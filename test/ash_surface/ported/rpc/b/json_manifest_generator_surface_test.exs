defmodule AshSurface.Ported.Rpc.B.JsonManifestGeneratorSurfaceTest do
  @moduledoc """
  Executed courts for the ash_surface-native action manifest
  (`AshSurface.Manifest.ActionManifest`, KD-07), counterpart of the structural describes of
  ash_typescript `rpc/json_manifest_generator_test`.

  Per-test mapping and the TypeScript-only describes (files section, `types`/`variants`/
  `variantNames`, typed-controller routes, `generatedAt`) are recorded in the ledger row's
  `changes` and the remaining loud skips in `json_manifest_generator_gap_test.exs`.
  The manifest is built from the real prepared fixture manifest + entry table (no action
  runs) and decoded from its canonical JSON bytes.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Manifest.ActionManifest
  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.RFP

  # Entry options the reference declares on `rpc_action` (deprecated / see / description).
  @extras %{
    list_todos: [namespace: "todos"],
    list_todos_deprecated: [deprecated: "Use listTodosV2 instead"],
    list_todos_deprecated_simple: [deprecated: true],
    list_todos_with_see: [see: [:create_todo, :get_single_todo]],
    list_todos_with_custom_description: [description: "Custom list description"]
  }

  setup_all do
    entries =
      Enum.map(P.Rpc.entries(), fn e -> Map.merge(e, Map.new(Map.get(@extras, e.name, []))) end)

    built = ActionManifest.build(RFP.manifest(), entries)
    json = ActionManifest.to_json(built)
    {:ok, manifest: Jason.decode!(json), json: json, built: built}
  end

  defp action(manifest, fname), do: Enum.find(manifest["actions"], &(&1["functionName"] == fname))

  describe "basic structure" do
    test "is valid JSON that ends with newline", %{json: json} do
      assert String.ends_with?(json, "\n")
      assert {:ok, _} = Jason.decode(json)
    end

    test "has required top-level keys", %{manifest: m} do
      refute Map.has_key?(m, "$schema")
      refute Map.has_key?(m, "generatedAt")
      assert Map.has_key?(m, "version")
      assert Map.has_key?(m, "actions")
      assert Map.has_key?(m, "resources")
    end

    test("version is 1.0", %{manifest: m}, do: assert(m["version"] == "1.0"))

    test "actions is a non-empty list", %{manifest: m} do
      assert is_list(m["actions"]) and m["actions"] != []
    end

    test "bytes are deterministic (no wall clock) and key-sorted", %{json: json, built: built} do
      assert json == ActionManifest.to_json(built)
      assert json == ActionManifest.to_json(Jason.decode!(json))
    end
  end

  describe "action entries" do
    test "each action has required fields", %{manifest: m} do
      for a <- m["actions"] do
        assert is_binary(a["functionName"])
        assert a["actionType"] in ["read", "create", "update", "destroy", "action"]
        assert is_boolean(a["get"])
        assert is_binary(a["resource"])
        assert is_binary(a["description"])
        assert is_list(a["see"])
        assert a["input"] in ["none", "optional", "required"]
        assert is_map(a["pagination"])
        assert is_boolean(a["enableFilter"])
        assert is_boolean(a["enableSort"])
        assert is_boolean(a["hasFields"])
        assert is_list(a["metadataFields"])
        assert is_binary(a["namespace"]) or is_nil(a["namespace"])
        assert a["deprecated"] in [false, true] or is_binary(a["deprecated"])
      end
    end

    test "function names are unique", %{manifest: m} do
      names = Enum.map(m["actions"], & &1["functionName"])
      assert names == Enum.uniq(names)
    end

    test "actions are in exact ascending functionName order", %{manifest: m} do
      names = Enum.map(m["actions"], & &1["functionName"])
      assert names == Enum.sort(names)
      assert length(names) > 1
      assert hd(names) <= List.last(names)
      assert names != Enum.reverse(names)
    end

    test "custom description is carried", %{manifest: m} do
      assert action(m, "listTodosWithCustomDescription")["description"] ==
               "Custom list description"
    end
  end

  describe "read list actions" do
    test "pagination config for optional pagination", %{manifest: m} do
      a = action(m, "listTodos")
      assert a["pagination"]["supported"] == true
      assert a["pagination"]["required"] == false
      assert a["pagination"]["offset"] == true
      assert a["pagination"]["keyset"] == true
    end

    test "is not a get action", %{manifest: m} do
      a = action(m, "listTodos")
      assert a["get"] == false
      assert a["pagination"]["get"] == false
      assert a["actionType"] == "read"
    end
  end

  describe "namespace" do
    test "has namespace", %{manifest: m} do
      assert action(m, "listTodos")["namespace"] == "todos"
      assert action(m, "createTodo")["namespace"] == nil
    end
  end

  describe "get actions" do
    test "get flag is true and pagination is not supported", %{manifest: m} do
      a = action(m, "getSingleTodo")
      assert a["get"] == true
      assert a["pagination"]["supported"] == false
      assert a["hasFields"] == true
    end
  end

  describe "destroy actions" do
    test "has no fields and no input", %{manifest: m} do
      a = action(m, "destroyTodo")
      assert a["actionType"] == "destroy"
      assert a["hasFields"] == false
      assert a["pagination"]["supported"] == false
    end
  end

  describe "create/update actions" do
    test "have fields; no pagination", %{manifest: m} do
      create = action(m, "createTodo")
      update = action(m, "updateTodo")
      assert create["hasFields"] and update["hasFields"]
      assert create["actionType"] == "create" and update["actionType"] == "update"
      assert create["pagination"]["supported"] == false
    end
  end

  describe "filter and sort flags" do
    test "filter disabled is reflected", %{manifest: m} do
      a = action(m, "listTodosNoFilter")
      assert a["enableFilter"] == false
      assert a["enableSort"] == true
    end

    test "sort disabled is reflected", %{manifest: m} do
      a = action(m, "listTodosNoSort")
      assert a["enableSort"] == false
      assert a["enableFilter"] == true
    end

    test "non-read actions advertise neither", %{manifest: m} do
      a = action(m, "createTodo")
      assert a["enableFilter"] == false and a["enableSort"] == false
    end
  end

  describe "deprecated actions" do
    test "deprecated with message", %{manifest: m} do
      assert action(m, "listTodosDeprecated")["deprecated"] == "Use listTodosV2 instead"
    end

    test "deprecated without message", %{manifest: m} do
      assert action(m, "listTodosDeprecatedSimple")["deprecated"] == true
    end

    test("undeprecated is false", %{manifest: m},
      do: assert(action(m, "listTodos")["deprecated"] == false)
    )
  end

  describe "see references" do
    test "see refs are camelCase function names", %{manifest: m} do
      see = action(m, "listTodosWithSee")["see"]
      assert "createTodo" in see
      assert "getSingleTodo" in see
    end
  end

  describe "input classification" do
    test "actions with no arguments have input none", %{manifest: m} do
      assert action(m, "destroyTodo")["input"] == "none"
    end

    test "actions with required arguments have input required", %{manifest: m} do
      assert action(m, "createTodo")["input"] == "required"
    end

    test "read actions with optional arguments have input optional", %{manifest: m} do
      assert action(m, "listTodos")["input"] == "optional"
    end
  end

  describe "generic actions" do
    test "field-selectable generic actions have fields", %{manifest: m} do
      a = action(m, "searchTodos")
      assert a["actionType"] == "action"
      assert a["hasFields"] == true
    end

    test "non-field-selectable generic actions lack fields", %{manifest: m} do
      a = action(m, "pingTodo")
      assert a["actionType"] == "action"
      assert a["hasFields"] == false
    end
  end

  describe "relationship query capabilities" do
    test "resource entries expose many-relationship capabilities", %{manifest: m} do
      rels = m["resources"]["Todo"]["relationships"]

      assert rels["comments"] == %{
               "pagination" => "mixed",
               "filterable" => true,
               "sortable" => true
             }

      assert rels["unfilterable_comments"]["filterable"] == false
      assert rels["unsortable_comments"]["sortable"] == false
      assert rels["unpaginated_comments"]["pagination"] == "none"
      refute Map.has_key?(rels, "user")
    end
  end
end
