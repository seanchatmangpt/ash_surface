defmodule AshSurface.Manifest.ActionManifest do
  @moduledoc """
  ash_surface-native machine-readable action manifest (KD-07).

  Counterpart of `AshTypescript.Rpc.Codegen.JsonManifestGenerator`, built from data
  ash_surface already owns: the prepared `Ash.Info.Manifest` handle
  (`RuntimeParity.RequestedFields.Compat.prepare/1`) plus the RPC entry table
  (`RuntimeParity.Rpc.Pipeline.entry/4`). It reads facts only (no action runs: README,
  "it never actuates") and emits JSON-shaped data; `to_json/1` encodes it with the repo's
  canonical-JSON law, so equal manifests are byte-identical (no `generatedAt` wall clock,
  no TypeScript type/variant/file names: ash_surface generates no `.ts`).

  Per action: `functionName`, `name`, `actionType`, `get`, `resource`, `namespace`,
  `description`, `see`, `deprecated` (false | true | message), `input`
  (`none | optional | required`), `pagination`
  (`supported/required/offset/keyset/countable/get`), `enableFilter`, `enableSort`,
  `hasFields`, `metadataFields`. Per resource: many-relationship query capabilities
  (`pagination` mixed|offset|keyset|none, `filterable`, `sortable`).
  """

  alias Ash.Info.Manifest
  alias AshSurface.CanonicalJSON
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.Rpc.Support

  @version "1.0"

  @doc """
  Build the JSON-shaped manifest (string keys) for `entries` over a manifest or handle.

  Option `:routes` (string-keyed typed-controller route maps, see
  `AshSurface.Compiler.RouteSchema`) adds a sorted `"routes"` list of route descriptors:
  `name`, `method`, `path`, `pathParams`, `mutation` (non get/head), `hasInput`, `hasResponse`,
  `inputKind` (`none|query|body`), `namespace`, `description`, `see`, `deprecated`,
  `zodSchemaName` (route `zod_schema_name` override, else lowerCamel `<name>Response`).
  An inadmissible route set raises `ArgumentError`. Without `:routes` no key is emitted.
  """
  @spec build(Manifest.t() | map(), [map()], keyword()) :: map()
  def build(manifest_or_handle, entries, opts \\ []) when is_list(entries) do
    handle = Compat.prepare(manifest_or_handle)

    actions =
      entries
      |> Enum.map(&action_entry(handle, &1))
      |> Enum.sort_by(& &1["functionName"])

    resources =
      entries
      |> Enum.map(& &1.resource)
      |> Enum.uniq()
      |> Map.new(fn resource -> {short(resource), resource_entry(handle, resource)} end)

    namespaces =
      actions |> Enum.map(& &1["namespace"]) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()

    base = %{
      "version" => @version,
      "actions" => actions,
      "resources" => resources,
      "namespaces" => namespaces
    }

    case Keyword.fetch(opts, :routes) do
      {:ok, routes} -> Map.put(base, "routes", route_entries(routes))
      :error -> base
    end
  end

  defp route_entries(routes) do
    built =
      case AshSurface.Compiler.RouteSchema.build(routes, base_path: "", mode: :full) do
        {:ok, built} -> built
        {:error, reason} -> raise ArgumentError, "inadmissible routes: #{inspect(reason)}"
      end

    inputs = Map.new(routes, &{&1["name"], &1})

    built
    |> Enum.map(&route_entry(&1, inputs[&1["name"]] || %{}))
    |> Enum.sort_by(&{&1["path"], &1["method"]})
  end

  defp route_entry(b, raw) do
    mutation? = b["method"] not in ["get", "head"]
    input_kind = input_kind(b, mutation?)

    %{
      "name" => b["name"],
      "method" => b["method"],
      "path" => b["path"],
      "pathParams" => b["path_params"],
      "mutation" => mutation?,
      "inputKind" => input_kind,
      "hasInput" => input_kind != "none",
      "hasResponse" => not is_nil(raw["returns"]),
      "namespace" => b["namespace"],
      "description" => b["description"] || "",
      "see" => List.wrap(raw["see"]),
      "deprecated" => deprecated(raw["deprecated"]),
      "zodSchemaName" =>
        b["zod_schema_name"] || function_name(to_string(b["name"]) <> "_response")
    }
  end

  @empty_object "z.object({}).strict()"
  defp input_kind(b, true), do: if(b["body"] == @empty_object, do: "none", else: "body")
  defp input_kind(b, false), do: if(b["query"] == @empty_object, do: "none", else: "query")

  @doc "Canonical JSON bytes (key-sorted, trailing newline)."
  @spec to_json(map()) :: String.t()
  def to_json(manifest), do: CanonicalJSON.encode(manifest) <> "\n"

  @doc "Function name of an rpc entry name: lowerCamelCase."
  @spec function_name(atom() | String.t()) :: String.t()
  def function_name(name) do
    {first, rest} = name |> to_string() |> Macro.camelize() |> String.split_at(1)
    String.downcase(first) <> rest
  end

  defp action_entry(handle, entry) do
    action = Map.fetch!(handle.action_lookup, {entry.resource, entry.action})
    get? = Map.get(entry, :get?, false) or Map.get(entry, :get_by, []) not in [nil, []]

    %{
      "functionName" => function_name(entry.name),
      "name" => to_string(entry.name),
      "actionType" => to_string(action.type),
      "get" => get?,
      "resource" => short(entry.resource),
      "namespace" => namespace(entry),
      "description" => present(Map.get(entry, :description)) || present(action.description) || "",
      "see" => (Map.get(entry, :see) || []) |> Enum.map(&function_name/1),
      "deprecated" => deprecated(Map.get(entry, :deprecated)),
      "input" => input_class(action),
      "pagination" => pagination(action, get?),
      "enableFilter" => action.type == :read and Map.get(entry, :enable_filter?, true),
      "enableSort" => action.type == :read and Map.get(entry, :enable_sort?, true),
      "hasFields" => has_fields?(action, handle.type_lookup),
      "metadataFields" => exposed_metadata(entry, action)
    }
  end

  # exposed metadata names are owned by the pipeline (show_metadata semantics)
  defp exposed_metadata(entry, action) do
    entry
    |> AshSurface.RuntimeParity.Rpc.Pipeline.exposed_metadata_fields(action)
    |> Enum.map(&to_string/1)
    |> Enum.sort()
  end

  defp namespace(entry) do
    case Map.get(entry, :namespace) || resource_namespace(entry.resource) do
      nil -> nil
      ns -> to_string(ns)
    end
  end

  defp resource_namespace(resource) do
    if Spark.Dsl.is?(resource, Ash.Resource) and AshSurface.Resource in Spark.extensions(resource),
      do: AshSurface.Resource.Info.effective_namespace(resource),
      else: nil
  end

  # an empty description is no description: it must fall through to the next source
  defp present(s) when is_binary(s) and s != "", do: s
  defp present(_), do: nil

  defp deprecated(nil), do: false
  defp deprecated(false), do: false
  defp deprecated(true), do: true
  defp deprecated(message) when is_binary(message), do: message

  defp input_class(%{inputs: inputs}) do
    inputs = inputs || []

    cond do
      inputs == [] -> "none"
      Enum.any?(inputs, & &1.required?) -> "required"
      true -> "optional"
    end
  end

  defp pagination(action, get?) do
    p = if action.type == :read and not get?, do: action.pagination, else: nil

    %{
      "supported" => not is_nil(p),
      "required" => (p && p.required?) || false,
      "offset" => (p && p.offset?) || false,
      "keyset" => (p && p.keyset?) || false,
      "countable" => (p && p.countable?) || false,
      "get" => get?
    }
  end

  defp has_fields?(%{type: :destroy}, _type_lookup), do: false

  defp has_fields?(%{type: :action} = action, type_lookup),
    do:
      match?(
        {:ok, _, _},
        Support.compute_action_returns_field_selectable_type?(action, type_lookup)
      )

  defp has_fields?(_action, _type_lookup), do: true

  defp resource_entry(handle, resource) do
    case Map.get(handle.resource_lookup, resource) do
      nil ->
        %{"relationships" => %{}}

      %Manifest.Resource{relationships: rels} ->
        many =
          for {name, %{cardinality: :many} = rel} <- rels, into: %{} do
            surface = Map.get(rel.custom || %{}, :ash_surface, %{})

            {to_string(name),
             %{
               "pagination" => to_string(Map.get(surface, :pagination, :none)),
               "filterable" => rel.filterable?,
               "sortable" => rel.sortable?
             }}
          end

        %{"relationships" => many}
    end
  end

  defp short(module), do: module |> Module.split() |> List.last()
end
