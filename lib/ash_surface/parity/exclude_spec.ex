defmodule AshSurface.Parity.ExcludeSpec do
  @moduledoc """
  Statically resolves which tests ExUnit will not run, without executing any project code.

  Sources (all read through `Code.string_to_quoted/1`; comments and strings never count):

    * `test/test_helper.exs` - `exclude:` / `include:` options of `ExUnit.start/1` and
      `ExUnit.configure/1`. Literal atoms, `slow: false` style keyword filters, `~w(slow)a`
      sigils and variables bound to such literals earlier in the file resolve. Anything else
      (`Application.get_env/3`, module attributes, function calls) cannot be resolved and
      yields an `UNRESOLVABLE-EXCLUDE` problem: the gate must never silently pass on it.
    * `mix.exs` - `--only`, `--exclude`, `--include` flags written in alias strings
      (`"test --exclude slow"` or `["test", "--exclude", "slow"]`).

  Filters are `{name, value}` pairs (`:slow` is `{"slow", true}`); matching follows
  `ExUnit.Filters`: the test must carry the tag and its value must compare equal as a string.
  `include` overrides `exclude`; `only` excludes every test that matches no `only` filter.
  """

  @type filter :: {String.t(), term()}
  @type t :: %{
          exclude: [filter()],
          include: [filter()],
          only: [filter()],
          problems: [String.t()]
        }

  @spec read(String.t()) :: t()
  def read(root) do
    helper = helper_spec(Path.join(root, "test/test_helper.exs"))
    mix = mix_spec(Path.join(root, "mix.exs"))

    %{
      exclude: helper.exclude ++ mix.exclude,
      include: helper.include ++ mix.include,
      only: mix.only,
      problems: helper.problems ++ mix.problems
    }
  end

  @doc """
  Is a test with these tag values excluded? `tag_values` maps tag name to literal value
  (or `:dynamic` when the value is not a literal; that matches any filter on the key).
  """
  @spec excluded?(t(), %{optional(String.t()) => term()}) :: boolean()
  def excluded?(spec, tag_values) do
    cond do
      spec.only != [] -> not Enum.any?(spec.only, &matches?(&1, tag_values))
      Enum.any?(spec.include, &matches?(&1, tag_values)) -> false
      true -> Enum.any?(spec.exclude, &matches?(&1, tag_values))
    end
  end

  defp matches?({k, v}, tags) do
    case Map.fetch(tags, k) do
      {:ok, :dynamic} -> true
      {:ok, tv} -> to_string(tv) == to_string(v)
      :error -> false
    end
  end

  # ---- test_helper.exs ----

  @doc "Spec from the `ExUnit.start/configure` calls of one file (test_helper or a test file)."
  @spec read_file(String.t()) :: t()
  def read_file(path) do
    h = helper_spec(path)
    Map.put(h, :only, [])
  end

  @doc "Spec that excludes plain tag names (legacy list form)."
  @spec from_names([atom() | String.t()]) :: t()
  def from_names(names),
    do: %{
      exclude: Enum.map(names, &{to_string(&1), true}),
      include: [],
      only: [],
      problems: []
    }

  @doc "Union of two specs."
  @spec merge(t(), t()) :: t()
  def merge(a, b),
    do: %{
      exclude: a.exclude ++ b.exclude,
      include: a.include ++ b.include,
      only: a.only ++ b.only,
      problems: a.problems ++ b.problems
    }

  defp helper_spec(path) do
    empty = %{exclude: [], include: [], problems: []}

    case File.read(path) do
      {:ok, text} ->
        case Code.string_to_quoted(text) do
          {:ok, ast} ->
            binds = bindings(ast)

            ast
            |> option_exprs()
            |> Enum.reduce(empty, fn {key, expr}, acc ->
              case resolve(expr, binds) do
                {:ok, filters} -> Map.update!(acc, key, &(&1 ++ filters))
                {:error, why} -> add_problem(acc, key, why)
              end
            end)

          {:error, _} ->
            add_problem(empty, :exclude, "test/test_helper.exs is unparseable")
        end

      _ ->
        empty
    end
  end

  defp add_problem(acc, key, why),
    do: %{acc | problems: acc.problems ++ ["UNRESOLVABLE-EXCLUDE: #{key}: #{why}"]}

  # `ExUnit.start(opts)` / `ExUnit.configure(opts)` option expressions for :exclude / :include
  defp option_exprs(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, [:ExUnit]}, f]}, _, args} = n, acc
        when f in [:start, :configure] and is_list(args) ->
          found =
            for opts <- args,
                is_list(opts),
                {k, v} <- opts,
                k in [:exclude, :include],
                do: {k, v}

          {n, acc ++ found}

        n, acc ->
          {n, acc}
      end)

    acc
  end

  # `name = literal` statements at the top level of the helper (plain variables only)
  defp bindings({:__block__, _, stmts}), do: Enum.reduce(stmts, %{}, &bind/2)
  defp bindings(stmt), do: bind(stmt, %{})

  defp bind({:=, _, [{name, _, ctx}, expr]}, acc) when is_atom(name) and is_atom(ctx) do
    case resolve(expr, acc) do
      {:ok, _} -> Map.put(acc, name, expr)
      _ -> acc
    end
  end

  defp bind(_, acc), do: acc

  defp resolve(expr, binds) do
    case do_resolve(expr, binds) do
      {:ok, f} -> {:ok, f}
      {:error, _} = e -> e
    end
  end

  defp do_resolve(a, _) when is_atom(a) and a not in [nil, true, false],
    do: {:ok, [{to_string(a), true}]}

  defp do_resolve(s, _) when is_binary(s), do: {:ok, [parse_string(s)]}

  defp do_resolve({:sigil_w, _, [{:<<>>, _, [str]}, mods]}, _) when is_binary(str) do
    words = String.split(str)

    if mods in [[], ~c"a", ~c"s"],
      do: {:ok, Enum.map(words, &parse_string/1)},
      else: {:error, "unsupported ~w modifier"}
  end

  defp do_resolve({name, _, ctx} = v, binds) when is_atom(name) and is_atom(ctx) do
    case Map.fetch(binds, name) do
      {:ok, e} -> do_resolve(e, binds)
      :error -> {:error, "variable #{name} is not statically bound (#{Macro.to_string(v)})"}
    end
  end

  defp do_resolve(list, binds) when is_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn el, {:ok, acc} ->
      case do_resolve_element(el, binds) do
        {:ok, f} -> {:cont, {:ok, acc ++ f}}
        {:error, _} = e -> {:halt, e}
      end
    end)
  end

  defp do_resolve(other, _),
    do: {:error, "#{Macro.to_string(other)} cannot be statically resolved"}

  defp do_resolve_element({k, v}, _) when is_atom(k) do
    if literal_value?(v),
      do: {:ok, [{Atom.to_string(k), v}]},
      else: {:error, "filter value #{Macro.to_string(v)} cannot be statically resolved"}
  end

  defp do_resolve_element({:{}, _, [k, v]}, _) when is_atom(k) and (is_atom(v) or is_binary(v)),
    do: {:ok, [{Atom.to_string(k), v}]}

  defp do_resolve_element(el, binds), do: do_resolve(el, binds)

  defp literal_value?(v), do: is_atom(v) or is_binary(v) or is_number(v)

  defp parse_string(s) do
    case String.split(s, ":", parts: 2) do
      [k, v] -> {k, v}
      [k] -> {k, true}
    end
  end

  # ---- mix.exs (--only / --exclude / --include in alias strings) ----

  defp mix_spec(path) do
    empty = %{exclude: [], include: [], only: [], problems: []}

    with {:ok, text} <- File.read(path),
         {:ok, ast} <- Code.string_to_quoted(text) do
      ast
      |> string_runs()
      |> Enum.flat_map(&String.split/1)
      |> flags(empty)
    else
      _ -> empty
    end
  end

  # every binary literal, plus the space-joined run of every all-binary list literal
  # (`["test", "--exclude", "slow"]`)
  defp string_runs(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        s, acc when is_binary(s) ->
          {s, [s | acc]}

        l, acc when is_list(l) and l != [] ->
          if Enum.all?(l, &is_binary/1), do: {l, [Enum.join(l, " ") | acc]}, else: {l, acc}

        n, acc ->
          {n, acc}
      end)

    Enum.reverse(acc)
  end

  defp flags(tokens, acc) do
    tokens
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(acc, fn
      [flag, val], acc when flag in ["--only", "--exclude", "--include"] ->
        if String.contains?(val, "/") or String.ends_with?(val, ".exs") or
             String.starts_with?(val, "-") do
          acc
        else
          key = %{"--only" => :only, "--exclude" => :exclude, "--include" => :include}[flag]
          Map.update!(acc, key, &Enum.uniq(&1 ++ [parse_string(val)]))
        end

      _, acc ->
        acc
    end)
  end
end
