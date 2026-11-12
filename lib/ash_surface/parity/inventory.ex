defmodule AshSurface.Parity.Inventory do
  @moduledoc """
  Mechanical capability inventory of the `ash_typescript` reference.

  The inventory is DERIVED, never hand-typed: every `lib/**/*.ex` file of the
  reference checkout is parsed with `Code.string_to_quoted/1` and walked as an
  AST. The reference is never compiled and no resource action is executed.

  Sections (each id is `<section-prefix>.<...>`):

    * `dsl`        - Spark DSL entities/sections and every schema option
                     (`dsl.<mod>.entity.<name>.option.<key>`)
    * `config`     - `Application.get_env(:ash_typescript, key)` keys
    * `type`       - type kinds (`type.kind.*`), aggregate kinds
                     (`type.aggregate.*`) and constraint keys (`type.constraint.*`)
    * `error`      - `Rpc.Error` protocol impls and wire `type:` strings
    * `task`       - mix tasks and their switches
    * `verifier`   - verifier modules
    * `transformer`- transformer modules
    * `codegen`    - codegen modules
    * `tstype`     - exported TypeScript names found in emitted string templates
    * `installer`  - installer modules
    * `runtime`    - every remaining reference module

  The output is a stable, sorted structure: no timestamps, no absolute paths.
  """

  @entity_kinds [:Entity, :Section]
  @get_env_funs [:get_env, :fetch_env, :fetch_env!, :compile_env, :compile_env!]
  @constraint_files [
    "lib/ash_typescript/codegen/zod_schema_generator.ex",
    "lib/ash_typescript/codegen/schema_core.ex",
    "lib/ash_typescript/codegen/type_mapper.ex",
    "lib/ash_typescript/codegen/valibot_schema_generator.ex"
  ]
  @type_files [
    "lib/ash_typescript/codegen/type_mapper.ex",
    "lib/ash_typescript/codegen/schema_core.ex",
    "lib/ash_typescript/codegen/zod_schema_generator.ex"
  ]
  @ts_export ~r/export\s+(?:declare\s+)?(?:type|interface|const|function|class|enum)\s+([A-Za-z_][A-Za-z0-9_]*)/

  @type capability :: %{id: String.t(), section: String.t(), source: String.t()}

  @doc "Derive the inventory from the reference checkout at `ref_root`."
  @spec derive(Path.t()) ::
          {:ok, %{capabilities: [capability()], advisory: map()}} | {:error, String.t()}
  def derive(ref_root) do
    lib = Path.join(ref_root, "lib")

    if File.dir?(lib) do
      files = lib |> Path.join("**/*.ex") |> Path.wildcard() |> Enum.sort()
      parsed = Enum.map(files, &parse!(&1, ref_root))

      caps =
        parsed
        |> Enum.flat_map(fn {rel, ast, src} -> extract(rel, ast, src) end)
        |> Enum.uniq_by(& &1.id)
        |> Enum.sort_by(& &1.id)

      {:ok, %{capabilities: caps, advisory: advisory(ref_root)}}
    else
      {:error, "reference lib/ not found at #{ref_root}"}
    end
  rescue
    e -> {:error, "inventory derivation failed: " <> Exception.message(e)}
  end

  @doc "Read the reference's git HEAD without running git (nil when unknown)."
  def reference_head(ref_root) do
    head = Path.join([ref_root, ".git", "HEAD"])

    with {:ok, content} <- File.read(head) do
      case String.trim(content) do
        "ref: " <> ref ->
          case File.read(Path.join([ref_root, ".git", ref])) do
            {:ok, sha} -> String.trim(sha)
            _ -> nil
          end

        sha ->
          sha
      end
    else
      _ -> nil
    end
  end

  @doc "Stable JSON rendering (one capability per line; byte-identical on re-derivation)."
  def to_json(%{capabilities: caps, advisory: advisory}) do
    lines =
      Enum.map_join(caps, ",\n", fn c ->
        "    " <>
          Jason.encode!(
            Jason.OrderedObject.new([{"id", c.id}, {"section", c.section}, {"source", c.source}])
          )
      end)

    adv =
      advisory
      |> Enum.sort()
      |> Enum.map_join(",\n", fn {k, v} ->
        "    " <> Jason.encode!(to_string(k)) <> ": " <> Jason.encode!(v)
      end)

    "{\n  \"advisory\": {\n" <>
      adv <>
      "\n  },\n  \"capabilities\": [\n" <>
      lines <> "\n  ],\n  \"reference\": \"ash_typescript\",\n  \"schema\": 1\n}\n"
  end

  @doc "Decode a committed inventory file."
  def from_json!(text) do
    decoded = Jason.decode!(text)

    caps =
      for c <- decoded["capabilities"] do
        %{id: c["id"], section: c["section"], source: c["source"]}
      end

    %{capabilities: caps, advisory: decoded["advisory"] || %{}}
  end

  # ---------------------------------------------------------------- parsing

  defp parse!(path, ref_root) do
    src = File.read!(path)

    case Code.string_to_quoted(src, file: path) do
      {:ok, ast} -> {Path.relative_to(path, ref_root), ast, src}
      {:error, err} -> raise "cannot parse #{path}: #{inspect(err)}"
    end
  end

  defp advisory(ref_root) do
    tests = ref_root |> Path.join("test/**/*.exs") |> Path.wildcard() |> Enum.sort()

    {describes, test_count} =
      Enum.reduce(tests, {0, 0}, fn f, {d, t} ->
        src = File.read!(f)
        {d + count(src, ~r/^\s*describe\s+"/m), t + count(src, ~r/^\s*test\s+"/m)}
      end)

    %{
      "test_files" => length(tests),
      "test_describe_blocks" => describes,
      "test_cases" => test_count
    }
  end

  defp count(src, re), do: re |> Regex.scan(src) |> length()

  # ------------------------------------------------------------- extraction

  defp extract(rel, ast, _src) do
    mod = mod_key(rel)

    dsl(rel, mod, ast) ++
      config(rel, ast) ++
      types(rel, ast) ++
      errors(rel, ast) ++
      tasks(rel, ast) ++
      modules(rel, ast) ++
      tstypes(rel, ast)
  end

  defp mod_key(rel),
    do:
      rel
      |> String.replace_prefix("lib/ash_typescript/", "")
      |> String.replace_prefix("lib/", "")
      |> String.replace_suffix(".ex", "")
      |> String.replace("/", ".")

  defp cap(id, section, rel), do: %{id: id, section: section, source: rel}

  # (a) Spark DSL
  defp dsl(rel, mod, ast) do
    attrs = schema_attrs(ast)

    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:%, _, [{:__aliases__, _, aliases}, {:%{}, _, kw}]} = node, acc ->
          if :Spark in aliases and :Dsl in aliases and List.last(aliases) in @entity_kinds do
            {node, entity(rel, mod, aliases, kw, attrs) ++ acc}
          else
            {node, acc}
          end

        {:opt_schema, schema} = node, acc when is_list(schema) ->
          {node, options("dsl.#{mod}.opt_schema", schema, rel) ++ acc}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  defp entity(rel, mod, aliases, kw, attrs) do
    kind = aliases |> List.last() |> Atom.to_string() |> String.downcase()

    case kw[:name] do
      name when is_atom(name) and not is_nil(name) ->
        base = "dsl.#{mod}.#{kind}.#{name}"
        schema = schema_pairs(kw[:schema], attrs)
        [cap(base, "dsl", rel) | options(base, schema, rel)]

      _ ->
        []
    end
  end

  # `@attr [key: [...]]` module attributes holding schema keyword lists
  defp schema_attrs(ast) do
    {_, acc} =
      Macro.prewalk(ast, %{}, fn
        {:@, _, [{name, _, [list]}]} = node, acc when is_atom(name) and is_list(list) ->
          if Enum.all?(list, &match?({k, _} when is_atom(k), &1)),
            do: {node, Map.put(acc, name, list)},
            else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  # a schema is a literal list, `a ++ b`, or an `@attr` reference to one
  defp schema_pairs(list, _) when is_list(list), do: list
  defp schema_pairs({:++, _, [a, b]}, attrs), do: schema_pairs(a, attrs) ++ schema_pairs(b, attrs)

  defp schema_pairs({:@, _, [{name, _, ctx}]}, attrs) when is_atom(ctx),
    do: Map.get(attrs, name, [])

  defp schema_pairs(_, _), do: []

  defp options(base, schema, rel) do
    for {key, _} <- schema, is_atom(key), do: cap("#{base}.option.#{key}", "dsl", rel)
  end

  # (b) config keys
  defp config(rel, ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, [:Application]}, f]}, _, [:ash_typescript, key | _]} = node,
        acc
        when f in @get_env_funs and is_atom(key) ->
          {node, [cap("config.key.#{key}", "config", rel) | acc]}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  # (c) type kinds, aggregate kinds, constraint keys
  defp types(rel, ast) do
    kinds = if rel in @type_files, do: type_kinds(rel, ast), else: []
    cons = if rel in @constraint_files, do: constraint_keys(rel, ast), else: []
    kinds ++ cons
  end

  defp type_kinds(rel, ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:@, _, [{name, _, [{:%{}, _, pairs}]}]} = node, acc when is_atom(name) ->
          prefix =
            if String.contains?(Atom.to_string(name), "aggregate"),
              do: "type.aggregate",
              else: "type.kind"

          ids = for {k, _} <- pairs, n = kind_name(k), do: cap("#{prefix}.#{n}", "type", rel)
          {node, ids ++ acc}

        {:__aliases__, _, [:Ash, :Type, last]} = node, acc when is_atom(last) ->
          {node, [cap("type.kind.#{snake(last)}", "type", rel) | acc]}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  defp kind_name({:__aliases__, _, [:Ash, :Type, last]}), do: snake(last)
  defp kind_name(a) when is_atom(a) and not is_nil(a), do: Atom.to_string(a)
  defp kind_name(_), do: nil

  defp snake(atom) do
    s = Atom.to_string(atom)

    case s do
      "UUIDv7" ->
        "uuid_v7"

      _ ->
        s
        |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1_\\2")
        |> String.downcase()
    end
  end

  @constraint_funs [:get, :fetch, :fetch!, :has_key?, :pop, :get_lazy]

  defp constraint_keys(rel, ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, [:Keyword]}, f]}, _, [{v, _, ctx}, key | _]} = node, acc
        when f in @constraint_funs and is_atom(v) and is_atom(ctx) and is_atom(key) ->
          {node, constraint(v, key, rel, acc)}

        {{:., _, [Access, :get]}, _, [{v, _, ctx}, key]} = node, acc
        when is_atom(v) and is_atom(ctx) and is_atom(key) ->
          {node, constraint(v, key, rel, acc)}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  defp constraint(var, key, rel, acc) do
    if String.contains?(Atom.to_string(var), "constraint") do
      [cap("type.constraint.#{key}", "type", rel) | acc]
    else
      acc
    end
  end

  # (d) error impls + wire types
  defp errors("lib/ash_typescript/rpc/error.ex", ast) do
    rel = "lib/ash_typescript/rpc/error.ex"

    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:defimpl, _, [{:__aliases__, _, [:AshTypescript, :Rpc, :Error]} | rest]} = node, acc ->
          for_alias =
            rest
            |> Enum.filter(&is_list/1)
            |> Enum.find_value(fn l -> Keyword.get(l, :for) end)

          impl =
            case for_alias do
              {:__aliases__, _, parts} ->
                [cap("error.impl." <> Enum.join(parts, "."), "error", rel)]

              _ ->
                []
            end

          {node, impl ++ wire_types(rest, rel) ++ acc}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  defp errors(_, _), do: []

  defp wire_types(ast, rel) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:type, t} = node, acc when is_binary(t) ->
          {node, [cap("error.type.#{t}", "error", rel) | acc]}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  # (e) mix tasks + switches
  defp tasks("lib/mix/tasks/" <> file, ast) do
    rel = "lib/mix/tasks/" <> file

    name =
      file
      |> String.replace_suffix(".ex", "")
      |> String.replace_prefix("ash_typescript.", "")

    {_, flags} =
      Macro.prewalk(ast, [], fn
        {:switches, list} = node, acc when is_list(list) ->
          ids = for {k, _} <- list, is_atom(k), do: cap("task.#{name}.flag.#{k}", "task", rel)
          {node, ids ++ acc}

        node, acc ->
          {node, acc}
      end)

    [cap("task.#{name}", "task", rel) | flags]
  end

  defp tasks(_, _), do: []

  # (f)(g)(j) module-shaped sections
  defp modules(rel, ast) do
    names = defmodule_names(ast)

    case section_of(rel) do
      nil ->
        []

      {section, strip} ->
        for n <- names do
          rest = n |> String.replace_prefix("AshTypescript.", "") |> strip.()
          cap("#{section}.#{rest_label(section, rest)}", section, rel)
        end
    end
  end

  defp rest_label("verifier", rest), do: rest |> String.split(".") |> List.last()
  defp rest_label("transformer", rest), do: rest |> String.split(".") |> List.last()
  defp rest_label("codegen", rest), do: "module." <> rest
  defp rest_label("installer", rest), do: "module." <> rest
  defp rest_label("runtime", rest), do: "module." <> rest

  defp section_of("lib/mix/tasks/" <> _), do: nil

  defp section_of(rel) do
    cond do
      String.contains?(rel, "/verifiers/") or String.ends_with?(rel, "verifier_checker.ex") ->
        {"verifier", & &1}

      String.contains?(rel, "/transformers/") ->
        {"transformer", & &1}

      String.contains?(rel, "/installer/") ->
        {"installer", & &1}

      String.contains?(rel, "/codegen/") or String.ends_with?(rel, "/codegen.ex") ->
        {"codegen", & &1}

      true ->
        {"runtime", & &1}
    end
  end

  defp defmodule_names(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _, [{:__aliases__, _, parts} | _]} = node, acc ->
          {node, [Enum.map_join(parts, ".", &to_string/1) | acc]}

        node, acc ->
          {node, acc}
      end)

    # nested defmodule names are relative; keep only the outermost-qualified ones
    acc |> Enum.filter(&String.starts_with?(&1, "AshTypescript")) |> Enum.uniq()
  end

  # (h) exported TS names in emitted templates
  defp tstypes(rel, ast) do
    if String.contains?(rel, "/installer/"), do: [], else: scan_templates(rel, ast)
  end

  defp scan_templates(rel, ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:@, _, [{attr, _, _}]}, acc when attr in [:moduledoc, :doc, :typedoc] -> {nil, acc}
        node, acc when is_binary(node) -> {node, scan_ts(node, rel) ++ acc}
        node, acc -> {node, acc}
      end)

    acc
  end

  defp scan_ts(str, rel) do
    for [_, name] <- Regex.scan(@ts_export, str), do: cap("tstype.#{name}", "tstype", rel)
  end
end
