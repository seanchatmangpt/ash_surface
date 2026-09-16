defmodule AshSurface.Projectors.LiveViewTest do
  @moduledoc """
  Chicago zero-config tests for the ash_admin-pattern LiveView structure
  projector: golden structure maps over a 2-resource fixture, authority
  gating of action controls, and presentation.order ordering.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projectors.LiveView

  defp ir(resource, action, action_type, opts) do
    %IR{
      version: "26.9.13",
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
        ontology: "ggen-marketplace:v26.9.13"
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

  # 2-resource fixture: Catalog.Product (3 actions) and Catalog.Review
  # (2 actions), deliberately fed out of order to prove permutation stability.
  defp fixture_irs do
    [
      ir(Catalog.Product, :create, :create,
        group: "Catalog",
        label: "New product",
        order: 3,
        format: "form",
        widget: %{"name" => "text", "price_cents" => "currency"},
        input: %{
          "name" => %{"type" => "string", "required" => true},
          "price_cents" => %{"type" => "integer", "required" => true},
          "active" => %{"type" => "boolean"}
        },
        consequence_class: "DO",
        authority_required: true,
        receipt_required: true
      ),
      ir(Catalog.Review, :read, :read,
        group: "Feedback",
        label: "Reviews",
        order: 2,
        format: "table",
        input: %{
          "rating" => %{"type" => "integer", "required" => true},
          "body" => %{"type" => "string"}
        }
      ),
      ir(Catalog.Product, :destroy, :destroy,
        group: "Catalog",
        label: "Delete product",
        order: 5,
        consequence_class: "DO",
        authority_required: true,
        receipt_required: true
      ),
      ir(Catalog.Product, :read, :read,
        group: "Catalog",
        label: "Products",
        order: 1,
        format: "table",
        input: %{
          "name" => %{"type" => "string", "required" => true},
          "price_cents" => %{"type" => "integer", "required" => true},
          "active" => %{"type" => "boolean"}
        },
        predicates: %{
          "relationships" => [
            %{"name" => "reviews", "destination" => "Catalog.Review", "cardinality" => "many"}
          ]
        }
      ),
      ir(Catalog.Review, :update, :update,
        group: "Feedback",
        label: "Edit review",
        order: 4,
        format: "form",
        widget: %{"body" => "textarea"},
        input: %{
          "rating" => %{"type" => "integer", "required" => true},
          "body" => %{"type" => "string"}
        },
        consequence_class: "CONSTRUCT",
        authority_required: true,
        receipt_required: true
      )
    ]
  end

  describe "golden structure maps (2-resource fixture)" do
    test "projects the exact ash_admin structure map and meta" do
      assert {:ok, view, meta} = LiveView.project_ir(fixture_irs(), [])

      assert meta == %{
               "projector" => "AshSurface.Projectors.LiveView",
               "resource_count" => 2,
               "group_count" => 2,
               "action_count" => 5
             }

      assert view == %{
               "kind" => "ash_admin",
               "ir_version" => "26.9.13",
               "digest" => view["digest"],
               "navigation" => %{
                 "groups" => [
                   %{
                     "group" => "Catalog",
                     "order" => 1,
                     "resources" => [
                       %{
                         "resource" => "Catalog.Product",
                         "label" => "Products",
                         "path" => "/catalog-product",
                         "order" => 1
                       }
                     ]
                   },
                   %{
                     "group" => "Feedback",
                     "order" => 2,
                     "resources" => [
                       %{
                         "resource" => "Catalog.Review",
                         "label" => "Reviews",
                         "path" => "/catalog-review",
                         "order" => 2
                       }
                     ]
                   }
                 ]
               },
               "resources" => %{
                 "Catalog.Product" => %{
                   "resource" => "Catalog.Product",
                   "label" => "Products",
                   "group" => "Catalog",
                   "order" => 1,
                   "table" => %{
                     "surface_action_id" => "Catalog.Product#read",
                     "format" => "table",
                     "columns" => [
                       %{"name" => "active", "type" => "boolean", "required" => false},
                       %{"name" => "name", "type" => "string", "required" => true},
                       %{"name" => "price_cents", "type" => "integer", "required" => true}
                     ]
                   },
                   "forms" => [
                     %{
                       "surface_action_id" => "Catalog.Product#create",
                       "action" => "create",
                       "action_type" => "create",
                       "label" => "New product",
                       "order" => 3,
                       "format" => "form",
                       "fields" => [
                         %{
                           "name" => "active",
                           "type" => "boolean",
                           "required" => false,
                           "widget" => "toggle"
                         },
                         %{
                           "name" => "name",
                           "type" => "string",
                           "required" => true,
                           "widget" => "text"
                         },
                         %{
                           "name" => "price_cents",
                           "type" => "integer",
                           "required" => true,
                           "widget" => "currency"
                         }
                       ]
                     }
                   ],
                   "relationships" => [
                     %{
                       "name" => "reviews",
                       "destination" => "Catalog.Review",
                       "cardinality" => "many",
                       "surface_action_id" => "Catalog.Product#read"
                     }
                   ],
                   "actions" => [
                     control_entry(
                       "Catalog.Product#read",
                       "read",
                       "read",
                       "Products",
                       1,
                       "OBSERVE",
                       false,
                       false
                     ),
                     control_entry(
                       "Catalog.Product#create",
                       "create",
                       "create",
                       "New product",
                       3,
                       "DO",
                       true,
                       true
                     ),
                     control_entry(
                       "Catalog.Product#destroy",
                       "destroy",
                       "destroy",
                       "Delete product",
                       5,
                       "DO",
                       true,
                       true
                     )
                   ]
                 },
                 "Catalog.Review" => %{
                   "resource" => "Catalog.Review",
                   "label" => "Reviews",
                   "group" => "Feedback",
                   "order" => 2,
                   "table" => %{
                     "surface_action_id" => "Catalog.Review#read",
                     "format" => "table",
                     "columns" => [
                       %{"name" => "body", "type" => "string", "required" => false},
                       %{"name" => "rating", "type" => "integer", "required" => true}
                     ]
                   },
                   "forms" => [
                     %{
                       "surface_action_id" => "Catalog.Review#update",
                       "action" => "update",
                       "action_type" => "update",
                       "label" => "Edit review",
                       "order" => 4,
                       "format" => "form",
                       "fields" => [
                         %{
                           "name" => "body",
                           "type" => "string",
                           "required" => false,
                           "widget" => "textarea"
                         },
                         %{
                           "name" => "rating",
                           "type" => "integer",
                           "required" => true,
                           "widget" => "number"
                         }
                       ]
                     }
                   ],
                   "relationships" => [],
                   "actions" => [
                     control_entry(
                       "Catalog.Review#read",
                       "read",
                       "read",
                       "Reviews",
                       2,
                       "OBSERVE",
                       false,
                       false
                     ),
                     control_entry(
                       "Catalog.Review#update",
                       "update",
                       "update",
                       "Edit review",
                       4,
                       "CONSTRUCT",
                       true,
                       true
                     )
                   ]
                 }
               }
             }
    end

    test "projection is byte-stable under input permutation" do
      assert {:ok, view_a, _} = LiveView.project_ir(fixture_irs(), [])
      assert {:ok, view_b, _} = LiveView.project_ir(Enum.reverse(fixture_irs()), [])
      assert view_a == view_b
      assert view_a["digest"] == view_b["digest"]

      # Content-addressed: 64-char lowercase hex digest.
      assert view_a["digest"] =~ ~r/^[0-9a-f]{64}$/
    end

    test "a single IR projects a single-resource view" do
      assert {:ok, view, meta} = LiveView.project_ir(hd(fixture_irs()), [])

      assert meta["resource_count"] == 1
      assert meta["action_count"] == 1
      assert Map.keys(view["resources"]) == ["Catalog.Product"]
    end
  end

  defp control_entry(id, action, action_type, label, order, consequence, gated, receipt) do
    %{
      "surface_action_id" => id,
      "action" => action,
      "action_type" => action_type,
      "label" => label,
      "order" => order,
      "consequence_class" => consequence,
      "authority_required" => gated,
      "receipt_required" => receipt,
      "control" => %{
        "kind" => "intent",
        "intent_target" => id,
        "gated" => gated,
        "authority_gate" => if(gated, do: "REQUIRED", else: "NOT_REQUIRED")
      }
    }
  end

  describe "authority gating" do
    test "authority_required action controls are gated intent targets, never direct calls" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      all_controls =
        for {_resource, block} <- view["resources"],
            action <- block["actions"] do
          {action["surface_action_id"], action}
        end
        |> Map.new()

      # Gated: create / update / destroy carry capability.authority_required.
      for id <-
            ["Catalog.Product#create", "Catalog.Product#destroy", "Catalog.Review#update"] do
        control = all_controls[id]["control"]

        assert control["gated"] == true
        assert control["authority_gate"] == "REQUIRED"
        assert control["kind"] == "intent"
        assert control["intent_target"] == id
        assert all_controls[id]["authority_required"] == true
      end

      # Ungated: reads carry no authority requirement.
      for id <- ["Catalog.Product#read", "Catalog.Review#read"] do
        control = all_controls[id]["control"]

        assert control["gated"] == false
        assert control["authority_gate"] == "NOT_REQUIRED"
        assert all_controls[id]["authority_required"] == false
      end

      # Intent-only law: no control references a module, function, or route.
      for {_id, action} <- all_controls do
        control = action["control"]

        assert Enum.sort(Map.keys(control)) == [
                 "authority_gate",
                 "gated",
                 "intent_target",
                 "kind"
               ]

        assert control["intent_target"] == action["surface_action_id"]
      end
    end
  end

  describe "presentation.order ordering" do
    test "navigation groups and resources follow presentation.order" do
      assert {:ok, view, _} = LiveView.project_ir(fixture_irs(), [])

      groups = view["navigation"]["groups"]
      assert Enum.map(groups, & &1["group"]) == ["Catalog", "Feedback"]
      assert Enum.map(groups, & &1["order"]) == [1, 2]

      actions = view["resources"]["Catalog.Product"]["actions"]
      assert Enum.map(actions, & &1["order"]) == [1, 3, 5]
    end

    test "order is behavioral: reordering flips navigation precedence" do
      flipped =
        Enum.map(fixture_irs(), fn %{presentation: p} = entry ->
          case {entry.ash.resource, entry.ash.action} do
            {Catalog.Review, :read} -> %{entry | presentation: %{p | order: 0}}
            _ -> entry
          end
        end)

      assert {:ok, view, _} = LiveView.project_ir(flipped, [])

      assert [%{"group" => "Feedback"}, %{"group" => "Catalog"}] =
               view["navigation"]["groups"]

      # Review now leads its own group and the group leads navigation.
      assert hd(view["navigation"]["groups"])["order"] == 0

      assert hd(view["navigation"]["groups"])["resources"] == [
               %{
                 "resource" => "Catalog.Review",
                 "label" => "Reviews",
                 "path" => "/catalog-review",
                 "order" => 0
               }
             ]
    end
  end

  describe "fail-closed validation" do
    test "refuses non-IR elements" do
      assert {:error, {:not_an_ir, :junk}} = LiveView.project_ir([hd(fixture_irs()), :junk], [])
    end

    test "refuses non-list, non-IR input" do
      assert {:error, {:not_ir_input, :nope}} = LiveView.project_ir(:nope, [])
    end

    test "refuses IR version conflicts" do
      [ir_a | rest] = fixture_irs()
      conflicting = [%{ir_a | version: "25.0.0"} | rest]

      assert {:error, {:ir_version_conflict, ["25.0.0", "26.9.13"]}} =
               LiveView.project_ir(conflicting, [])
    end

    test "refuses malformed relationship declarations" do
      broken =
        put_in(
          hd(fixture_irs()),
          [Access.key!(:semantic), Access.key!(:predicates)],
          %{"relationships" => [%{"name" => "reviews"}]}
        )

      assert {:error, {:malformed_relationship, %{"name" => "reviews"}}} =
               LiveView.project_ir([broken], [])
    end
  end

  describe "behaviour conformance" do
    test "LiveView carries its documented project_ir/2 subject contract" do
      behaviours =
        LiveView.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      # Integrated truth: the branch-local behaviour declaration was superseded
      # by the canonical AshSurface.Projector.IR (v16), whose callback folds
      # kind-tagged IR node maps; LiveView's project_ir/2 folds %AshSurface.IR{}
      # structs directly — a different subject contract — so it honestly does
      # not declare the behaviour. Conformance is owed by the adapter that
      # bridges the two IR shapes.
      assert AshSurface.Projector.IR not in behaviours
      assert function_exported?(LiveView, :project_ir, 2)
    end
  end
end
