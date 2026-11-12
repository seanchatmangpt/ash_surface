defmodule AshSurface.Compiler.ValidationErrorSchema do
  @moduledoc """
  Recursive Zod rendering of per-type validation-error shapes (port of
  AshTypescript `Rpc.ValidationErrorSchemas.map_error_type/2`, Zod only).

  Input is a string-keyed type definition as `AshSurface.Compiler.EmbeddedSchema`
  takes (`%{"type" => %{"kind" => ..}}`; atom-keyed kind maps are accepted too).

  Mapping (error expression for a value of that type):

    * scalars / enums / unknown -> `z.array(z.string())` (messages)
    * `array` -> `z.array(<item errors>)`
    * `embedded_resource` / `typed_struct` / `typed_map` / `map` / `struct` /
      `keyword` / `tuple` with fields -> `z.object({<field>: <errors>.optional()}).strict()`
    * containers without fields -> `z.record(z.string(), z.unknown())`
    * `union` -> object keyed by member name, each `<member errors>.optional()`
      (no members -> record)
    * `resource` / struct whose `instance_of` is a resource -> INLINED from
      `opts[:resources]` (`%{"My.Todo" => [field, ...]}`), never a bare
      identifier (`ZodGuard` refuses name tokens other than `z`/`true`/`false`/
      `null`, so identifier references could never be admitted). A name absent
      from `:resources` degrades to the record fallback.
    * an `embedded_resource` without inline fields resolves through
      `opts[:resources]` (`%{"My.Embedded" => [field, ...]}`); revisiting a
      resource already on the path ends in the record fallback (no `z.lazy`);
      `opts[:cycle_depth]` (default 0) lets each resource re-enter that many
      times first. Expansion larger than `opts[:max_bytes]` (default 1_000_000)
      yields `{:error, {:schema_too_large, bytes, cap}}` from `render/2`
      (`map_error_type/2` returns the same typed error).

  Field names are formatted with `opts[:formatter]` (default `:camel_case`).
  Output is byte-deterministic (map-form fields sorted) and `render/2` proves
  every expression with `AshSurface.Projectors.JS.ZodGuard`.
  """

  alias AshSurface.Compiler.ZodType
  alias AshSurface.ErrorFormatter
  alias AshSurface.Projectors.JS.ZodGuard

  @containers ~w(embedded_resource typed_struct typed_map map struct keyword tuple)
  @record "z.record(z.string(), z.unknown())"
  @default_max_bytes 1_000_000

  @doc "Errors expression for a definition (unguarded; see `render/2`)."
  @spec map_error_type(map() | nil, keyword()) :: {:ok, String.t()} | {:error, term()}
  def map_error_type(definition, opts \\ []), do: build(definition, opts)

  defp build(definition, opts) do
    {:ok, go(definition, state(opts), [])}
  catch
    {:schema_too_large, bytes, cap} -> {:error, {:schema_too_large, bytes, cap}}
    {:denied_field_name, name} -> {:error, {:denied_field_name, name}}
  end

  @doc "Like `map_error_type/2` but guard-proven: `{:ok, expr} | {:error, {:zod_guard_refused, expr, reason}}`."
  @spec render(map() | nil, keyword()) :: {:ok, String.t()} | {:error, term()}
  def render(definition, opts \\ []) do
    with {:ok, expr} <- build(definition, opts) do
      case ZodGuard.expression(expr) do
        :ok -> {:ok, expr}
        {:error, reason} -> {:error, {:zod_guard_refused, expr, reason}}
      end
    end
  end

  defp state(opts) do
    %{
      resources: Keyword.get(opts, :resources, %{}),
      depth: Keyword.get(opts, :cycle_depth, 0),
      max_bytes: Keyword.get(opts, :max_bytes, @default_max_bytes),
      formatter: Keyword.get(opts, :formatter, :camel_case)
    }
  end

  # Leaf messages come from the shared ZodType table (single source for scalars).
  defp leaf, do: "z.array(#{ZodType.fragment(%{"type" => %{"kind" => "string"}})})"

  defp go(nil, _st, _path), do: leaf()

  defp go(%{"type" => %{"kind" => _} = type}, st, path), do: kind(type, st, path)
  defp go(%{type: %{kind: _} = type}, st, path), do: kind(stringify(type), st, path)
  defp go(%{"kind" => _} = type, st, path), do: kind(type, st, path)
  defp go(%{kind: _} = type, st, path), do: kind(stringify(type), st, path)
  defp go(_other, _st, _path), do: leaf()

  defp stringify(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), stringify(v)} end)

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(other), do: other

  defp kind(%{"kind" => "array"} = type, st, path) do
    item = type["items"] || type["item"] || type["item_type"]
    "z.array(#{go(item, st, path)})"
  end

  defp kind(%{"kind" => "union"} = type, st, path) do
    case type["members"] || type["types"] do
      members when is_list(members) and members != [] ->
        body =
          members
          |> Enum.map(fn m ->
            name = to_string(m["name"] || m[:name])
            {name, go(m["type"] || m[:type] || m, st, path)}
          end)
          |> object_body(st)

        "z.object({#{body}}).strict()"

      _ ->
        @record
    end
  end

  defp kind(%{"kind" => "resource"} = type, st, path), do: reference(type, st, path)

  defp kind(%{"kind" => k} = type, st, path) when k in @containers do
    cond do
      k in ["struct", "embedded_resource"] and resource_ref?(type) ->
        reference(type, st, path)

      true ->
        container(type, st, path)
    end
  end

  defp kind(_type, _st, _path), do: leaf()

  defp resource_ref?(%{"fields" => [_ | _]}), do: false
  defp resource_ref?(%{"kind" => "embedded_resource"}), do: false
  defp resource_ref?(%{"resource?" => false}), do: false
  defp resource_ref?(%{"instance_of" => name}) when is_binary(name), do: true
  defp resource_ref?(_), do: false

  # Inline the referenced resource's fields (guard admits no bare identifiers).
  defp reference(type, st, path) do
    name = type["instance_of"] || type["resource"]

    if is_binary(name) and Map.has_key?(st.resources, name) do
      container(%{"kind" => "embedded_resource", "resource" => name}, st, path)
    else
      @record
    end
  end

  defp container(type, st, path) do
    key = type["resource"]

    cond do
      key != nil and Enum.count(path, &(&1 == key)) > st.depth ->
        @record

      true ->
        case fields_of(type, st) do
          [] ->
            @record

          fields ->
            body =
              fields
              |> Enum.map(fn f ->
                {field_name(f), go(f, st, if(key, do: path ++ [key], else: path)), wire?(f)}
              end)
              |> object_body(st)

            out = "z.object({#{body}}).strict()"
            bytes = byte_size(out)
            if bytes > st.max_bytes, do: throw({:schema_too_large, bytes, st.max_bytes})
            out
        end
    end
  end

  defp field_name(f) when is_map(f), do: to_string(f["name"] || f[:name])
  defp field_name(_), do: ""

  # `"wire" => true`: the name is already wire-spelled; the formatter must not run again.
  defp wire?(f) when is_map(f), do: (f["wire"] || f[:wire]) == true
  defp wire?(_), do: false

  defp fields_of(%{"fields" => fields}, _st) when is_list(fields) and fields != [],
    do: Enum.map(fields, &field_map/1)

  defp fields_of(%{"fields" => fields}, _st) when is_map(fields) and map_size(fields) > 0 do
    fields
    |> Enum.sort_by(fn {name, _} -> to_string(name) end)
    |> Enum.map(fn {name, f} -> f |> field_map() |> Map.put_new("name", to_string(name)) end)
  end

  defp fields_of(%{"kind" => "embedded_resource", "resource" => name}, st) when is_binary(name),
    do: st.resources |> Map.get(name, []) |> Enum.map(&field_map/1)

  defp fields_of(_type, _st), do: []

  # Atom-keyed field maps -> string keys (top level + `type`); non-maps -> leaf.
  defp field_map(f) when is_map(f) and not is_struct(f) do
    Map.new(f, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), field_type(k, v)}
      {k, v} -> {k, v}
    end)
  end

  defp field_map(_), do: %{"name" => "", "type" => %{"kind" => "string"}}

  defp field_type(:type, %{} = t) when not is_struct(t), do: stringify(t)
  defp field_type(_, v), do: v

  defp object_body(pairs, st) do
    Enum.map_join(pairs, ", ", fn pair ->
      {name, expr, wire?} =
        case pair do
          {n, e, w} -> {n, e, w}
          {n, e} -> {n, e, false}
        end

      formatted = if wire?, do: name, else: ErrorFormatter.format_name(name, st.formatter)
      if formatted == "__proto__", do: throw({:denied_field_name, "__proto__"})
      "#{key(formatted)}: #{expr}.optional()"
    end)
  end

  defp key(name) do
    if Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, name) and
         not String.starts_with?(name, "__"),
       do: name,
       else: Jason.encode!(name)
  end
end
