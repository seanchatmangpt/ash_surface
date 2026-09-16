# v35 — deepen v17's LiveView project_ir/2 contract (structure depth).
#
# The v17 projector (exp/v17, commit 2b93c85) is absent from this tree (base
# 282f3ca predates it), so its modules are declared LOCALLY below, deepened,
# mirroring v17's own "locally declared until admitted as standalone files"
# pattern. Deepened surfaces (no v17 case is duplicated here):
#
#   - relationship sections: navigable, labeled, deterministic ownership;
#   - pagination/windowing metadata presence on read tables (structure only);
#   - argument -> field mapping carrying declared defaults/placeholders;
#   - authority-gated controls ALWAYS reference surface_action_id, and the
#     emitted structure greps clean of module/function targets (in-test);
#   - empty state: zero admitted actions project an ok, navigable empty view.

defmodule AshSurface.LiveViewProjectorTest.IR do
  @moduledoc """
  Canonical intermediate representation of one projected Ash action.

  An IR is a pure fact set: Ash semantics (`ash`), semantic identity
  (`semantic`), capability boundary (`capability`), human presentation
  (`presentation`), and boundary schemas (`schema`). Projectors fold lists of
  IRs into consumer structure maps; they never rediscover Ash semantics.
  """

  defstruct [:version, :digest, :ash, :semantic, :capability, :presentation, :schema]

  defmodule Ash do
    @moduledoc "Ash action facts."
    defstruct [:resource, :action, :action_type, :inputs, :outputs, :policies]
    @type t :: %__MODULE__{}
  end

  defmodule Semantic do
    @moduledoc """
    Semantic identity facts.

    Relationship bindings ride in `predicates` under the `"relationships"` key
    as a list of `%{"name" => ..., "destination" => ..., "cardinality" => ...}`
    maps. Malformed entries are refused, not silently dropped.
    """
    defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]
    @type t :: %__MODULE__{}
  end

  defmodule Capability do
    @moduledoc "Capability boundary facts."
    defstruct [:capability_id, :consequence_class, :authority_required, :receipt_required]
    @type t :: %__MODULE__{}
  end

  defmodule Presentation do
    @moduledoc """
    Human presentation facts.

    `group` defaults to `"Resources"` (zero-config). `widget` may be a map
    (field name -> widget kind), a binary/atom (default widget for every
    field), or nil (widget derived from the field type). `order` defaults to 0.
    """
    defstruct [:label, :group, :order, :widget, :format]
    @type t :: %__MODULE__{}
  end

  defmodule Schema do
    @moduledoc """
    Boundary schema facts.

    `input` maps field name to either a type (binary/atom) or a spec map with
    `"type"` and optional `"required"`, `"default"`, `"placeholder"`.
    `zod`/`aria` are passthrough facts.
    """
    defstruct [:input, :output, :zod, :aria]
    @type t :: %__MODULE__{}
  end

  @type t :: %__MODULE__{
          version: String.t() | nil,
          digest: String.t() | nil,
          ash: Ash.t() | nil,
          semantic: Semantic.t() | nil,
          capability: Capability.t() | nil,
          presentation: Presentation.t() | nil,
          schema: Schema.t() | nil
        }
end

defmodule AshSurface.LiveViewProjectorTest.Projector.IR do
  @moduledoc """
  Behaviour for folding IR facts into consumer structure maps.

  A projector receives already-declared IR facts and returns pure data:
  `{:ok, structure_map, meta}` or `{:error, term}`. It must not embed direct
  invocation references (modules, functions, routes to code); action controls
  reference `surface_action_id` intent targets only.
  """

  @callback project_ir(
              AshSurface.LiveViewProjectorTest.IR.t() | [AshSurface.LiveViewProjectorTest.IR.t()],
              keyword()
            ) ::
              {:ok, map(), map()} | {:error, term()}
end

defmodule AshSurface.LiveViewProjectorTest.Projectors.LiveView do
  @moduledoc """
  Ash admin-pattern human projection as DATA (no Phoenix dependency).

  v17 contract, deepened in v35:

    - navigation groups from `presentation.group` (default `"Resources"`),
      ordered by `presentation.order`;
    - table columns from `schema.input` of the resource's primary read IR,
      each carrying declared `default`/`placeholder` argument facts;
    - read tables reserve pagination/windowing METADATA (structure only: an
      offset window, a default limit, and the sortable column names — no
      windowing behavior is claimed or embedded);
    - form fields from `schema.input` of create/update IRs, with widgets from
      `presentation.widget` and defaults/placeholders from the spec maps;
    - relationships from `semantic.predicates["relationships"]`, projected as
      navigable sections (label, destination, destination path), deduped by
      {name, destination} with the first ordered declaring IR owning the
      section;
    - one action control per IR, gated by `capability.authority_required`.
      Controls are INTENT references (`surface_action_id`), never direct calls;
    - zero admitted actions (empty IR list) project an ok, navigable empty
      view instead of crashing.

  Every collection is explicitly ordered (order, then name/id) so the
  projection is byte-stable under input permutation.
  """

  @behaviour AshSurface.LiveViewProjectorTest.Projector.IR

  @default_group "Resources"
  @default_order 0
  @default_limit 20
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

  @impl true
  def project_ir(%AshSurface.LiveViewProjectorTest.IR{} = ir, opts), do: project_ir([ir], opts)

  @impl true
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
      "ir_version" => ir_version(irs),
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
        %{"surface_action_id" => nil, "format" => nil, "columns" => [], "pagination" => nil}

      read ->
        columns = columns(read)

        %{
          "surface_action_id" => surface_action_id(read),
          "format" => read.presentation.format,
          "columns" => columns,
          # Structure-only windowing metadata: presence, never behavior.
          "pagination" => %{
            "window" => "offset",
            "default_limit" => @default_limit,
            "sortable" => Enum.map(columns, & &1["name"])
          }
        }
    end
  end

  defp columns(%AshSurface.LiveViewProjectorTest.IR{} = ir) do
    ir.schema.input
    |> input_fields()
    |> Enum.map(fn {name, type, required, default, placeholder} ->
      %{
        "name" => name,
        "type" => type,
        "required" => required,
        "default" => default,
        "placeholder" => placeholder
      }
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

  defp form_fields(%AshSurface.LiveViewProjectorTest.IR{} = ir) do
    widget = ir.presentation.widget

    ir.schema.input
    |> input_fields()
    |> Enum.map(fn {name, type, required, default, placeholder} ->
      %{
        "name" => name,
        "type" => type,
        "required" => required,
        "default" => default,
        "placeholder" => placeholder,
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

    Enum.sort_by(rels, & &1["name"])
  end

  defp relationship(rel, %AshSurface.LiveViewProjectorTest.IR{} = ir) do
    %{
      "name" => rel["name"],
      "label" => humanize(rel["name"]),
      "destination" => rel["destination"],
      "destination_path" => nav_path(rel["destination"]),
      "cardinality" => rel["cardinality"] || "many",
      "surface_action_id" => surface_action_id(ir)
    }
  end

  defp action_control(%AshSurface.LiveViewProjectorTest.IR{} = ir) do
    id = surface_action_id(ir)
    gated = !!ir.capability.authority_required

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

  defp effective_order(%AshSurface.LiveViewProjectorTest.IR{} = ir),
    do: ir.presentation.order || @default_order

  defp presentation_group(%AshSurface.LiveViewProjectorTest.IR{} = ir),
    do: ir.presentation.group || @default_group

  defp presentation_label(%AshSurface.LiveViewProjectorTest.IR{} = ir), do: ir.presentation.label

  defp action_name(%AshSurface.LiveViewProjectorTest.IR{} = ir), do: to_string(ir.ash.action)

  defp resource_name(%AshSurface.LiveViewProjectorTest.IR{} = ir),
    do: module_name(ir.ash.resource)

  defp surface_action_id(%AshSurface.LiveViewProjectorTest.IR{} = ir),
    do: "#{resource_name(ir)}##{action_name(ir)}"

  defp module_name(module) when is_atom(module), do: module |> Module.split() |> Enum.join(".")
  defp module_name(name) when is_binary(name), do: name

  defp input_fields(nil), do: []

  defp input_fields(input) when is_map(input) do
    Enum.map(input, fn {name, spec} ->
      {to_string(name), field_type(spec), field_required(spec), field_fact(spec, "default"),
       field_fact(spec, "placeholder")}
    end)
  end

  defp field_type(%{"type" => type}), do: to_string(type)
  defp field_type(%{type: type}), do: to_string(type)
  defp field_type(type) when is_binary(type) or is_atom(type), do: to_string(type)
  defp field_type(_), do: "string"

  defp field_required(%{"required" => required}), do: !!required
  defp field_required(%{required: required}), do: !!required
  defp field_required(_), do: false

  defp field_fact(spec, key) when is_map(spec) do
    case Map.get(spec, key) do
      nil -> Map.get(spec, field_atom(key))
      value -> value
    end
  end

  defp field_fact(_spec, _key), do: nil

  defp field_atom("default"), do: :default
  defp field_atom("placeholder"), do: :placeholder

  defp declared_relationships(%AshSurface.LiveViewProjectorTest.IR{} = ir) do
    ir.semantic.predicates |> normalize_predicates() |> Map.get("relationships", [])
  end

  defp normalize_predicates(nil), do: %{}

  defp normalize_predicates(predicates) when is_map(predicates) do
    Map.new(predicates, fn {k, v} -> {to_string(k), v} end)
  end

  defp nav_path(resource_name) when is_binary(resource_name) do
    "/" <> (resource_name |> String.replace(~r/[^a-zA-Z0-9]+/, "-") |> String.downcase())
  end

  defp humanize(name), do: name |> String.replace("_", " ") |> String.capitalize()

  ## Digest (byte-stable under input permutation; empty-safe)

  defp view_digest(irs) do
    entries =
      irs |> Enum.map(&{surface_action_id(&1), &1.digest}) |> Enum.sort()

    :erlang.term_to_binary({ir_version(irs), entries})
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp ir_version([]), do: nil
  defp ir_version([first | _]), do: first.version

  ## Validation (fail-closed; an empty list is a legal empty state)

  defp validate_irs(irs) do
    Enum.reduce_while(irs, :ok, fn
      %AshSurface.LiveViewProjectorTest.IR{} = ir, :ok ->
        case malformed_relationship(ir) do
          nil -> {:cont, :ok}
          entry -> {:halt, {:error, {:malformed_relationship, entry}}}
        end

      other, :ok ->
        {:halt, {:error, {:not_an_ir, other}}}
    end)
  end

  defp malformed_relationship(%AshSurface.LiveViewProjectorTest.IR{} = ir) do
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
      [] -> :ok
      [_] -> :ok
      many -> {:error, {:ir_version_conflict, many}}
    end
  end
end

defmodule AshSurface.LiveViewProjectorTest do
  @moduledoc """
  v35 deepening of v17's LiveView `project_ir/2` contract: relationship
  sections, pagination/windowing metadata presence (structure only),
  argument->field mapping with defaults/placeholders, surface_action_id-only
  authority-gated controls (grepped in-test), and the zero-admitted-actions
  empty state. v17's own cases (golden map, permutation, order flip,
  fail-closed, behaviour conformance) are not duplicated.
  """

  use ExUnit.Case, async: true

  alias AshSurface.LiveViewProjectorTest.IR
  alias AshSurface.LiveViewProjectorTest.Projectors.LiveView

  defp ir(resource, action, action_type, opts) do
    %IR{
      version: "26.9.15",
      digest: Keyword.get(opts, :digest, "digest-#{resource}-#{action}"),
      ash: %IR.Ash{
        resource: resource,
        action: action,
        action_type: action_type,
        inputs: Keyword.get(opts, :inputs, []),
        outputs: Keyword.get(opts, :outputs, []),
        policies: []
      },
      semantic: %IR.Semantic{
        subject_iri: "ash:#{resource}",
        capability_iri: "ash:#{resource}##{action}",
        predicates: Keyword.get(opts, :predicates, %{}),
        shape_id: "shape-#{resource}-#{action}",
        ontology: "ggen-marketplace:v26.9.15"
      },
      capability: %IR.Capability{
        capability_id: "#{resource}##{action}",
        consequence_class: Keyword.get(opts, :consequence_class, "OBSERVE"),
        authority_required: Keyword.get(opts, :authority_required, false),
        receipt_required: Keyword.get(opts, :receipt_required, false)
      },
      presentation: %IR.Presentation{
        label: Keyword.get(opts, :label, to_string(action)),
        group: Keyword.get(opts, :group),
        order: Keyword.get(opts, :order),
        widget: Keyword.get(opts, :widget),
        format: Keyword.get(opts, :format)
      },
      schema: %IR.Schema{
        input: Keyword.get(opts, :input, %{}),
        output: Keyword.get(opts, :output, %{}),
        zod: nil,
        aria: nil
      }
    }
  end

  # 2-resource fixture: Accounts.Tenant (4 actions; read + update both declare
  # relationships, update re-declares "users" to prove dedup/ownership) and
  # Accounts.User (2 actions) in a separate navigation group.
  defp fixture_irs do
    [
      ir(Accounts.Tenant, :read, :read,
        group: "Accounts",
        label: "Tenants",
        order: 1,
        format: "table",
        input: %{
          "name" => %{"type" => "string", "required" => true},
          "page" => %{"type" => "integer", "default" => 1, "placeholder" => "page number"}
        },
        predicates: %{
          "relationships" => [
            %{"name" => "users", "destination" => "Accounts.User"},
            %{
              "name" => "billing_profile",
              "destination" => "Accounts.BillingProfile",
              "cardinality" => "one"
            }
          ]
        }
      ),
      ir(Accounts.User, :read, :read,
        group: "People",
        label: "Users",
        order: 2,
        format: "table",
        input: %{"email" => %{"type" => "string", "required" => true}}
      ),
      ir(Accounts.Tenant, :create, :create,
        group: "Accounts",
        label: "New tenant",
        order: 3,
        format: "form",
        widget: %{"name" => "text", "subdomain" => "slug"},
        input: %{
          "name" => %{
            "type" => "string",
            "required" => true,
            "default" => "New tenant",
            "placeholder" => "Acme Inc"
          },
          "subdomain" => %{"type" => "string", "placeholder" => "acme"},
          "active" => %{"type" => "boolean", "default" => true}
        },
        consequence_class: "DO",
        authority_required: true,
        receipt_required: true
      ),
      ir(Accounts.Tenant, :update, :update,
        group: "Accounts",
        label: "Edit tenant",
        order: 4,
        format: "form",
        input: %{"name" => %{"type" => "string", "required" => true}},
        predicates: %{
          "relationships" => [
            %{"name" => "overdue_invoices", "destination" => "Billing.Invoice"},
            %{"name" => "users", "destination" => "Accounts.User"}
          ]
        },
        consequence_class: "CONSTRUCT",
        authority_required: true
      ),
      ir(Accounts.Tenant, :destroy, :destroy,
        group: "Accounts",
        label: "Delete tenant",
        order: 5,
        consequence_class: "DO",
        authority_required: true,
        receipt_required: true
      ),
      ir(Accounts.User, :update, :update,
        group: "People",
        label: "Edit user",
        order: 6,
        format: "form",
        input: %{"email" => %{"type" => "string", "required" => true}},
        consequence_class: "CONSTRUCT",
        authority_required: true
      )
    ]
  end

  describe "relationship sections (semantic.predicates)" do
    test "relationships project as sorted, navigable sections with labels and destination paths" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      rels = view["resources"]["Accounts.Tenant"]["relationships"]

      assert Enum.map(rels, & &1["name"]) == ["billing_profile", "overdue_invoices", "users"]

      assert hd(rels) == %{
               "name" => "billing_profile",
               "label" => "Billing profile",
               "destination" => "Accounts.BillingProfile",
               "destination_path" => "/accounts-billingprofile",
               "cardinality" => "one",
               "surface_action_id" => "Accounts.Tenant#read"
             }

      # Undeclared cardinality defaults to "many" (zero-config).
      users = List.last(rels)
      assert users["cardinality"] == "many"
      assert users["destination_path"] == "/accounts-user"

      # Navigation groups still derive from presentation.group (v17 baseline).
      assert Enum.map(view["navigation"]["groups"], & &1["group"]) == ["Accounts", "People"]
    end

    test "duplicate declarations collapse; the first ordered declaring IR owns the section" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      rels = view["resources"]["Accounts.Tenant"]["relationships"]
      assert length(rels) == 3

      by_name = Map.new(rels, &{&1["name"], &1})

      # "users" is declared by read (order 1) and update (order 4): one
      # section, owned by the earlier IR.
      assert by_name["users"]["surface_action_id"] == "Accounts.Tenant#read"

      # "overdue_invoices" is first declared by update: owned by update.
      assert by_name["overdue_invoices"]["surface_action_id"] == "Accounts.Tenant#update"
    end
  end

  describe "pagination/windowing metadata (structure only)" do
    test "every read table reserves offset windowing metadata derived from its columns" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      assert view["resources"]["Accounts.Tenant"]["table"]["pagination"] == %{
               "window" => "offset",
               "default_limit" => 20,
               "sortable" => ["name", "page"]
             }

      assert view["resources"]["Accounts.User"]["table"]["pagination"] == %{
               "window" => "offset",
               "default_limit" => 20,
               "sortable" => ["email"]
             }
    end

    test "a resource without an admitted read action reserves no windowing metadata" do
      import_only = [
        ir(Accounts.Legacy, :import, :create,
          group: "Accounts",
          input: %{"csv" => %{"type" => "string", "required" => true}}
        )
      ]

      assert {:ok, view, _} = LiveView.project_ir(import_only, [])

      assert view["resources"]["Accounts.Legacy"]["table"] == %{
               "surface_action_id" => nil,
               "format" => nil,
               "columns" => [],
               "pagination" => nil
             }
    end
  end

  describe "argument->field mapping (schema.input)" do
    test "form fields carry declared defaults and placeholders; widgets come from presentation.widget" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      forms = view["resources"]["Accounts.Tenant"]["forms"]
      create_form = Enum.find(forms, &(&1["action"] == "create"))

      assert create_form["fields"] == [
               %{
                 "name" => "active",
                 "type" => "boolean",
                 "required" => false,
                 "default" => true,
                 "placeholder" => nil,
                 "widget" => "toggle"
               },
               %{
                 "name" => "name",
                 "type" => "string",
                 "required" => true,
                 "default" => "New tenant",
                 "placeholder" => "Acme Inc",
                 "widget" => "text"
               },
               %{
                 "name" => "subdomain",
                 "type" => "string",
                 "required" => false,
                 "default" => nil,
                 "placeholder" => "acme",
                 "widget" => "slug"
               }
             ]
    end

    test "table filter arguments map to columns carrying declared defaults" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      assert view["resources"]["Accounts.Tenant"]["table"]["columns"] == [
               %{
                 "name" => "name",
                 "type" => "string",
                 "required" => true,
                 "default" => nil,
                 "placeholder" => nil
               },
               %{
                 "name" => "page",
                 "type" => "integer",
                 "required" => false,
                 "default" => 1,
                 "placeholder" => "page number"
               }
             ]
    end
  end

  describe "authority-gated controls reference surface_action_id only" do
    test "every control, gated or not, targets exactly its own surface_action_id" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      actions =
        for {_resource, block} <- view["resources"], action <- block["actions"] do
          {action["surface_action_id"], action}
        end

      gated_ids =
        for {id, action} <- actions, action["authority_required"], do: id

      assert Enum.sort(gated_ids) == [
               "Accounts.Tenant#create",
               "Accounts.Tenant#destroy",
               "Accounts.Tenant#update",
               "Accounts.User#update"
             ]

      # ALWAYS: gated and ungated controls alike target their own id.
      for {id, action} <- actions do
        control = action["control"]
        assert control["kind"] == "intent"
        assert control["intent_target"] == id
        assert control["gated"] == action["authority_required"]
      end

      # Every non-control section binds to a surface_action_id as well.
      for {_resource, block} <- view["resources"] do
        assert is_binary(block["table"]["surface_action_id"]) or
                 is_nil(block["table"]["surface_action_id"])

        assert Enum.all?(block["forms"], &is_binary(&1["surface_action_id"]))
        assert Enum.all?(block["relationships"], &is_binary(&1["surface_action_id"]))
      end
    end

    test "emitted structure greps clean of module/function targets" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      emitted = inspect(view)

      refute emitted =~ "Elixir."
      refute emitted =~ "AshSurface"
      refute emitted =~ "Phoenix"
      # Mod.fun/arity references.
      refute emitted =~ ~r{[A-Za-z_][A-Za-z0-9_.]*/[0-9]+}

      forbidden_keys = ["module", "function", "mfa", "handler", "route", "target_module"]

      assert MapSet.disjoint?(MapSet.new(binary_keys(view)), MapSet.new(forbidden_keys))
    end
  end

  describe "empty state (zero admitted actions)" do
    test "an empty IR list projects an ok, navigable empty view without crashing" do
      assert {:ok, view, meta} = LiveView.project_ir([], [])

      assert view["kind"] == "ash_admin"
      assert view["ir_version"] == nil
      assert view["digest"] =~ ~r/^[0-9a-f]{64}$/
      assert view["navigation"] == %{"groups" => []}
      assert view["resources"] == %{}

      assert meta == %{
               "projector" => "AshSurface.LiveViewProjectorTest.Projectors.LiveView",
               "resource_count" => 0,
               "group_count" => 0,
               "action_count" => 0
             }
    end
  end

  defp binary_keys(term) when is_map(term) do
    Enum.flat_map(term, fn
      {key, value} when is_binary(key) -> [key | binary_keys(value)]
      {_key, value} -> binary_keys(value)
    end)
  end

  defp binary_keys(term) when is_list(term), do: Enum.flat_map(term, &binary_keys/1)
  defp binary_keys(_term), do: []
end
