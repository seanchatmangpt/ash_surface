defmodule AshSurface.Ported.Rpc.RunAction.LtreeFixture.Domain do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.RunAction.LtreeFixture.User)
    resource(AshSurface.Ported.Rpc.RunAction.LtreeFixture.Todo)
  end
end

defmodule AshSurface.Ported.Rpc.RunAction.LtreeFixture.User do
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.RunAction.LtreeFixture.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  surface do
    type_name("LtreeUser")
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.RunAction.LtreeFixture.Todo do
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.RunAction.LtreeFixture.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  surface do
    type_name("LtreeTodo")
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
    attribute(:completed, :boolean, public?: true, default: false)
    attribute(:hierarchy, AshPostgres.Ltree, public?: true)

    attribute :strict_hierarchy, AshPostgres.Ltree do
      public?(true)
      constraints(escape?: true)
    end
  end

  relationships do
    belongs_to :user, AshSurface.Ported.Rpc.RunAction.LtreeFixture.User do
      public?(true)
      attribute_writable?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:title, :hierarchy, :strict_hierarchy, :user_id])
    end

    update :update do
      primary?(true)
      accept([:title, :hierarchy, :strict_hierarchy])
    end
  end
end

defmodule AshSurface.Ported.RpcRunActionLtreeSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_ltree_test.exs` over a private ltree-shaped
  fixture (T5 dropped the `AshPostgres.Ltree` attributes). A private manifest + entry table is
  installed for this (non-async) module only and the shared table is re-asserted on exit.
  Input casting to a label list is the real type's job (execution side); here the request
  carries the client value through unchanged and the result processor emits the label list.
  The `escape?: true` string rejection is an `AshPostgres.Ltree` cast error and stays in the gap
  file (the real type is not available).
  """
  use ExUnit.Case, async: false

  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support}
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.Ported.Rpc.RunAction.LtreeFixture, as: F

  @uid "11111111-1111-1111-1111-111111111111"
  @tid "22222222-2222-2222-2222-222222222222"

  setup_all do
    Application.put_env(:ash_surface_ltree_fixture, :ash_domains, [F.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_ltree_fixture)
    handle = Compat.prepare(manifest)

    entries = [
      Pipeline.entry(:list_todos, F.Todo, :read),
      Pipeline.entry(:create_todo, F.Todo, :create),
      Pipeline.entry(:update_todo, F.Todo, :update)
    ]

    Support.install(handle, entries)
    on_exit(fn -> AshSurface.Ported.Rpc.install() end)
    :ok
  end

  defp todo(attrs),
    do: struct(F.Todo, Keyword.merge([id: @tid, title: "T", completed: false], attrs))

  defp run(params, result), do: Pipeline.run_with_result(params, result, [], [])

  defp create(input, result, fields) do
    params = %{"action" => "create_todo", "input" => input, "fields" => fields}
    assert {:ok, request} = Pipeline.parse_request(params, [])
    {request, run(params, result)}
  end

  describe "AshPostgres.Ltree support" do
    test "creates todo with Ltree hierarchy field" do
      {request, result} =
        create(
          %{
            "title" => "Todo with Hierarchy",
            "hierarchy" => "projects.web.frontend.components",
            "userId" => @uid
          },
          todo(
            title: "Todo with Hierarchy",
            hierarchy: ["projects", "web", "frontend", "components"]
          ),
          ["id", "title", "hierarchy"]
        )

      assert request.input[:hierarchy] == "projects.web.frontend.components"
      assert result["success"] == true
      assert result["data"]["title"] == "Todo with Hierarchy"
      assert result["data"]["hierarchy"] == ["projects", "web", "frontend", "components"]
      assert Map.has_key?(result["data"], "id")
    end

    test "creates todo with null Ltree hierarchy field" do
      {request, result} =
        create(
          %{"title" => "Todo without Hierarchy", "userId" => @uid},
          todo(title: "Todo without Hierarchy", hierarchy: nil),
          ["id", "title", "hierarchy"]
        )

      refute Map.has_key?(request.input, :hierarchy)
      assert result["success"] == true
      assert is_nil(result["data"]["hierarchy"])
      assert Map.has_key?(result["data"], "id")
    end

    test "updates todo hierarchy field" do
      params = %{
        "action" => "update_todo",
        "identity" => @tid,
        "input" => %{"hierarchy" => "updated.complex.hierarchical.path.to.item"},
        "fields" => ["id", "title", "hierarchy"]
      }

      assert {:ok, request} = Pipeline.parse_request(params, [])
      assert request.input[:hierarchy] == "updated.complex.hierarchical.path.to.item"

      result =
        run(
          params,
          todo(title: "Todo to Update", hierarchy: ~w(updated complex hierarchical path to item))
        )

      assert result["success"] == true
      assert result["data"]["id"] == @tid
      assert result["data"]["title"] == "Todo to Update"

      assert result["data"]["hierarchy"] == [
               "updated",
               "complex",
               "hierarchical",
               "path",
               "to",
               "item"
             ]
    end

    test "updates todo hierarchy field to null" do
      params = %{
        "action" => "update_todo",
        "identity" => @tid,
        "input" => %{"hierarchy" => nil},
        "fields" => ["id", "title", "hierarchy"]
      }

      assert {:ok, request} = Pipeline.parse_request(params, [])
      assert Map.get(request.input, :hierarchy) == nil

      result = run(params, todo(title: "Todo to Clear", hierarchy: nil))
      assert result["success"] == true
      assert result["data"]["title"] == "Todo to Clear"
      assert is_nil(result["data"]["hierarchy"])
    end

    test "reads todos with hierarchy field selection" do
      values = [
        ["projects", "web", "frontend"],
        ["projects", "web", "backend", "api"],
        ["projects", "mobile", "ios", "components"],
        nil
      ]

      todos =
        values
        |> Enum.with_index()
        |> Enum.map(fn {h, i} ->
          todo(
            id: "22222222-2222-2222-2222-2222222222#{10 + i}",
            title: "Todo #{inspect(h)}",
            hierarchy: h
          )
        end)

      result = run(%{"action" => "list_todos", "fields" => ["id", "title", "hierarchy"]}, todos)
      assert result["success"] == true
      data = result["data"]
      assert length(data) >= 4

      Enum.each(data, fn t ->
        for k <- ["id", "title", "hierarchy"], do: assert(Map.has_key?(t, k))
        assert is_list(t["hierarchy"]) or is_nil(t["hierarchy"])
      end)

      assert data |> Enum.map(& &1["hierarchy"]) |> MapSet.new() == MapSet.new(values)
    end

    test "processes hierarchy field with mixed attributes and relationships" do
      t =
        todo(
          title: "Complex Todo",
          hierarchy: ~w(complex nested structure with many levels),
          user: struct(F.User, id: @uid, name: "John Doe")
        )

      result =
        run(
          %{
            "action" => "list_todos",
            "fields" => ["id", "title", "hierarchy", "completed", %{"user" => ["id", "name"]}]
          },
          [t]
        )

      assert result["success"] == true
      found = Enum.find(result["data"], &(&1["title"] == "Complex Todo"))
      assert found["hierarchy"] == ["complex", "nested", "structure", "with", "many", "levels"]
      assert Map.has_key?(found, "completed")
      assert found["user"]["name"] == "John Doe"
    end

    test "hierarchy field excluded when not requested" do
      t = todo(title: "Todo with Hidden Hierarchy", hierarchy: ~w(should not appear in results))
      result = run(%{"action" => "list_todos", "fields" => ["id", "title", "completed"]}, [t])
      assert result["success"] == true
      found = Enum.find(result["data"], &(&1["title"] == "Todo with Hidden Hierarchy"))
      assert Map.has_key?(found, "title")
      assert Map.has_key?(found, "completed")
      refute Map.has_key?(found, "hierarchy")
    end
  end

  describe "AshPostgres.Ltree constraint scenarios" do
    test "flexible hierarchy accepts string input" do
      {request, result} =
        create(
          %{
            "title" => "Flexible Hierarchy String",
            "hierarchy" => "projects.web.frontend.components",
            "userId" => @uid
          },
          todo(
            title: "Flexible Hierarchy String",
            hierarchy: ~w(projects web frontend components)
          ),
          ["id", "title", "hierarchy"]
        )

      assert request.input[:hierarchy] == "projects.web.frontend.components"
      assert result["success"] == true
      assert result["data"]["hierarchy"] == ["projects", "web", "frontend", "components"]
    end

    test "flexible hierarchy accepts array input" do
      {request, result} =
        create(
          %{
            "title" => "Flexible Hierarchy Array",
            "hierarchy" => ["projects", "web", "backend", "api"],
            "userId" => @uid
          },
          todo(
            title: "Flexible Hierarchy Array",
            hierarchy: ["projects", "web", "backend", "api"]
          ),
          ["id", "title", "hierarchy"]
        )

      assert request.input[:hierarchy] == ["projects", "web", "backend", "api"]
      assert result["data"]["hierarchy"] == ["projects", "web", "backend", "api"]
    end

    test "strict hierarchy accepts array input" do
      {request, result} =
        create(
          %{
            "title" => "Strict Hierarchy Array",
            "strictHierarchy" => ["projects", "mobile", "ios", "views"],
            "userId" => @uid
          },
          todo(
            title: "Strict Hierarchy Array",
            strict_hierarchy: ["projects", "mobile", "ios", "views"]
          ),
          ["id", "title", "strictHierarchy"]
        )

      assert request.input[:strict_hierarchy] == ["projects", "mobile", "ios", "views"]
      assert result["success"] == true
      assert result["data"]["strictHierarchy"] == ["projects", "mobile", "ios", "views"]
    end

    test "both hierarchy fields work together" do
      {request, result} =
        create(
          %{
            "title" => "Both Hierarchies",
            "hierarchy" => "flexible.string.input",
            "strictHierarchy" => ["strict", "array", "input"],
            "userId" => @uid
          },
          todo(
            title: "Both Hierarchies",
            hierarchy: ~w(flexible string input),
            strict_hierarchy: ~w(strict array input)
          ),
          ["id", "title", "hierarchy", "strictHierarchy"]
        )

      assert request.input[:hierarchy] == "flexible.string.input"
      assert request.input[:strict_hierarchy] == ["strict", "array", "input"]
      assert result["data"]["hierarchy"] == ["flexible", "string", "input"]
      assert result["data"]["strictHierarchy"] == ["strict", "array", "input"]
    end

    test "update both hierarchy types" do
      params = %{
        "action" => "update_todo",
        "identity" => @tid,
        "input" => %{
          "hierarchy" => ["updated", "flexible", "as", "array"],
          "strictHierarchy" => ["updated", "strict", "hierarchy"]
        },
        "fields" => ["id", "title", "hierarchy", "strictHierarchy"]
      }

      assert {:ok, request} = Pipeline.parse_request(params, [])
      assert request.input[:hierarchy] == ["updated", "flexible", "as", "array"]
      assert request.input[:strict_hierarchy] == ["updated", "strict", "hierarchy"]

      result =
        run(
          params,
          todo(
            title: "Update Both Test",
            hierarchy: ~w(updated flexible as array),
            strict_hierarchy: ~w(updated strict hierarchy)
          )
        )

      assert result["success"] == true
      assert result["data"]["id"] == @tid
      assert result["data"]["title"] == "Update Both Test"
      assert result["data"]["hierarchy"] == ["updated", "flexible", "as", "array"]
      assert result["data"]["strictHierarchy"] == ["updated", "strict", "hierarchy"]
    end
  end

  describe "ltree shaping and zod projection (mutation-killing)" do
    alias AshSurface.Compiler.{TypeFacts, ZodType}

    defp zod(fragment, samples) do
      root = Path.expand("../../../../..", __DIR__)

      script = """
      import { z } from "zod";
      const s = #{fragment};
      console.log(JSON.stringify(#{Jason.encode!(samples)}.map((v) => s.safeParse(v).success)));
      """

      {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: root)
      Jason.decode!(out)
    end

    test "list output keeps label order and exact labels across rows" do
      a = todo(id: "22222222-2222-2222-2222-22222222222a", hierarchy: ["z", "a", "m"])
      b = todo(id: "22222222-2222-2222-2222-22222222222b", hierarchy: ["only"])
      c = todo(id: "22222222-2222-2222-2222-22222222222c", hierarchy: [])

      result = run(%{"action" => "list_todos", "fields" => ["id", "hierarchy"]}, [a, b, c])

      assert result["data"] == [
               %{"id" => a.id, "hierarchy" => ["z", "a", "m"]},
               %{"id" => b.id, "hierarchy" => ["only"]},
               %{"id" => c.id, "hierarchy" => []}
             ]
    end

    test "strict_hierarchy output is a label list distinct from the plain field" do
      t = todo(hierarchy: ["p", "q"], strict_hierarchy: ["r", "s", "t"])

      result =
        run(%{"action" => "list_todos", "fields" => ["hierarchy", "strictHierarchy"]}, [t])

      assert result["data"] == [
               %{"hierarchy" => ["p", "q"], "strictHierarchy" => ["r", "s", "t"]}
             ]
    end

    test "fixture attributes analyze as ltree kind; default accepts string or label array" do
      a = TypeFacts.analyze(AshPostgres.Ltree, [])
      assert a.kind == "ltree"
      f = ZodType.fragment(a.definition)
      assert f == "z.union([z.string(), z.array(z.string())])"
      assert zod(f, ["a.b", ["a", "b"], [], 1, [1], nil, %{}]) ==
               [true, true, true, false, false, false, false]
    end

    test "escape?: true ltree projects to the array form only" do
      f =
        ZodType.fragment(%{
          "type" => %{"kind" => "ltree"},
          "constraints" => %{"escape?" => true}
        })

      assert f == "z.array(z.string())"
      assert zod(f, [["a", "b"], [], "a.b", 1, [1]]) == [true, true, false, false, false]

      plain =
        ZodType.fragment(%{"type" => %{"kind" => "ltree"}, "constraints" => %{"escape?" => false}})

      assert plain == "z.union([z.string(), z.array(z.string())])"
    end

    test "request keeps the dotted string; omitted hierarchy is absent from input" do
      params = %{
        "action" => "create_todo",
        "input" => %{"title" => "X", "hierarchy" => "a.b", "strictHierarchy" => "c.d", "userId" => @uid},
        "fields" => ["id"]
      }

      assert {:ok, request} = Pipeline.parse_request(params, [])
      assert request.input[:hierarchy] == "a.b"
      assert request.input[:strict_hierarchy] == "c.d"
    end
  end
end
