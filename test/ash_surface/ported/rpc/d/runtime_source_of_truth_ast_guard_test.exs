defmodule AshSurface.Ported.Rpc.D.RuntimeSourceOfTruthAstGuardTest do
  @moduledoc """
  AST-based companion to `runtime_source_of_truth_guard_test.exs` (which string-greps and is
  kept). This one parses each runtime-parity file with `Code.string_to_quoted/1`, resolves
  `alias` declarations, and checks real call/alias structure, so it is immune to comments,
  strings and docs that merely mention a forbidden name, and it also catches an aliased call
  (`alias AshSurface.Info, as: I` then `I.x()`) that the string guard misses.

  Two laws:

    1. The seven guarded files never call into `AshSurface.Resource.Info` / `AshSurface.Info`
       (resolved through aliases) and never read the retired raw `rpc_action` keys via
       `Map.get/2,3`.
    2. Every file under `lib/ash_surface/runtime_parity` is non-actuating: no remote call to
       `Ash.read*/create*/update*/destroy*` (nor `Ash.bulk_*`), the data-layer entry points.
  """
  use ExUnit.Case, async: true

  @guarded [
    "lib/ash_surface/runtime_parity/requested_fields_processor.ex",
    "lib/ash_surface/runtime_parity/field_selection.ex",
    "lib/ash_surface/runtime_parity/requested_fields/atomizer.ex",
    "lib/ash_surface/runtime_parity/requested_fields/field_selector.ex",
    "lib/ash_surface/runtime_parity/requested_fields/validation.ex",
    "lib/ash_surface/runtime_parity/requested_fields/load_restrictions.ex",
    "lib/ash_surface/runtime_parity/requested_fields/introspection.ex"
  ]

  @forbidden_modules [AshSurface.Resource.Info, AshSurface.Info]
  @retired_keys [:allowed_loads, :denied_loads, :enable_filter?, :enable_sort?, :show_metadata]
  @actuating ~w(read read! read_one read_one! create create! update update! destroy destroy!
                bulk_create bulk_update bulk_destroy bulk_create! bulk_update! bulk_destroy!
                stream stream! run_action run_action! load load! calculate calculate!)a
  @map_readers ~w(get get! fetch fetch! get_lazy pop pop! has_key? take)a

  @doc false
  def violations(source, opts \\ []) do
    {:ok, ast} = Code.string_to_quoted(source)
    ast |> walk(%{aliases: %{}, imports: [], module: nil}, opts, []) |> Enum.reverse()
  end

  # Scope-aware walk: `alias`/`import` take effect for later siblings in the same block only;
  # a block's declarations never leak to the enclosing scope.
  defp walk({:__block__, _, stmts}, env, opts, acc) do
    {_, acc} =
      Enum.reduce(stmts, {env, acc}, fn stmt, {e, a} ->
        {declare(stmt, e), walk(stmt, e, opts, a)}
      end)

    acc
  end

  defp walk({:defmodule, _, [name_ast, [do: body]]}, env, opts, acc) do
    full =
      case {resolve_mod(name_ast, env), env.module} do
        {nil, _} -> nil
        {mod, nil} -> mod
        {mod, outer} -> Module.concat(outer, mod)
      end

    walk(body, %{env | module: full}, opts, acc)
  end

  defp walk({form, _, args} = node, env, opts, acc) do
    acc = check(node, env, opts) ++ acc
    acc = if is_tuple(form), do: walk(form, env, opts, acc), else: acc
    if is_list(args), do: walk(args, env, opts, acc), else: acc
  end

  defp walk(list, env, opts, acc) when is_list(list),
    do: Enum.reduce(list, acc, &walk(&1, env, opts, &2))

  defp walk({a, b}, env, opts, acc), do: walk(b, env, opts, walk(a, env, opts, acc))
  defp walk(_, _env, _opts, acc), do: acc

  defp declare({:alias, _, [{:__aliases__, _, parts} = ast]}, env) do
    put_alias(env, List.last(parts), resolve_mod(ast, env))
  end

  defp declare({:alias, _, [{:__aliases__, _, _} = ast, [as: {:__aliases__, _, [as]}]]}, env),
    do: put_alias(env, as, resolve_mod(ast, env))

  defp declare({:alias, _, [{{:., _, [base_ast, :{}]}, _, subs}]}, env) do
    base = resolve_mod(base_ast, env)

    Enum.reduce(subs, env, fn
      {:__aliases__, _, sub}, e when is_atom(hd(sub)) and base != nil ->
        put_alias(e, List.last(sub), Module.concat([base | sub]))

      _, e ->
        e
    end)
  end

  defp declare({:import, _, [mod_ast | _]}, env) do
    case resolve_mod(mod_ast, env) do
      nil -> env
      mod -> %{env | imports: [mod | env.imports]}
    end
  end

  defp declare(_, env), do: env

  defp put_alias(env, _short, nil), do: env
  defp put_alias(env, short, mod), do: %{env | aliases: Map.put(env.aliases, short, mod)}

  defp resolve_mod({:__aliases__, _, [{:__MODULE__, _, _} | rest]}, %{module: m}) when m != nil,
    do: Module.concat([m | rest])

  defp resolve_mod({:__aliases__, _, [first | rest] = parts}, env) when is_atom(first) do
    case env.aliases do
      %{^first => full} -> Module.concat([full | rest])
      _ -> Module.concat(parts)
    end
  end

  defp resolve_mod({:__MODULE__, _, _}, %{module: m}) when m != nil, do: m

  defp resolve_mod({{:., _, [{:__aliases__, _, [:Module]}, :concat]}, _, [list]}, env)
       when is_list(list) do
    parts = Enum.map(list, &resolve_mod(&1, env))
    if Enum.all?(parts, & &1), do: Module.concat(parts), else: nil
  end

  defp resolve_mod(atom, _env) when is_atom(atom) and atom not in [nil, true, false], do: atom
  defp resolve_mod(_, _env), do: nil

  defp check({:import, _, [mod_ast | _]}, env, opts) do
    mod = resolve_mod(mod_ast, env)

    if Keyword.get(opts, :modules, true) and mod in @forbidden_modules,
      do: ["import #{inspect(mod)}"],
      else: []
  end

  defp check({:apply, _, [mod_ast, fun, _args]}, env, opts) when is_atom(fun),
    do: call_violations(resolve_mod(mod_ast, env), fun, opts)

  defp check({fun, _, args}, env, opts) when is_atom(fun) and is_list(args) do
    if Keyword.get(opts, :actuating, true) and fun in @actuating and Ash in env.imports,
      do: ["actuating call Ash.#{fun}"],
      else: []
  end

  defp check({{:., _, [mod_ast, fun]}, _, args}, env, opts) when is_atom(fun) do
    mod = resolve_mod(mod_ast, env)
    modules? = Keyword.get(opts, :modules, true)
    retired = Enum.filter(args, &(&1 in @retired_keys))

    cond do
      mod == Kernel and fun == :apply and match?([_, _, _], args) ->
        [m, f, _] = args
        if is_atom(f), do: call_violations(resolve_mod(m, env), f, opts), else: []

      mod == Map and fun in @map_readers and retired != [] and modules? ->
        ["Map.#{fun} on retired key #{inspect(hd(retired))}"]

      mod == Access and retired != [] and modules? ->
        ["Access.#{fun} on retired key #{inspect(hd(retired))}"]

      mod == nil and args == [] and fun in @retired_keys and modules? and
          action_receiver?(mod_ast) ->
        ["dot access on retired key #{inspect(fun)}"]

      true ->
        call_violations(mod, fun, opts)
    end
  end

  defp check(_, _, _), do: []

  # Dot access only counts on an rpc-action-shaped receiver (`rpc_action.x`, `entry.x`); a
  # local ctx struct that happens to reuse a retired key name (`ctx.enable_sort?`) is not it.
  defp action_receiver?({name, _, ctx}) when is_atom(name) and is_atom(ctx),
    do: Atom.to_string(name) =~ ~r/action|entry/

  defp action_receiver?(_), do: false

  defp call_violations(mod, fun, opts) do
    cond do
      Keyword.get(opts, :modules, true) and mod in @forbidden_modules ->
        ["call #{inspect(mod)}.#{fun}"]

      Keyword.get(opts, :actuating, true) and mod == Ash and fun in @actuating ->
        ["actuating call Ash.#{fun}"]

      true ->
        []
    end
  end

  describe "analyzer hardened forms (each known-bad source flips it)" do
    defp wrap(body), do: "defmodule X do\n#{body}\nend"

    test "import of a forbidden module is found" do
      assert violations(wrap("import AshSurface.Info\ndef f(r), do: entries(r)")) ==
               ["import AshSurface.Info"]
    end

    test "import Ash then a bare actuating call is found" do
      assert violations(wrap("import Ash\ndef f(q), do: read!(q)")) ==
               ["actuating call Ash.read!"]

      assert violations(wrap("import Enum\ndef f(q), do: read!(q)")) == []
    end

    test "apply/3 and Kernel.apply/3 with literal module are found" do
      assert violations(wrap("def f, do: apply(AshSurface.Info, :f, [1])")) ==
               ["call AshSurface.Info.f"]

      assert violations(wrap("def f, do: Kernel.apply(AshSurface.Info, :f, [1])")) ==
               ["call AshSurface.Info.f"]

      assert violations(wrap("def f(q), do: apply(Ash, :read!, [q])")) ==
               ["actuating call Ash.read!"]

      assert violations(wrap("def f(q), do: apply(Other, :read!, [q])")) == []
    end

    test "piped Map.get / Map.fetch on a retired key are found" do
      assert violations(wrap("def f(a), do: a |> Map.get(:show_metadata)")) ==
               ["Map.get on retired key :show_metadata"]

      assert violations(wrap("def f(a), do: Map.fetch(a, :allowed_loads)")) ==
               ["Map.fetch on retired key :allowed_loads"]

      assert violations(wrap("def f(a), do: a |> Map.get(:other)")) == []
    end

    test "Access bracket and dot access on a retired key are found" do
      assert violations(wrap("def f(a), do: a[:enable_sort?]")) ==
               ["Access.get on retired key :enable_sort?"]

      assert violations(wrap("def f(rpc_action), do: rpc_action.denied_loads")) ==
               ["dot access on retired key :denied_loads"]

      assert violations(wrap("def f(a), do: a.denied_loads")) == []
    end

    test "a local ctx struct reusing a retired key name is not flagged; an rpc_action var is" do
      assert violations(wrap("def f(ctx), do: ctx.enable_sort?")) == []

      assert violations(wrap("def f(rpc_action), do: rpc_action.enable_sort?")) ==
               ["dot access on retired key :enable_sort?"]

      assert violations(wrap("def f(entry), do: entry.enable_filter?")) ==
               ["dot access on retired key :enable_filter?"]
    end

    test "aliased Map reader on a retired key is found" do
      assert violations(wrap("alias Map, as: M\ndef f(a), do: M.get(a, :denied_loads)")) ==
               ["Map.get on retired key :denied_loads"]
    end

    test "Ash.stream!, run_action and load! are found" do
      for fun <- ~w(stream! run_action load!) do
        assert violations(wrap("def f(q), do: Ash.#{fun}(q)")) == ["actuating call Ash.#{fun}"]
      end
    end

    test "alias __MODULE__.Info resolves without crashing" do
      assert violations(wrap("alias __MODULE__.Info\ndef f, do: Info.go()")) == []

      src = "defmodule AshSurface do\n alias __MODULE__.Info\n def f, do: Info.go()\nend"
      assert violations(src) == ["call AshSurface.Info.go"]
    end

    test "Module.concat literal module is resolved" do
      assert violations(wrap("def f, do: Module.concat([AshSurface, Info]).go()")) ==
               ["call AshSurface.Info.go"]
    end

    test "aliases are scope-aware: the same short name in separate scopes is not over-flagged" do
      src = """
      defmodule X do
        def a do
          alias AshSurface.Info
          Info.go()
        end

        def b do
          alias Other.Info
          Info.go()
        end

        def c, do: Info.go()
      end
      """

      assert violations(src) == ["call AshSurface.Info.go"]
    end
  end

  describe "analyzer is not vacuous (known-bad source flips it)" do
    test "direct forbidden module call is found" do
      assert violations("defmodule X do\n def f, do: AshSurface.Info.foo()\nend") ==
               ["call AshSurface.Info.foo"]
    end

    test "aliased forbidden module call is found (string guard cannot see this)" do
      src = """
      defmodule X do
        alias AshSurface.Resource.Info, as: I
        def f(r), do: I.entries(r)
      end
      """

      assert violations(src) == ["call AshSurface.Resource.Info.entries"]
    end

    test "grouped alias is resolved" do
      src = """
      defmodule X do
        alias AshSurface.{Info, Other}
        def f, do: Info.go()
      end
      """

      assert violations(src) == ["call AshSurface.Info.go"]
    end

    test "retired rpc_action key read via Map.get is found" do
      assert violations("defmodule X do\n def f(a), do: Map.get(a, :denied_loads, [])\nend") ==
               ["Map.get on retired key :denied_loads"]
    end

    test "actuating Ash call is found, comments and strings are not" do
      assert violations("defmodule X do\n def f(q), do: Ash.read!(q)\nend") ==
               ["actuating call Ash.read!"]

      src = """
      defmodule X do
        # AshSurface.Info.foo() Ash.read!(q)
        @moduledoc "AshSurface.Info.foo() and Ash.read!(q) in prose"
        def f, do: Ash.Resource.Info.action(R, :a)
      end
      """

      assert violations(src) == []
    end
  end

  describe "guarded runtime files (modules + retired keys)" do
    for file <- @guarded do
      test "#{file} has no forbidden calls in its AST" do
        path = Path.join(File.cwd!(), unquote(file))
        assert File.exists?(path), "guarded file missing: #{unquote(file)}"
        assert violations(File.read!(path)) == []
      end
    end
  end

  describe "runtime_parity tree is non-actuating" do
    test "no file under lib/ash_surface/runtime_parity calls an Ash data-layer entry point" do
      files = Path.wildcard(Path.join(File.cwd!(), "lib/ash_surface/runtime_parity/**/*.ex"))
      assert length(files) >= length(@guarded)

      offenders =
        for f <- files,
            v = violations(File.read!(f), modules: false),
            v != [],
            do: {Path.relative_to_cwd(f), v}

      assert offenders == []
    end
  end
end
