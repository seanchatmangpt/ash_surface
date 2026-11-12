defmodule AshSurface.Ported.Rpc.B.ManifestGeneratorSurfaceTest do
  @moduledoc """
  Structural counterpart of ash_typescript `rpc/manifest_generator_test` (the markdown
  document generator) over the KD-07 native manifest (`AshSurface.Manifest.ActionManifest`):
  the markdown rendering (headers, tables, TS columns, typed queries, routes) is a loud skip
  in `manifest_generator_gap_test.exs` (operator decision D24); the facts those tables
  present (sorted actions, action types, descriptions, namespace, deprecated marker,
  omission of resources without rpc actions, camelCase function names) are asserted here on
  the machine-readable form.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Manifest.ActionManifest
  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.RFP

  setup_all do
    entries =
      Enum.map(P.Rpc.entries(), fn
        %{name: :list_todos} = e -> Map.put(e, :namespace, "todos")
        %{name: :list_todos_deprecated} = e -> Map.put(e, :deprecated, "Use listTodosV2 instead")
        e -> e
      end)

    manifest =
      entries
      |> then(&ActionManifest.build(RFP.manifest(), &1))
      |> ActionManifest.to_json()
      |> Jason.decode!()

    {:ok, manifest: manifest, entries: entries}
  end

  describe "sorting" do
    test "actions are sorted alphabetically by function name", %{manifest: m} do
      names = Enum.map(m["actions"], & &1["functionName"])
      assert length(names) > 10
      assert names == Enum.sort(names)
    end

    test "resources appear once each, keyed by short name", %{manifest: m} do
      assert Map.has_key?(m["resources"], "Todo")
      assert Map.has_key?(m["resources"], "User")

      assert m["resources"] |> Map.keys() |> Enum.sort() ==
               m["resources"] |> Map.keys() |> Enum.sort() |> Enum.uniq()
    end
  end

  describe "action types" do
    test "shows correct action types", %{manifest: m} do
      types = m["actions"] |> Enum.map(& &1["actionType"]) |> MapSet.new()
      for t <- ~w(read create update destroy action), do: assert(t in types)
    end
  end

  describe "action details" do
    test "includes description for each action", %{manifest: m} do
      assert Enum.all?(m["actions"], &is_binary(&1["description"]))
    end

    test "includes namespace when set", %{manifest: m} do
      assert Enum.find(m["actions"], &(&1["functionName"] == "listTodos"))["namespace"] ==
               "todos"
    end

    test "includes deprecated marker when action is deprecated", %{manifest: m} do
      d = Enum.find(m["actions"], &(&1["functionName"] == "listTodosDeprecated"))
      assert d["deprecated"] == "Use listTodosV2 instead"
    end
  end

  describe "resources without actions" do
    test "omits resources with no rpc actions", %{manifest: m} do
      refute Map.has_key?(m["resources"], "EmptyResource")
    end

    test "only includes resources that have rpc actions", %{manifest: m, entries: entries} do
      with_actions =
        entries
        |> Enum.map(&(&1.resource |> Module.split() |> List.last()))
        |> Enum.uniq()
        |> Enum.sort()

      assert m["resources"] |> Map.keys() |> Enum.sort() == with_actions
    end
  end

  describe "function naming" do
    test "function names are camelCase", %{manifest: m} do
      names = Enum.map(m["actions"], & &1["functionName"])
      assert "listTodos" in names
      assert "createTodo" in names
      refute Enum.any?(names, &(&1 =~ "_"))
    end
  end

  describe "real manifest output (action ids, sections, flags, bytes)" do
    defp action(m, fname), do: Enum.find(m["actions"], &(&1["functionName"] == fname))

    defp build_json(entries) do
      entries |> then(&ActionManifest.build(RFP.manifest(), &1)) |> ActionManifest.to_json()
    end

    test "top-level sections and action ids", %{manifest: m, entries: entries} do
      assert m |> Map.keys() |> Enum.sort() == ["actions", "namespaces", "resources", "version"]
      assert m["version"] == "1.0"
      assert length(m["actions"]) == length(entries)

      assert Enum.sort(Enum.map(m["actions"], & &1["name"])) ==
               entries |> Enum.map(&to_string(&1.name)) |> Enum.sort()

      assert Enum.all?(
               m["actions"],
               &(&1["functionName"] == ActionManifest.function_name(&1["name"]))
             )

      assert action(m, "createTodo")["name"] == "create_todo"
      assert action(m, "createTodo")["actionType"] == "create"
      assert action(m, "createTodo")["resource"] == "Todo"
    end

    test "action fields: exact key set per action", %{manifest: m} do
      expected =
        ~w(actionType deprecated description enableFilter enableSort functionName get hasFields
           input metadataFields name namespace pagination resource see)

      for a <- m["actions"], do: assert(a |> Map.keys() |> Enum.sort() == expected)
    end

    test "description falls back to the action description, never empty-string override",
         %{entries: entries} do
      destroy_me = Enum.find(entries, &(&1.name == :destroy_me))
      assert destroy_me

      base = action(Jason.decode!(build_json([destroy_me])), "destroyMe")
      assert base["description"] =~ "Delete the authenticated user's own account"

      blank =
        action(Jason.decode!(build_json([Map.put(destroy_me, :description, "")])), "destroyMe")

      assert blank["description"] == base["description"]

      custom =
        action(
          Jason.decode!(build_json([Map.put(destroy_me, :description, "Mine")])),
          "destroyMe"
        )

      assert custom["description"] == "Mine"
    end

    test "enableFilter / enableSort follow the read action and entry flags", %{entries: entries} do
      list = Enum.find(entries, &(&1.name == :list_todos))

      m =
        Jason.decode!(
          build_json([
            list,
            Map.put(list, :name, :list_nf) |> Map.put(:enable_filter?, false),
            Map.put(list, :name, :list_ns) |> Map.put(:enable_sort?, false),
            Enum.find(entries, &(&1.name == :create_todo))
          ])
        )

      assert %{"enableFilter" => true, "enableSort" => true} =
               Map.take(action(m, "listTodos"), ["enableFilter", "enableSort"])

      assert %{"enableFilter" => false, "enableSort" => true} =
               Map.take(action(m, "listNf"), ["enableFilter", "enableSort"])

      assert %{"enableFilter" => true, "enableSort" => false} =
               Map.take(action(m, "listNs"), ["enableFilter", "enableSort"])

      assert %{"enableFilter" => false, "enableSort" => false} =
               Map.take(action(m, "createTodo"), ["enableFilter", "enableSort"])
    end

    test "get flags, pagination and input classification", %{manifest: m} do
      list = action(m, "listTodos")
      assert list["get"] == false

      assert list["pagination"] == %{
               "supported" => true,
               "required" => false,
               "offset" => true,
               "keyset" => true,
               "countable" => true,
               "get" => false
             }

      for f <- ~w(getSingleTodo getTodoByUserAndStatus) do
        a = action(m, f)
        assert a["get"] == true
        assert a["pagination"]["supported"] == false
        assert a["pagination"]["get"] == true
      end

      assert action(m, "createTodo")["input"] == "required"
      assert action(m, "destroyMe")["input"] == "none"
      assert action(m, "readWithInvalidArg")["input"] == "optional"
      assert action(m, "destroyMe")["hasFields"] == false
      assert action(m, "createTodo")["hasFields"] == true
    end

    test "deprecated marker forms and metadata field names", %{manifest: m, entries: entries} do
      assert action(m, "listTodosDeprecated")["deprecated"] == "Use listTodosV2 instead"
      assert action(m, "listTodosDeprecatedSimple")["deprecated"] == false

      simple =
        entries
        |> Enum.find(&(&1.name == :list_todos_deprecated_simple))
        |> Map.put(:deprecated, true)

      assert action(Jason.decode!(build_json([simple])), "listTodosDeprecatedSimple")[
               "deprecated"
             ] ==
               true

      assert action(m, "listTodos")["deprecated"] == false

      assert action(m, "readTasksWithMetadataTwo")["metadataFields"] == [
               "some_number",
               "some_string"
             ]

      assert action(m, "listTodos")["metadataFields"] == []
    end

    test "resources section carries relationship capabilities for each resource", %{manifest: m} do
      for {_name, r} <- m["resources"] do
        assert Map.keys(r) == ["relationships"]

        for {_rel, caps} <- r["relationships"] do
          assert caps |> Map.keys() |> Enum.sort() == ["filterable", "pagination", "sortable"]
          assert caps["pagination"] in ~w(mixed offset keyset none)
        end
      end
    end

    test "relationship query capabilities are exact for Todo many-relationships", %{manifest: m} do
      rels = m["resources"]["Todo"]["relationships"]
      caps = fn pg, f, so -> %{"pagination" => pg, "filterable" => f, "sortable" => so} end

      assert rels["unfilterable_comments"] == caps.("mixed", false, true)
      assert rels["unsortable_comments"] == caps.("mixed", true, false)
      assert rels["unpaginated_comments"] == caps.("none", true, true)
      assert rels["keyset_comments"] == caps.("keyset", true, true)
      assert rels["offset_comments"] == caps.("offset", true, true)
      assert rels["comments"] == caps.("mixed", true, true)
      assert m["resources"]["Article"]["relationships"] == %{}
    end

    test "bytes are deterministic, canonical and newline-terminated", %{entries: entries} do
      a = build_json(entries)
      assert a == build_json(Enum.reverse(entries))
      assert String.ends_with?(a, "\n")
      refute String.ends_with?(a, "\n\n")

      assert Jason.decode!(a)["actions"] |> Enum.map(& &1["functionName"]) ==
               Jason.decode!(a)["actions"] |> Enum.map(& &1["functionName"]) |> Enum.sort()

      refute a =~ "generatedAt"
    end
  end
end
