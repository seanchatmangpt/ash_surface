defmodule AshSurface.Projectors.LiveViewStatesTest do
  @moduledoc """
  Chicago state-table tests (ticket chicago-liveview-states-045) over the REAL
  `AshSurface.Projectors.LiveView` projector: rendered structure maps asserted
  as DATA — content fields only, never markup internals.

  State dimensions, one describe each:

  - delegated-authority gating across three authority profiles
    (`delegated_operator`, `delegated_agent`, `public_observer`) via a
    12-row gate state table;
  - the gate-law invariant (OBSERVE controls never enter the DO window) and
    the intent-only control law, over every control of every profile;
  - relationship state: dedupe by {name, destination}, first-ordered IR owns
    the intent target, cardinality defaults;
  - windowing: each structure reads only its own IR window (table <- leading
    read only, forms <- create/update only, meta counts);
  - defaults: zero-config group/order/label/widget/required/cardinality.

  No test doubles: the unit under test is invoked directly on
  `%AshSurface.IR{}` fact carriers.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projectors.LiveView

  # Three delegated-authority profiles. Capability facts are carried facts,
  # never grants: the same fixture projects differently per profile.
  @authority_profiles %{
    delegated_operator: %{authority_required: true, receipt_required: true},
    delegated_agent: %{authority_required: true, receipt_required: false},
    public_observer: %{authority_required: false, receipt_required: false}
  }

  defp ir(resource, action, action_type, opts) do
    capability = Keyword.get(opts, :capability, %{})

    %IR{
      version: "26.9.17",
      digest: "digest-#{resource}-#{action}",
      ash: %IR.Ash{
        resource: resource,
        action: action,
        action_type: action_type,
        inputs: [],
        outputs: [],
        policies: []
      },
      semantic: %IR.Semantic{
        subject_iri: "ash:#{resource}",
        capability_iri: "ash:#{resource}##{action}",
        predicates: Keyword.get(opts, :predicates, %{}),
        shape_id: "shape-#{resource}-#{action}",
        ontology: "ggen-marketplace:v26.9.17"
      },
      capability: %IR.Capability{
        capability_id: "#{resource}##{action}",
        consequence_class: Keyword.get(opts, :consequence_class, "OBSERVE"),
        authority_required: Map.get(capability, :authority_required, false),
        receipt_required: Map.get(capability, :receipt_required, false)
      },
      presentation: %IR.Presentation{
        label: Keyword.get(opts, :label),
        group: Keyword.get(opts, :group),
        order: Keyword.get(opts, :order),
        widget: Keyword.get(opts, :widget),
        format: Keyword.get(opts, :format)
      },
      schema: %IR.Schema{
        input: Keyword.get(opts, :input, %{}),
        output: %{},
        zod: nil,
        aria: nil
      }
    }
  end

  # Ops.Cluster (3 actions: two reads + one update) and Ops.Deployment
  # (read/create/update/destroy), both in the "Infra" group. Capability facts
  # are per-action: the profile governs DO/CONSTRUCT authority delegation,
  # while OBSERVE actions never carry an authority requirement in any profile
  # (reads stay ungated everywhere — the delegated-authority model).
  defp fixture_irs(profile) do
    [
      ir(Ops.Cluster, :index, :read,
        capability: capability_facts(profile, "OBSERVE"),
        consequence_class: "OBSERVE",
        label: "Clusters",
        group: "Infra",
        order: 0,
        format: "grid",
        input: %{"name" => %{"type" => "string", "required" => true}}
      ),
      ir(Ops.Cluster, :read, :read,
        capability: capability_facts(profile, "OBSERVE"),
        consequence_class: "OBSERVE",
        label: "Cluster table",
        group: "Infra",
        order: 1,
        format: "table",
        input: %{
          "name" => %{"type" => "string", "required" => true},
          "node_count" => %{"type" => "integer"}
        },
        predicates: %{
          "relationships" => [
            %{
              "name" => "deployments",
              "destination" => "Ops.Deployment",
              "cardinality" => "many"
            },
            %{"name" => "owner", "destination" => "Ops.Principal", "cardinality" => "one"}
          ]
        }
      ),
      ir(Ops.Cluster, :resize, :update,
        capability: capability_facts(profile, "CONSTRUCT"),
        consequence_class: "CONSTRUCT",
        label: "Resize cluster",
        group: "Infra",
        order: 3,
        format: "form",
        input: %{
          "cpu" => %{"type" => "integer", "required" => true},
          "region" => %{"type" => "string"},
          "window" => %{"type" => "utc_datetime"}
        },
        # Deliberately re-declares {deployments, Ops.Deployment}: must dedupe.
        predicates: %{
          "relationships" => [
            %{"name" => "deployments", "destination" => "Ops.Deployment", "cardinality" => "many"}
          ]
        }
      ),
      ir(Ops.Deployment, :read, :read,
        capability: capability_facts(profile, "OBSERVE"),
        consequence_class: "OBSERVE",
        label: "Deployments",
        group: "Infra",
        order: 1,
        format: "table",
        input: %{"env" => %{"type" => "string"}}
      ),
      ir(Ops.Deployment, :create, :create,
        capability: capability_facts(profile, "DO"),
        consequence_class: "DO",
        label: "Deploy new",
        group: "Infra",
        order: 2,
        format: "form",
        input: %{
          "image" => %{"type" => "string", "required" => true},
          "replicas" => %{"type" => "integer"}
        }
      ),
      ir(Ops.Deployment, :rollback, :update,
        capability: capability_facts(profile, "CONSTRUCT"),
        consequence_class: "CONSTRUCT",
        label: "Rollback",
        group: "Infra",
        order: 3,
        format: "form",
        input: %{"revision" => %{"type" => "string", "required" => true}}
      ),
      ir(Ops.Deployment, :destroy, :destroy,
        capability: capability_facts(profile, "DO"),
        consequence_class: "DO",
        label: "Destroy",
        group: "Infra",
        order: 4
      )
    ]
  end

  # Delegated-authority model: a profile decides DO/CONSTRUCT delegation;
  # OBSERVE actions are ungated in every profile.
  defp capability_facts(_profile, "OBSERVE") do
    %{authority_required: false, receipt_required: false}
  end

  defp capability_facts(profile, _consequence_class) do
    Map.fetch!(@authority_profiles, profile)
  end

  # The gate state table: 12 rows across the 3 authority profiles. Each row
  # pins the rendered content fields of one control under one profile.
  defp gate_state_rows do
    [
      %{
        profile: :delegated_operator,
        id: "Ops.Deployment#create",
        consequence: "DO",
        gated: true,
        gate: "REQUIRED",
        receipt: true
      },
      %{
        profile: :delegated_operator,
        id: "Ops.Deployment#destroy",
        consequence: "DO",
        gated: true,
        gate: "REQUIRED",
        receipt: true
      },
      %{
        profile: :delegated_operator,
        id: "Ops.Deployment#rollback",
        consequence: "CONSTRUCT",
        gated: true,
        gate: "REQUIRED",
        receipt: true
      },
      %{
        profile: :delegated_operator,
        id: "Ops.Cluster#read",
        consequence: "OBSERVE",
        gated: false,
        gate: "NOT_REQUIRED",
        receipt: false
      },
      %{
        profile: :delegated_agent,
        id: "Ops.Deployment#create",
        consequence: "DO",
        gated: true,
        gate: "REQUIRED",
        receipt: false
      },
      %{
        profile: :delegated_agent,
        id: "Ops.Deployment#destroy",
        consequence: "DO",
        gated: true,
        gate: "REQUIRED",
        receipt: false
      },
      %{
        profile: :delegated_agent,
        id: "Ops.Cluster#resize",
        consequence: "CONSTRUCT",
        gated: true,
        gate: "REQUIRED",
        receipt: false
      },
      %{
        profile: :delegated_agent,
        id: "Ops.Deployment#read",
        consequence: "OBSERVE",
        gated: false,
        gate: "NOT_REQUIRED",
        receipt: false
      },
      %{
        profile: :public_observer,
        id: "Ops.Deployment#create",
        consequence: "DO",
        gated: false,
        gate: "NOT_REQUIRED",
        receipt: false
      },
      %{
        profile: :public_observer,
        id: "Ops.Deployment#destroy",
        consequence: "DO",
        gated: false,
        gate: "NOT_REQUIRED",
        receipt: false
      },
      %{
        profile: :public_observer,
        id: "Ops.Cluster#resize",
        consequence: "CONSTRUCT",
        gated: false,
        gate: "NOT_REQUIRED",
        receipt: false
      },
      %{
        profile: :public_observer,
        id: "Ops.Cluster#read",
        consequence: "OBSERVE",
        gated: false,
        gate: "NOT_REQUIRED",
        receipt: false
      }
    ]
  end

  defp controls(view) do
    for {_resource, block} <- view["resources"],
        action <- block["actions"],
        into: %{} do
      {action["surface_action_id"], action}
    end
  end

  describe "delegated-authority gate state table" do
    test "12 state rows across 3 authority profiles render exact gate states" do
      rows = gate_state_rows()
      assert length(rows) >= 10

      views =
        for {profile, _facts} <- @authority_profiles, into: %{} do
          assert {:ok, view, _meta} = LiveView.project_ir(fixture_irs(profile), [])
          {profile, controls(view)}
        end

      for row <- rows do
        action = Map.fetch!(views[row.profile], row.id)
        control = action["control"]
        where = "#{row.profile} / #{row.id}"

        assert action["consequence_class"] == row.consequence,
               "consequence_class: #{where}"

        assert action["authority_required"] == row.gated,
               "authority_required: #{where}"

        assert action["receipt_required"] == row.receipt,
               "receipt_required: #{where}"

        assert control["gated"] == row.gated, "control.gated: #{where}"

        assert control["authority_gate"] == row.gate,
               "control.authority_gate: #{where}"
      end
    end

    test "gating follows the carried authority fact, not the consequence class" do
      # An OBSERVE-class action whose carried fact requires authority IS gated
      # (fact wins); the class is inert. The mirror row — ungated DO under
      # :public_observer — is pinned in the state table above.
      irs = [
        ir(Ops.Shadow, :peek, :read,
          capability: %{authority_required: true, receipt_required: true},
          consequence_class: "OBSERVE",
          label: "Peek"
        )
      ]

      assert {:ok, view, _meta} = LiveView.project_ir(irs, [])
      [control_entry] = view["resources"]["Ops.Shadow"]["actions"]

      assert control_entry["authority_required"] == true
      assert control_entry["receipt_required"] == true
      assert control_entry["control"]["gated"] == true
      assert control_entry["control"]["authority_gate"] == "REQUIRED"
    end

    test "gate-law invariant: OBSERVE controls never enter the DO window, every control is intent-only" do
      for {profile, _facts} <- @authority_profiles do
        assert {:ok, view, _meta} = LiveView.project_ir(fixture_irs(profile), [])

        for {resource, block} <- view["resources"],
            action <- block["actions"] do
          control = action["control"]
          where = "#{profile}/#{resource}/#{action["surface_action_id"]}"

          # Intent-only law: the control references the intent target and
          # nothing else — no module, function, or route-to-code field.
          assert Enum.sort(Map.keys(control)) ==
                   ["authority_gate", "gated", "intent_target", "kind"],
                 "control shape: #{where}"

          assert control["kind"] == "intent", "control kind: #{where}"

          assert control["intent_target"] == action["surface_action_id"],
                 "intent target: #{where}"

          assert control["gated"] == action["authority_required"],
                 "gate follows carried fact: #{where}"

          if action["consequence_class"] == "OBSERVE" do
            refute control["gated"], "OBSERVE control in DO-window: #{where}"

            assert control["authority_gate"] == "NOT_REQUIRED",
                   "OBSERVE control gate label: #{where}"
          end
        end
      end
    end
  end

  describe "relationship state" do
    test "dedupe by name+destination; first-ordered IR owns the intent target" do
      assert {:ok, view, _meta} = LiveView.project_ir(fixture_irs(:delegated_agent), [])

      # Cluster#read (order 1) declares both; Cluster#resize (order 3)
      # re-declares {deployments, Ops.Deployment} — deduped away, and the
      # surviving entry keeps the first-ordered declaring IR as its target.
      assert view["resources"]["Ops.Cluster"]["relationships"] == [
               %{
                 "name" => "deployments",
                 "destination" => "Ops.Deployment",
                 "cardinality" => "many",
                 "surface_action_id" => "Ops.Cluster#read"
               },
               %{
                 "name" => "owner",
                 "destination" => "Ops.Principal",
                 "cardinality" => "one",
                 "surface_action_id" => "Ops.Cluster#read"
               }
             ]

      assert view["resources"]["Ops.Deployment"]["relationships"] == []
    end
  end

  describe "windowing state" do
    test "table reads only the leading read IR; forms read only create/update IRs" do
      assert {:ok, view, meta} = LiveView.project_ir(fixture_irs(:public_observer), [])

      # Table window: the lowest-order read (#index, order 0) owns the table;
      # #read's node_count column never leaks into it.
      assert view["resources"]["Ops.Cluster"]["table"] == %{
               "surface_action_id" => "Ops.Cluster#index",
               "format" => "grid",
               "columns" => [%{"name" => "name", "type" => "string", "required" => true}]
             }

      # Form window: create/update only. The DO destroy and the OBSERVE read
      # never render as forms.
      deployment_forms = view["resources"]["Ops.Deployment"]["forms"]

      assert Enum.map(deployment_forms, & &1["surface_action_id"]) == [
               "Ops.Deployment#create",
               "Ops.Deployment#rollback"
             ]

      refute Enum.any?(deployment_forms, &(&1["surface_action_id"] == "Ops.Deployment#destroy"))
      refute Enum.any?(deployment_forms, &(&1["surface_action_id"] == "Ops.Deployment#read"))

      assert Enum.map(view["resources"]["Ops.Cluster"]["forms"], & &1["surface_action_id"]) == [
               "Ops.Cluster#resize"
             ]

      # Form field content (widget defaults by type), sorted by field name.
      assert [%{"fields" => create_fields}, %{"fields" => rollback_fields}] = deployment_forms

      assert create_fields == [
               %{"name" => "image", "type" => "string", "required" => true, "widget" => "text"},
               %{
                 "name" => "replicas",
                 "type" => "integer",
                 "required" => false,
                 "widget" => "number"
               }
             ]

      assert rollback_fields == [
               %{"name" => "revision", "type" => "string", "required" => true, "widget" => "text"}
             ]

      assert [%{"fields" => resize_fields}] = view["resources"]["Ops.Cluster"]["forms"]

      assert resize_fields == [
               %{"name" => "cpu", "type" => "integer", "required" => true, "widget" => "number"},
               %{"name" => "region", "type" => "string", "required" => false, "widget" => "text"},
               %{
                 "name" => "window",
                 "type" => "utc_datetime",
                 "required" => false,
                 "widget" => "datetime"
               }
             ]

      # Navigation content fields: group, order, label, path.
      assert [%{"group" => "Infra", "order" => 0, "resources" => [cluster_nav, deployment_nav]}] =
               view["navigation"]["groups"]

      assert cluster_nav == %{
               "resource" => "Ops.Cluster",
               "label" => "Clusters",
               "path" => "/ops-cluster",
               "order" => 0
             }

      assert deployment_nav == %{
               "resource" => "Ops.Deployment",
               "label" => "Deployments",
               "path" => "/ops-deployment",
               "order" => 1
             }

      assert meta == %{
               "projector" => "AshSurface.Projectors.LiveView",
               "resource_count" => 2,
               "group_count" => 1,
               "action_count" => 7
             }
    end
  end

  describe "defaults state" do
    test "zero-config IRs: default group, order, label fallback, widgets, required, cardinality" do
      irs = [
        ir(Ops.AuditLog, :read, :read,
          consequence_class: "OBSERVE",
          input: %{
            "query" => "string",
            "occurred_at" => %{"type" => "utc_datetime", "required" => true},
            "opaque" => %{"type" => "some_exotic"}
          },
          predicates: %{
            "relationships" => [%{"name" => "entries", "destination" => "Ops.AuditEntry"}]
          }
        ),
        ir(Ops.AuditLog, :export, :create,
          consequence_class: "DO",
          input: %{"payload" => %{"type" => "jsonb"}}
        )
      ]

      assert {:ok, view, meta} = LiveView.project_ir(irs, [])
      block = view["resources"]["Ops.AuditLog"]

      # Presentation defaults: group "Resources", order 0, label falls back to
      # the resource name.
      assert block["group"] == "Resources"
      assert block["order"] == 0
      assert block["label"] == "Ops.AuditLog"

      # Schema defaults: required defaults to false; bare-binary specs type as
      # themselves; unknown types pass through as their own string.
      assert block["table"]["columns"] == [
               %{"name" => "occurred_at", "type" => "utc_datetime", "required" => true},
               %{"name" => "opaque", "type" => "some_exotic", "required" => false},
               %{"name" => "query", "type" => "string", "required" => false}
             ]

      # Relationship default cardinality: "many" when absent.
      assert block["relationships"] == [
               %{
                 "name" => "entries",
                 "destination" => "Ops.AuditEntry",
                 "cardinality" => "many",
                 "surface_action_id" => "Ops.AuditLog#read"
               }
             ]

      # Form defaults: label nil, order 0, format nil; unknown field type gets
      # the fallback widget "text".
      assert [form] = block["forms"]
      assert form["surface_action_id"] == "Ops.AuditLog#export"
      assert form["label"] == nil
      assert form["order"] == 0
      assert form["format"] == nil

      assert form["fields"] == [
               %{"name" => "payload", "type" => "jsonb", "required" => false, "widget" => "text"}
             ]

      assert [%{"group" => "Resources", "order" => 0, "resources" => [nav]}] =
               view["navigation"]["groups"]

      assert nav == %{
               "resource" => "Ops.AuditLog",
               "label" => "Ops.AuditLog",
               "path" => "/ops-auditlog",
               "order" => 0
             }

      assert meta == %{
               "projector" => "AshSurface.Projectors.LiveView",
               "resource_count" => 1,
               "group_count" => 1,
               "action_count" => 2
             }
    end
  end
end
