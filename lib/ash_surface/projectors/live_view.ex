# Ash admin-pattern human projection: structure maps as DATA, no Phoenix dependency.
#
# Locally declared until admitted as their own files (this projector is the only
# consumer today; move verbatim when promoted):
#   - `AshSurface.IR`           (canonical shape of lib/ash_surface/ir.ex)
#   - `AshSurface.Projector.IR` (behaviour of lib/ash_surface/projector/ir.ex)

defmodule AshSurface.Projectors.LiveView do
  @moduledoc """
  Ash admin-pattern human projection as DATA (no Phoenix dependency).

  `project_ir/2` folds a list of IRs (or a single IR) into deterministic
  navigation / table / form / relationship structure maps:

    - navigation groups from `presentation.group` (default `"Resources"`),
      ordered by `presentation.order`;
    - table columns from `schema.input` of the resource's primary read IR;
    - form fields from `schema.input` of create/update IRs, with widgets from
      `presentation.widget`;
    - relationships from `semantic.predicates["relationships"]`;
    - one action control per IR, gated by `capability.authority_required`.
      Controls are INTENT references (`surface_action_id`), never direct calls.

  Every collection is explicitly ordered (order, then name/id) so the
  projection is byte-stable under input permutation.
  """

  # Integrated truth: the canonical AshSurface.Projector.IR behaviour (v16)
  # folds kind-tagged IR node maps; this projector folds %AshSurface.IR{}
  # structs directly — a different, documented subject contract — so it
  # honestly does not declare the behaviour.

  @default_group "Resources"
  @default_order 0
  @form_action_types ["create", "update"]

  @type_widgets %{
    "string" => "text",
    "uuid" => "text",
    "integer" => "number",
    "float" => "number",
    "decimal" => "number",
    "boolean" => "toggle",
    "date" => "date",
    "datetime" => "datetime",
    "utc_datetime" => "datetime"
  }

  def project_ir(%AshSurface.IR{} = ir, opts), do: project_ir([ir], opts)

  def project_ir(irs, _opts) when is_list(irs) do
    with :ok <- validate_irs(irs),
         :ok <- validate_versions(irs) do
      {:ok, view(irs), meta(irs)}
    end
  end

  def project_ir(other, _opts), do: {:error, {:not_ir_input, other}}

  ## Projection

  defp view(irs) do
    by_resource =
      irs
      |> Enum.group_by(&resource_name/1)
      |> Enum.map(fn {name, resource_irs} -> {name, resource_block(name, resource_irs)} end)
      |> Map.new()

    %{
      "kind" => "ash_admin",
      "ir_version" => hd(irs).version,
      "digest" => view_digest(irs),
      "navigation" => navigation(by_resource),
      "resources" => by_resource
    }
  end

  defp meta(irs) do
    by_resource = Enum.group_by(irs, &resource_name/1)

    group_count =
      by_resource
      |> Enum.map(fn {_name, resource_irs} ->
        resource_irs |> representative() |> presentation_group()
      end)
      |> MapSet.new()
      |> MapSet.size()

    %{
      "projector" => inspect(__MODULE__),
      "resource_count" => map_size(by_resource),
      "group_count" => group_count,
      "action_count" => length(irs)
    }
  end

  ## Per-resource structure

  defp resource_block(name, resource_irs) do
    rep = representative(resource_irs)
    ordered = ordered_irs(resource_irs)

    %{
      "resource" => name,
      "label" => presentation_label(rep) || name,
      "group" => presentation_group(rep),
      "order" => effective_order(rep),
      "table" => table(ordered),
      "forms" => forms(ordered),
      "relationships" => relationships(ordered),
      "actions" => Enum.map(ordered, &action_control/1)
    }
  end

  defp table(ordered) do
    case Enum.find(ordered, &(&1.ash.action_type |> to_string() == "read")) do
      nil ->
        %{"surface_action_id" => nil, "format" => nil, "columns" => []}

      read ->
        %{
          "surface_action_id" => surface_action_id(read),
          "format" => read.presentation.format,
          "columns" => columns(read)
        }
    end
  end

  defp columns(%AshSurface.IR{} = ir) do
    ir.schema.input
    |> input_fields()
    |> Enum.map(fn {name, type, required} ->
      %{"name" => name, "type" => type, "required" => required}
    end)
    |> Enum.sort_by(& &1["name"])
  end

  defp forms(ordered) do
    ordered
    |> Stream.filter(&(to_string(&1.ash.action_type) in @form_action_types))
    |> Enum.map(fn ir ->
      %{
        "surface_action_id" => surface_action_id(ir),
        "action" => action_name(ir),
        "action_type" => ir.ash.action_type |> to_string(),
        "label" => presentation_label(ir),
        "order" => effective_order(ir),
        "format" => ir.presentation.format,
        "fields" => form_fields(ir)
      }
    end)
  end

  defp form_fields(%AshSurface.IR{} = ir) do
    widget = ir.presentation.widget

    ir.schema.input
    |> input_fields()
    |> Enum.map(fn {name, type, required} ->
      %{
        "name" => name,
        "type" => type,
        "required" => required,
        "widget" => widget_for(widget, name, type)
      }
    end)
    |> Enum.sort_by(& &1["name"])
  end

  defp widget_for(widget, name, type) when is_map(widget) do
    Map.get(widget, name) || Map.get(widget, to_string(name)) || default_widget(type)
  end

  defp widget_for(widget, _name, _type) when is_binary(widget) or is_atom(widget),
    do: to_string(widget)

  defp widget_for(_widget, _name, type), do: default_widget(type)

  defp default_widget(type), do: Map.get(@type_widgets, type, "text")

  defp relationships(ordered) do
    {rels, _} =
      Enum.reduce(ordered, {[], MapSet.new()}, fn ir, {acc, seen} ->
        Enum.reduce(declared_relationships(ir), {acc, seen}, fn rel, {acc, seen} ->
          key = {rel["name"], rel["destination"]}

          if MapSet.member?(seen, key) do
            {acc, seen}
          else
            {acc ++ [relationship(rel, ir)], MapSet.put(seen, key)}
          end
        end)
      end)

    rels
  end

  defp relationship(rel, %AshSurface.IR{} = ir) do
    %{
      "name" => rel["name"],
      "destination" => rel["destination"],
      "cardinality" => rel["cardinality"] || "many",
      "surface_action_id" => surface_action_id(ir)
    }
  end

  defp action_control(%AshSurface.IR{} = ir) do
    id = surface_action_id(ir)

    gated =
      AshSurface.IR.Capability.authority_required(ir.capability || %AshSurface.IR.Capability{})

    %{
      "surface_action_id" => id,
      "action" => action_name(ir),
      "action_type" => ir.ash.action_type |> to_string(),
      "label" => presentation_label(ir),
      "order" => effective_order(ir),
      "consequence_class" => ir.capability.consequence_class,
      "authority_required" => gated,
      "receipt_required" => !!ir.capability.receipt_required,
      # INTENT target only: no module, function, or route-to-code reference.
      "control" => %{
        "kind" => "intent",
        "intent_target" => id,
        "gated" => gated,
        "authority_gate" => if(gated, do: "REQUIRED", else: "NOT_REQUIRED")
      }
    }
  end

  ## Navigation

  defp navigation(by_resource) do
    groups =
      by_resource
      |> Enum.map(fn {_name, block} -> block end)
      |> Enum.group_by(& &1["group"])
      |> Enum.map(fn {group, blocks} ->
        resources =
          blocks
          |> Enum.sort_by(&{&1["order"], &1["resource"]})
          |> Enum.map(fn block ->
            %{
              "resource" => block["resource"],
              "label" => block["label"],
              "path" => nav_path(block["resource"]),
              "order" => block["order"]
            }
          end)

        %{
          "group" => group,
          "order" => blocks |> Enum.map(& &1["order"]) |> Enum.min(),
          "resources" => resources
        }
      end)
      |> Enum.sort_by(&{&1["order"], &1["group"]})

    %{"groups" => groups}
  end

  ## IR accessors (nil-safe: sub-structs default to empty facts)

  defp representative(resource_irs) do
    Enum.min_by(resource_irs, &{effective_order(&1), surface_action_id(&1)})
  end

  defp ordered_irs(resource_irs),
    do: Enum.sort_by(resource_irs, &{effective_order(&1), surface_action_id(&1)})

  defp effective_order(%AshSurface.IR{} = ir),
    do: ir.presentation.order || @default_order

  defp presentation_group(%AshSurface.IR{} = ir),
    do: ir.presentation.group || @default_group

  defp presentation_label(%AshSurface.IR{} = ir), do: ir.presentation.label

  defp action_name(%AshSurface.IR{} = ir), do: to_string(ir.ash.action)

  defp resource_name(%AshSurface.IR{} = ir), do: module_name(ir.ash.resource)

  defp surface_action_id(%AshSurface.IR{} = ir),
    do: "#{resource_name(ir)}##{action_name(ir)}"

  defp module_name(module) when is_atom(module), do: module |> Module.split() |> Enum.join(".")
  defp module_name(name) when is_binary(name), do: name

  defp input_fields(nil), do: []

  defp input_fields(input) when is_map(input) do
    Enum.map(input, fn {name, spec} ->
      {to_string(name), field_type(spec), field_required(spec)}
    end)
  end

  defp field_type(%{"type" => type}), do: to_string(type)
  defp field_type(%{type: type}), do: to_string(type)
  defp field_type(type) when is_binary(type) or is_atom(type), do: to_string(type)
  defp field_type(_), do: "string"

  defp field_required(%{"required" => required}), do: !!required
  defp field_required(%{required: required}), do: !!required
  defp field_required(_), do: false

  defp declared_relationships(%AshSurface.IR{} = ir) do
    ir.semantic.predicates |> normalize_predicates() |> Map.get("relationships", [])
  end

  defp normalize_predicates(nil), do: %{}

  defp normalize_predicates(predicates) when is_map(predicates) do
    Map.new(predicates, fn {k, v} -> {to_string(k), v} end)
  end

  defp nav_path(resource_name) when is_binary(resource_name) do
    "/" <> (resource_name |> String.replace(~r/[^a-zA-Z0-9]+/, "-") |> String.downcase())
  end

  ## Digest (byte-stable under input permutation)

  defp view_digest(irs) do
    entries =
      irs |> Enum.map(&{surface_action_id(&1), &1.digest}) |> Enum.sort()

    :erlang.term_to_binary({hd(irs).version, entries})
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  ## Validation (fail-closed)

  defp validate_irs(irs) do
    Enum.reduce_while(irs, :ok, fn
      %AshSurface.IR{} = ir, :ok ->
        case malformed_relationship(ir) do
          nil -> {:cont, :ok}
          entry -> {:halt, {:error, {:malformed_relationship, entry}}}
        end

      other, :ok ->
        {:halt, {:error, {:not_an_ir, other}}}
    end)
  end

  defp malformed_relationship(%AshSurface.IR{} = ir) do
    ir.semantic.predicates
    |> normalize_predicates()
    |> Map.get("relationships", [])
    |> Enum.find(fn rel ->
      not (is_map(rel) and is_binary(rel["name"]) and rel["name"] != "" and
             is_binary(rel["destination"]) and rel["destination"] != "")
    end)
  end

  defp validate_versions(irs) do
    versions = irs |> Enum.map(& &1.version) |> Enum.uniq() |> Enum.sort()

    case versions do
      [_] -> :ok
      many -> {:error, {:ir_version_conflict, many}}
    end
  end
end
