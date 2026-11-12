defmodule AshSurface.TestModuleIsolationCourtTest do
  @moduledoc """
  Fail-closed court: a test file may not reference a module whose ONLY definition site is a
  DIFFERENT test file (`test/**/*.exs`). Such a reference passes or fails by file load order,
  `--only` and `--seed`. Modules from `lib/` and `test/support` (compiled via `elixirc_paths`
  in the :test env) are lawful.

  AST parsing is `Code.string_to_quoted/1`, the same primitive `AshSurface.Parity.TestIndex`
  uses; TestIndex indexes tests/tags only (no module-reference surface), so the module walk is
  local here.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  # Each entry: {referencing_file_relative, "Module.Name", "justification"}
  @allowlist []

  defp rel(f), do: Path.relative_to(f, @root)
  defp parse!(f), do: f |> File.read!() |> Code.string_to_quoted!(columns: false)

  # -- definitions: [{full_name, line}] with enclosing prefixes resolved
  def defs(ast), do: ast |> walk_defs([], []) |> Enum.reverse()

  # -- definition SITES (duplicate court): defmodule (incl. inside quote/eval_quoted bodies),
  # Module.create/3 with a literal name (alias, Module.concat([..]) literal, or @attr bound to
  # one), and Code.eval_string/compile_string with a literal binary. Each site records whether
  # it sits under an `if/unless Code.ensure_loaded?(..)` guard and its `fields:` list.
  def def_sites(ast) do
    attrs = collect_attrs(ast)
    ast |> walk_sites([], attrs, false, []) |> Enum.reverse()
  end

  defp collect_attrs(ast) do
    {_, acc} =
      Macro.prewalk(ast, %{}, fn
        {:@, _, [{name, _, [val]}]} = n, acc when is_atom(name) ->
          case lit_name(val, %{}) do
            nil -> {n, acc}
            m -> {n, Map.put(acc, name, m)}
          end

        n, acc ->
          {n, acc}
      end)

    acc
  end

  defp lit_name({:__aliases__, _, parts}, _) when is_list(parts),
    do: if(Enum.all?(parts, &is_atom/1), do: Enum.join(parts, "."))

  defp lit_name({{:., _, [{:__aliases__, _, [:Module]}, :concat]}, _, [l]}, _) when is_list(l),
    do: if(Enum.all?(l, &is_binary/1), do: Enum.join(l, "."))

  defp lit_name({:@, _, [{n, _, nil}]}, attrs), do: Map.get(attrs, n)
  defp lit_name(a, _) when is_atom(a) and not is_nil(a), do: String.replace_prefix(Atom.to_string(a), "Elixir.", "")
  defp lit_name(_, _), do: nil

  defp guard?(cond_ast) do
    {_, hit} =
      Macro.prewalk(cond_ast, false, fn
        {{:., _, [{:__aliases__, _, [:Code]}, :ensure_loaded?]}, _, _} = n, _ -> {n, true}
        n, h -> {n, h}
      end)

    hit
  end

  defp fields_of(ast) do
    {_, f} =
      Macro.prewalk(ast, nil, fn
        {:use, _, [_, opts]} = n, acc when is_list(opts) ->
          {n, Keyword.get(opts, :fields, acc)}

        n, acc ->
          {n, acc}
      end)

    f
  end

  defp walk_sites({g, _, [cond_, body]}, prefix, at, guarded, acc) when g in [:if, :unless] do
    walk_sites(body, prefix, at, guarded or guard?(cond_), acc)
  end

  defp walk_sites({:defmodule, m, [{:__aliases__, _, parts}, [do: body]]}, prefix, at, gd, acc) do
    full = qualify(parts, prefix)
    site = %{name: Enum.join(full, "."), line: m[:line], kind: :defmodule, guarded: gd, fields: fields_of(body)}
    walk_sites(body, full, at, gd, [site | acc])
  end

  defp walk_sites({{:., _, [{:__aliases__, _, [:Module]}, :create]}, m, [name, body | _]}, prefix, at, gd, acc) do
    case lit_name(name, at) do
      nil ->
        walk_sites(body, prefix, at, gd, acc)

      n ->
        site = %{name: n, line: m[:line], kind: :module_create, guarded: gd, fields: fields_of(body)}
        walk_sites(body, prefix, at, gd, [site | acc])
    end
  end

  defp walk_sites({{:., _, [{:__aliases__, _, [:Code]}, fun]}, _, [src | _]}, prefix, at, gd, acc)
       when fun in [:eval_string, :compile_string] and is_binary(src) do
    case Code.string_to_quoted(src) do
      {:ok, q} -> walk_sites(q, prefix, at, gd, acc)
      _ -> acc
    end
  end

  defp walk_sites({f, _, args}, prefix, at, gd, acc) do
    acc = if is_tuple(f), do: walk_sites(f, prefix, at, gd, acc), else: acc
    if is_list(args), do: Enum.reduce(args, acc, &walk_sites(&1, prefix, at, gd, &2)), else: acc
  end

  defp walk_sites(l, prefix, at, gd, acc) when is_list(l),
    do: Enum.reduce(l, acc, &walk_sites(&1, prefix, at, gd, &2))

  defp walk_sites({a, b}, prefix, at, gd, acc),
    do: walk_sites(b, prefix, at, gd, walk_sites(a, prefix, at, gd, acc))

  defp walk_sites(_, _, _, _, acc), do: acc

  @doc false
  # Duplicate/guarded definition findings over [{relative_path, ast}].
  # {:duplicate, name, [{file, line, kind}]} : same module defined at >1 site (any files).
  # {:guarded, name, file, line, fields} : Code.ensure_loaded?-guarded fake outside test/support.
  def definition_findings(test_files, shared_files \\ []) do
    sites =
      for {f, ast} <- test_files ++ shared_files, s <- def_sites(ast), do: Map.put(s, :file, f)

    dups =
      sites
      |> Enum.group_by(& &1.name)
      |> Enum.filter(fn {_, l} -> l |> Enum.map(& &1.file) |> Enum.uniq() |> length() > 1 end)
      |> Enum.map(fn {n, l} ->
        {:duplicate, n, l |> Enum.map(&{&1.file, &1.line, &1.kind}) |> Enum.sort()}
      end)

    guarded =
      for s <- sites, s.guarded, not Enum.any?(shared_files, fn {sf, _} -> sf == s.file end), do: {:guarded, s.name, s.file, s.line, s.fields}

    Enum.sort(dups) ++ Enum.sort(guarded)
  end

  defp walk_defs({:defmodule, m, [{:__aliases__, _, parts}, [do: body]]}, prefix, acc) do
    full = qualify(parts, prefix)
    walk_defs(body, full, [{Enum.join(full, "."), m[:line]} | acc])
  end

  defp walk_defs({_, _, args}, prefix, acc) when is_list(args),
    do: Enum.reduce(args, acc, &walk_defs(&1, prefix, &2))

  defp walk_defs(l, prefix, acc) when is_list(l),
    do: Enum.reduce(l, acc, &walk_defs(&1, prefix, &2))

  defp walk_defs({a, b}, prefix, acc), do: walk_defs(b, prefix, walk_defs(a, prefix, acc))
  defp walk_defs(_, _, acc), do: acc

  defp qualify([:__MODULE__ | rest], prefix), do: prefix ++ rest
  defp qualify(parts, prefix), do: prefix ++ parts

  # -- references: [{candidate_name, line}]
  def refs(ast) do
    aliases = collect_aliases(ast)
    ast |> walk_refs([], aliases, []) |> Enum.reverse()
  end

  defp collect_aliases(ast) do
    {_, acc} =
      Macro.prewalk(ast, %{}, fn
        {:alias, _, [{:__aliases__, _, parts}]} = n, acc ->
          {n, Map.put(acc, List.last(parts), parts)}

        {:alias, _, [{:__aliases__, _, parts}, [as: {:__aliases__, _, [as]}]]} = n, acc ->
          {n, Map.put(acc, as, parts)}

        {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, subs}]} = n, acc ->
          {n,
           Enum.reduce(subs, acc, fn {:__aliases__, _, p}, a ->
             Map.put(a, List.last(p), base ++ p)
           end)}

        n, acc ->
          {n, acc}
      end)

    acc
  end

  defp walk_refs({:defmodule, m, [{:__aliases__, _, parts}, [do: body]]}, prefix, al, acc) do
    walk_refs(body, qualify(parts, prefix), al, acc) |> tap(fn _ -> m end)
  end

  defp walk_refs({:alias, _, _}, _, _, acc), do: acc

  defp walk_refs({:__aliases__, m, [h | _] = parts}, prefix, al, acc) when is_atom(h) do
    via_alias =
      case al do
        %{^h => full} -> [Enum.join(full ++ tl(parts), ".")]
        _ -> []
      end

    via_prefix = if prefix == [], do: [], else: [Enum.join(prefix ++ parts, ".")]
    cands = via_alias ++ [Enum.join(parts, ".")] ++ via_prefix

    Enum.map(cands, &{&1, m[:line]}) ++ acc
  end

  defp walk_refs(a, _, _, acc) when is_atom(a) do
    case Atom.to_string(a) do
      "Elixir." <> n -> [{n, nil} | acc]
      _ -> acc
    end
  end

  defp walk_refs({f, _, args}, prefix, al, acc) do
    acc = if is_tuple(f), do: walk_refs(f, prefix, al, acc), else: acc
    if is_list(args), do: Enum.reduce(args, acc, &walk_refs(&1, prefix, al, &2)), else: acc
  end

  defp walk_refs(l, prefix, al, acc) when is_list(l),
    do: Enum.reduce(l, acc, &walk_refs(&1, prefix, al, &2))

  defp walk_refs({a, b}, prefix, al, acc), do: walk_refs(b, prefix, al, walk_refs(a, prefix, al, acc))
  defp walk_refs(_, _, _, acc), do: acc

  @doc false
  # files: list of {relative_path, ast}; lawful: MapSet of module names from lib/support.
  def findings(test_files, lawful, allow) do
    defs_by_file = for {f, ast} <- test_files, into: %{}, do: {f, defs(ast)}

    owners =
      Enum.reduce(defs_by_file, %{}, fn {f, ds}, acc ->
        Enum.reduce(ds, acc, fn {n, _}, a -> Map.update(a, n, [f], &[f | &1]) end)
      end)

    for {f, ast} <- test_files,
        own = own_modules(f, ast, defs_by_file),
        {name, line} <- ast |> refs() |> Enum.uniq(),
        not MapSet.member?(own, name),
        not MapSet.member?(lawful, name),
        other = Map.get(owners, name, []) -- [f],
        other != [],
        not Enum.any?(allow, fn {af, am, _why} -> af == f and am == name end) do
      %{file: f, line: line, module: name, owners: Enum.sort(other)}
    end
    |> Enum.uniq_by(&{&1.file, &1.module})
  end

  # A file that explicitly `Code.require_file("lit", __DIR__)`s a sibling owns that sibling's
  # modules: the load is a declared dependency, not an accident of load order.
  defp own_modules(f, ast, defs_by_file) do
    {_, reqs} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, [:Code]}, :require_file]}, _, [lit, {:__DIR__, _, _}]} = n, a
        when is_binary(lit) ->
          {n, [Path.join(Path.dirname(f), lit) | a]}

        n, a ->
          {n, a}
      end)

    ([f | Enum.map(reqs, &(&1 |> Path.expand(@root) |> rel()))] |> Enum.flat_map(&Map.get(defs_by_file, &1, [])))
    |> MapSet.new(&elem(&1, 0))
  end

  defp lawful_modules do
    for f <-
          Path.wildcard(Path.join(@root, "lib/**/*.ex")) ++
            Path.wildcard(Path.join(@root, "test/support/**/*.ex")),
        {n, _} <- f |> parse!() |> defs(),
        into: MapSet.new(),
        do: n
  end

  defp shared_files do
    for f <-
          Path.wildcard(Path.join(@root, "lib/**/*.ex")) ++
            Path.wildcard(Path.join(@root, "test/support/**/*.ex")) do
      {rel(f), parse!(f)}
    end
  end

  defp test_files do
    Path.wildcard(Path.join(@root, "test/**/*.exs"))
    |> Enum.reject(&String.contains?(&1, "/support/"))
    |> Enum.sort()
    |> Enum.map(&{rel(&1), parse!(&1)})
  end

  test "allowlist entries each cite a justification" do
    for {f, m, why} <- @allowlist,
        do: assert(is_binary(f) and is_binary(m) and byte_size(why) > 10)
  end

  test "mix.exs compiles test/support in :test (lawful shared-module location)" do
    assert File.read!(Path.join(@root, "mix.exs")) =~ ~s|elixirc_paths(:test), do: ["lib", "test/support"]|
  end

  test "no test file references a module defined only in another test file" do
    fs = test_files()
    assert length(fs) > 50, "census saw too few test files: #{length(fs)}"
    found = findings(fs, lawful_modules(), @allowlist)

    msg =
      Enum.map_join(found, "\n", fn x ->
        "  #{x.file}:#{x.line || "?"} references #{x.module} defined only in #{Enum.join(x.owners, ", ")}"
      end)

    assert found == [], "cross-test-file module references (load-order dependent):\n" <> msg
  end

  test "non-vacuity: a planted cross-file reference is flagged, own-file and lib are not" do
    a = Code.string_to_quoted!("defmodule Planted.Owner do\n def f, do: 1\nend")
    b = Code.string_to_quoted!("defmodule PlantedTest do\n def t, do: Planted.Owner.f()\nend")
    c = Code.string_to_quoted!("defmodule PlantedOk do\n alias Planted.Owner\n def t, do: Owner.f()\nend")

    assert [%{file: "b.exs", module: "Planted.Owner", owners: ["a.exs"]}] =
             findings([{"a.exs", a}, {"b.exs", b}], MapSet.new(), [])

    assert [%{file: "c.exs"}] = findings([{"a.exs", a}, {"c.exs", c}], MapSet.new(), [])
    assert [] == findings([{"a.exs", a}, {"b.exs", b}], MapSet.new(["Planted.Owner"]), [])
    assert [] == findings([{"a.exs", a}, {"b.exs", b}], MapSet.new(), [{"b.exs", "Planted.Owner", "justified test case"}])
  end

  test "no module is defined at more than one site, and no guarded fake lives in a test file" do
    found = definition_findings(test_files(), shared_files())

    msg =
      Enum.map_join(found, "\n", fn
        {:duplicate, n, sites} ->
          "  DUPLICATE #{n}: " <> Enum.map_join(sites, "; ", fn {f, l, k} -> "#{f}:#{l} (#{k})" end)

        {:guarded, n, f, l, fields} ->
          "  GUARDED FAKE #{n} at #{f}:#{l} fields=#{inspect(fields)}; move one shared definition to test/support"
      end)

    assert found == [], "duplicate/guarded module definitions (load-order dependent):\n" <> msg
  end

  test "non-vacuity: planted duplicates (defmodule, Module.create, eval_quoted, guarded) are flagged" do
    p = &Code.string_to_quoted!/1
    a = p.("defmodule Dup.M do\nend")
    b = p.("defmodule Dup.M do\nend")
    c = p.("@t Module.concat([\"Dup\", \"C\"])\nModule.create(@t, quote(do: use(Splode.Error, fields: [:a])), [])")
    d = p.("Module.create(Dup.C, quote(do: use(Splode.Error, fields: [:b])), [])")
    e = p.("Code.eval_quoted(quote(do: defmodule(Dup.E, do: nil)))")
    f = p.("defmodule Dup.E do\nend")
    g = p.("unless Code.ensure_loaded?(Dup.G) do\n  Module.create(Dup.G, quote(do: use(Splode.Error, fields: [:x, :y])), [])\nend")

    found = definition_findings([{"a", a}, {"b", b}, {"c", c}, {"d", d}, {"e", e}, {"f", f}, {"g", g}])
    assert Enum.any?(found, &match?({:duplicate, "Dup.M", [{"a", _, :defmodule}, {"b", _, :defmodule}]}, &1))
    assert Enum.any?(found, &match?({:duplicate, "Dup.C", [{"c", _, :module_create}, {"d", _, :module_create}]}, &1))
    assert Enum.any?(found, &match?({:duplicate, "Dup.E", [{"e", _, :defmodule}, {"f", _, :defmodule}]}, &1))
    assert Enum.any?(found, &match?({:guarded, "Dup.G", "g", _, [:x, :y]}, &1))
    assert [] == definition_findings([{"a", a}, {"e", e}, {"d", d}])
    # a test-file definition of a module owned by lib/test-support is a duplicate too
    assert [{:duplicate, "Dup.M", [{"a", _, _}, {"lib/x.ex", _, _}]}] =
             definition_findings([{"a", a}], [{"lib/x.ex", b}])
  end
end
