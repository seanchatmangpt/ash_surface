defmodule AshSurface.Compiler.RouteSchema do
  @moduledoc """
  Descriptor-only per-route Zod schemas (params / query / body / response).

  Input is a list of string-keyed route maps:

      %{"name" => "show", "method" => "get", "path" => "/users/:id",
        "arguments" => [%{"name" => "id", "type" => %{"kind" => "uuid"}}],
        "returns" => %{"type" => %{"kind" => "string"}}}

  Path params become the `params` object; remaining arguments go to `query`
  for GET/HEAD and to `body` otherwise. No fetch wrapper is emitted.

  A missing `"allow_nil?"` means nullable (the Ash DSL default), so a path
  param must say `"allow_nil?" => false`; non-path nullable arguments render
  `.nullable().optional()`. `"returns"` is a definition map (optionally with
  `"constraints"`) or a bare kind string paired with route-level `"constraints"`.
  A route may list `"mounts"` (paths); params present at only some mounts must
  be nullable. Descriptors carry `"name"` and `"scope_prefix"`.

  Admission errors: `{:duplicate_route, verb, path}`,
  `{:duplicate_route_name, name, scope_prefix}`,
  `{:path_param_missing_arg, route, param}`, `{:path_param_nullable, route, param}`,
  `{:path_param_sometimes_present, route, param}`.
  """

  alias AshSurface.Compiler.RouteSchema.{Fold, Introspector}
  alias AshSurface.Compiler.ZodType

  @query_verbs ~w(get head)

  @doc """
  Builds descriptors. Options (defaults read from `AshSurface.Config`):

    * `:base_path` - `""`, a string, or `{:runtime_expr, js}` (`typed_controller_base_path`).
      Non-empty adds `"base_path"` and `"full_path"` (static) or `"path_template"`
      (runtime expression, `${_basePath}` prefix).
    * `:mode` - `:full | :paths_only` (`typed_controller_mode`). `:paths_only` drops the
      params/query/body/response schemas and keeps path descriptors.
    * `:namespace` - controller-level default namespace; a route's own `namespace` wins.
    * `:verify` - `true` runs `RouteSchema.Verifier.verify/1` first (default `false`).
  """
  @spec build([map()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def build(routes, opts \\ [])

  def build(routes, opts) when is_list(routes) do
    base = Keyword.get_lazy(opts, :base_path, &AshSurface.Config.typed_controller_base_path/0)
    mode = Keyword.get_lazy(opts, :mode, &AshSurface.Config.typed_controller_mode/0)

    with :ok <- if(opts[:verify], do: __MODULE__.Verifier.verify(routes), else: :ok),
         routes = default_namespace(routes, opts[:namespace]),
         :ok <- check_duplicates(routes),
         :ok <- check_names(routes),
         :ok <- check_valibot_names(routes),
         {:ok, built} <- build_all(routes) do
      {:ok, Enum.map(built, &apply_base_and_mode(&1, base, mode))}
    end
  end

  def build(other, _opts), do: {:error, {:routes_not_a_list, other}}

  # Controller-level default `namespace` (ash_typescript `typed_controller.namespace`): a route's
  # own namespace wins; routes without one inherit the default.
  defp default_namespace(routes, ns) when is_binary(ns) and ns != "",
    do: Enum.map(routes, &if(str(&1["namespace"]), do: &1, else: Map.put(&1, "namespace", ns)))

  defp default_namespace(routes, _ns), do: routes

  # `valibot_schema_name` is carried verbatim into the descriptor, so it must be a JS identifier.
  defp check_valibot_names(routes) do
    Enum.find_value(routes, :ok, fn route ->
      case route["valibot_schema_name"] do
        nil ->
          nil

        name when is_binary(name) ->
          if name =~ ~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/,
            do: nil,
            else: {:error, {:invalid_valibot_schema_name, route["name"], name}}

        other ->
          {:error, {:invalid_valibot_schema_name, route["name"], other}}
      end
    end)
  end

  defp apply_base_and_mode(route, base, mode) do
    route
    |> apply_base(base)
    |> then(fn r ->
      if mode == :paths_only,
        do:
          r |> Map.drop(["params", "query", "body", "response"]) |> Map.put("mode", "paths_only"),
        else: r
    end)
  end

  defp apply_base(route, ""), do: route
  defp apply_base(route, nil), do: route

  defp apply_base(route, base) when is_binary(base),
    do: route |> Map.put("base_path", base) |> Map.put("full_path", base <> route["path"])

  defp apply_base(route, {:runtime_expr, expr}) when is_binary(expr),
    do:
      route
      |> Map.put("base_path", %{"runtime_expr" => expr})
      |> Map.put("path_template", "${_basePath}" <> route["path"])

  @doc """
  Plans controller namespace files from built descriptors: consumer of
  `enable_controller_namespace_files` / `controller_namespace_output_dir`. Returns `[]`
  when disabled or no output dir; else `[%{"file" => path, "namespace" => ns, "routes" => names}]`.
  """
  @spec namespace_plan([map()], keyword()) :: [map()]
  def namespace_plan(built, opts \\ []) do
    enabled =
      Keyword.get_lazy(opts, :enabled, &AshSurface.Config.enable_controller_namespace_files/0)

    dir =
      Keyword.get_lazy(opts, :output_dir, &AshSurface.Config.controller_namespace_output_dir/0)

    if enabled and is_binary(dir) and dir != "" do
      built
      |> Enum.filter(& &1["namespace"])
      |> Enum.group_by(& &1["namespace"])
      |> Enum.sort()
      |> Enum.map(fn {ns, rs} ->
        %{
          "file" => Path.join(dir, ns <> ".json"),
          "namespace" => ns,
          "routes" => rs |> Enum.map(& &1["name"]) |> Enum.sort()
        }
      end)
    else
      []
    end
  end

  @doc "Extracts `:name` and glob `*name` path parameters from a route path."
  @spec path_params(String.t()) :: [String.t()]
  def path_params(path),
    do: Regex.scan(~r{(?:\A|/)[:*](\w+)}, path) |> Enum.map(fn [_, p] -> p end)

  @doc "Delegates to `AshSurface.Compiler.RouteSchema.Introspector.introspect_router/1`."
  @spec introspect_router(module()) :: {:ok, [map()]} | {:error, term()}
  defdelegate introspect_router(router), to: Introspector

  defp verb(route), do: route |> Map.get("method", "get") |> to_string() |> String.downcase()

  defp check_duplicates(routes) do
    routes
    |> Enum.map(&{verb(&1), &1["path"]})
    |> Enum.reduce_while(MapSet.new(), fn key, seen ->
      if MapSet.member?(seen, key),
        do: {:halt, {:error, {:duplicate_route, elem(key, 0), elem(key, 1)}}},
        else: {:cont, MapSet.put(seen, key)}
    end)
    |> case do
      {:error, _} = e -> e
      _ -> :ok
    end
  end

  defp check_names(routes) do
    routes
    |> Enum.reject(&is_nil(&1["name"]))
    |> Enum.reduce_while(MapSet.new(), fn r, seen ->
      key = {r["name"], r["scope_prefix"]}

      if MapSet.member?(seen, key),
        do: {:halt, {:error, {:duplicate_route_name, elem(key, 0), elem(key, 1)}}},
        else: {:cont, MapSet.put(seen, key)}
    end)
    |> case do
      {:error, _} = e -> e
      _ -> :ok
    end
  end

  defp build_all(routes) do
    Enum.reduce_while(routes, {:ok, []}, fn route, {:ok, acc} ->
      case build_one(route) do
        {:ok, built} -> {:cont, {:ok, [built | acc]}}
        {:error, _} = e -> {:halt, e}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.sort_by(acc, &{&1["path"], &1["method"]})}
      e -> e
    end
  end

  defp build_one(route) do
    name = route["name"]
    path = route["path"]
    args = Map.get(route, "arguments", [])
    pparams = path_params(path)

    with :ok <- check_arguments(name, args),
         {:ok, args} <- Fold.fold_arguments(name, args),
         :ok <- Fold.check_returns(route, route),
         by_name = Map.new(args, &{&1["name"], &1}),
         :ok <- check_path_params(name, pparams, by_name),
         :ok <- check_mounts(name, pparams, by_name, route["mounts"]),
         :ok <- check_emitted(name, args) do
      {path_args, rest} = Enum.split_with(args, &(&1["name"] in pparams))
      m = verb(route)
      {query, body} = if m in @query_verbs, do: {rest, []}, else: {[], rest}

      {:ok,
       %{
         "name" => name,
         "scope_prefix" => route["scope_prefix"],
         "method" => m,
         "path" => path,
         "path_params" => pparams,
         "field_names" => %{
           "params" => inverse(path_args),
           "query" => inverse(query),
           "body" => inverse(body)
         },
         "params" => object(path_args, :path),
         "query" => object(query, :query),
         "body" => object(body, :input),
         "response" => response(route)
       }
       |> Map.merge(presentation(route))}
    end
  end

  # Presentation passthrough (ash_typescript route options deprecated/description/see/
  # namespace/zod_schema_name). `description` is also applied to the response fragment as
  # `.describe(...)`; `jsdoc` renders `@deprecated`/`@see`; `schema_declaration` names the
  # response schema const. Absent options add no keys.
  defp presentation(route) do
    desc = str(route["description"])
    dep = route["deprecated"]
    see = str(route["see"])
    zname = str(route["zod_schema_name"])

    %{}
    |> put_if("description", desc)
    |> put_if("deprecated", if(dep in [nil, false], do: nil, else: dep))
    |> put_if("see", see)
    |> put_if("namespace", str(route["namespace"]))
    |> put_if("zod_schema_name", zname)
    |> put_if("valibot_schema_name", str(route["valibot_schema_name"]))
    |> put_if("jsdoc", jsdoc(desc, dep, see))
    |> then(fn m ->
      resp = response(route)
      resp = if desc, do: resp <> ".describe(" <> Jason.encode!(desc) <> ")", else: resp
      m = if desc, do: Map.put(m, "response", resp), else: m
      if zname, do: Map.put(m, "schema_declaration", "export const #{zname} = #{resp};"), else: m
    end)
  end

  defp str(s) when is_binary(s) and s != "", do: s
  defp str(_), do: nil

  defp put_if(m, _k, nil), do: m
  defp put_if(m, k, v), do: Map.put(m, k, v)

  defp jsdoc(desc, dep, see) do
    lines =
      [desc]
      |> Kernel.++([
        case dep do
          true -> "@deprecated"
          d when is_binary(d) and d != "" -> "@deprecated " <> d
          _ -> nil
        end
      ])
      |> Kernel.++([see && "@see " <> see])
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&String.replace(&1, "*/", "* /"))

    if lines == [],
      do: nil,
      else: "/**\n" <> Enum.map_join(lines, "\n", &(" * " <> &1)) <> "\n */"
  end

  # Nil / non-string names and duplicate names are refused (last-wins would
  # silently drop an argument's schema).
  defp check_arguments(route, args) do
    Enum.reduce_while(args, MapSet.new(), fn a, seen ->
      case a["name"] do
        "__proto__" ->
          {:halt, {:error, {:denied_argument_name, route, "__proto__"}}}

        n when is_binary(n) and n != "" ->
          if MapSet.member?(seen, n),
            do: {:halt, {:error, {:duplicate_argument, route, n}}},
            else: {:cont, MapSet.put(seen, n)}

        other ->
          {:halt, {:error, {:argument_without_name, route, other}}}
      end
    end)
    |> case do
      {:error, _} = e -> e
      _ -> :ok
    end
  end

  defp nullable?(arg) do
    case {Map.get(arg, "allow_nil?"), Map.get(arg, "allow_nil")} do
      {false, _} -> false
      {nil, false} -> false
      _ -> true
    end
  end

  defp check_path_params(name, pparams, by_name) do
    Enum.find_value(pparams, :ok, fn
      "__proto__" -> {:error, {:denied_path_param_name, name, "__proto__"}}
      p -> if is_nil(by_name[p]), do: {:error, {:path_param_missing_arg, name, p}}
    end)
  end

  # Single mount: path params are always provided, so nullable is refused.
  # Multi mount: always-present => must be non-nullable; sometimes-present =>
  # must be nullable.
  defp check_mounts(name, pparams, by_name, mounts) do
    sets =
      case mounts do
        [_ | _] -> Enum.map(mounts, &MapSet.new(path_params(&1)))
        _ -> [MapSet.new(pparams)]
      end

    always = Enum.reduce(sets, &MapSet.intersection/2)
    any = Enum.reduce(sets, &MapSet.union/2)

    any
    |> Enum.sort()
    |> Enum.find_value(:ok, fn p ->
      arg = by_name[p]

      cond do
        is_nil(arg) ->
          {:error, {:path_param_missing_arg, name, p}}

        MapSet.member?(always, p) and nullable?(arg) ->
          {:error, {:path_param_nullable, name, p}}

        not MapSet.member?(always, p) and not nullable?(arg) ->
          {:error, {:path_param_sometimes_present, name, p}}

        true ->
          nil
      end
    end)
  end

  # Reference parity (ash_typescript typed_controller/codegen/route_renderer.ex:147,357,381,417):
  # every client-facing argument key (path object, query, body) is `format_output_field(arg.name)`;
  # the router path template (`path`, `path_params`) keeps the router's verbatim placeholders and
  # the client maps formatted names back (request_handler.ex:324). Emitted once, here.
  defp emitted_name(a), do: AshSurface.FieldName.emitted(a["name"])

  # Inverse table: client (emitted) name => server (declared) name.
  defp inverse(args), do: Map.new(args, &{emitted_name(&1), &1["name"]})

  defp check_emitted(route, args) do
    AshSurface.Compiler.EmittedKeys.check(
      Enum.map(args, &{&1["name"], emitted_name(&1)}),
      {:route, route}
    )
  end

  defp object(args, mode) do
    fields =
      args
      |> Enum.sort_by(&emitted_name/1)
      |> Enum.map_join(", ", fn a ->
        "#{object_key(emitted_name(a))}: #{coerce(ZodType.fragment(arg_def(a, mode)), mode)}"
      end)

    "z.object({#{fields}}).strict()"
  end

  # JS object-literal key: bare identifier when safe, JSON-quoted otherwise.
  # `__proto__` never reaches here: check_arguments/2 refuses it (ZodGuard denies the key).
  defp object_key(name) do
    if Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, name), do: name, else: Jason.encode!(name)
  end

  # Path and query values arrive as strings over HTTP. ash_typescript has no
  # coercion (no `coerce` in its route handling), so a numeric path/query arg
  # there rejects every real request. Numeric args are preprocessed from
  # non-blank numeric strings; blank strings are NOT coerced to 0.
  # Strict decimal grammar before Number(): hex/binary/octal/exponent/whitespace/
  # Infinity/"-0" stay strings and fail zod. Integers: digits; others add a fraction.
  defp coerce("z.number(" <> _ = frag, mode) when mode in [:path, :query] do
    re =
      if String.contains?(frag, ".int()"),
        do: "^(?!-0+$)-?\\d+$",
        else: "^(?!-0+(\\.0+)?$)-?\\d+(\\.\\d+)?$"

    ~s|z.preprocess((v) => (typeof v === "string" && /#{re}/.test(v) ? Number(v) : v), #{frag})|
  end

  defp coerce(frag, _mode), do: frag

  defp arg_def(a, mode) do
    nullable = nullable?(a)
    a = Map.put(a, "allow_nil?", nullable)
    if mode in [:input, :query] and nullable, do: Map.put(a, "optional", true), else: a
  end

  defp response(route) do
    returns = Map.get(route, "returns")
    constraints = route["returns_constraints"] || route["constraints"]

    defn =
      case returns do
        %{} = m ->
          if constraints && !m["constraints"], do: Map.put(m, "constraints", constraints), else: m

        kind when is_binary(kind) ->
          %{"type" => %{"kind" => kind}, "constraints" => constraints || %{}}

        _ ->
          %{}
      end

    typed_fragment(defn)
  end

  # A declared `returns` shape (map/typed_map/struct/embedded fields, or an array of one) renders
  # a field-level strict object through EmbeddedSchema; undeclared shapes keep `ZodType.fragment/1`.
  defp typed_fragment(defn) do
    defn = wrap_bare_fields(defn)

    with true <- declared_fields?(defn),
         true <- AshSurface.Compiler.EmbeddedSchema.container?(defn),
         {:ok, expr} <- AshSurface.Compiler.EmbeddedSchema.render(defn) do
      expr
    else
      _ -> ZodType.fragment(defn)
    end
  end

  defp declared_fields?(%{"type" => %{"kind" => "array"} = t}),
    do: declared_fields?(item_def(t))

  defp declared_fields?(%{"type" => %{"fields" => f}}) when is_map(f) or is_list(f),
    do: f |> Enum.to_list() |> Enum.any?()

  defp declared_fields?(_), do: false

  defp item_def(%{"items" => %{"type" => _} = i}), do: i
  defp item_def(%{"items" => %{"kind" => _} = i}), do: %{"type" => i}
  defp item_def(_), do: %{}

  # Route authors may list a field as a bare type (`%{"kind" => "uuid"}`); the renderer takes
  # definitions (`%{"type" => ...}`).
  defp wrap_bare_fields(%{"type" => %{"kind" => "array"} = t} = d) do
    case item_def(t) do
      %{"type" => _} = item ->
        Map.put(d, "type", Map.put(t, "items", wrap_bare_fields(item)))

      _ ->
        d
    end
  end

  defp wrap_bare_fields(%{"type" => %{"fields" => fields} = t} = d) when is_map(fields) do
    wrapped =
      Map.new(fields, fn
        {k, %{"kind" => _} = bare} -> {k, wrap_bare_fields(%{"type" => bare})}
        {k, other} -> {k, wrap_bare_fields(other)}
      end)

    Map.put(d, "type", Map.put(t, "fields", wrapped))
  end

  defp wrap_bare_fields(d), do: d
end
