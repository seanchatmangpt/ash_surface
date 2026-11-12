defmodule AshSurface.Ported.Rpc.C.RestrictedSchemaSurfaceTest do
  @moduledoc """
  Adaptation of the 15 reference restricted_schema_codegen tests. The reference asserts the
  generated TypeScript text of per-action restricted schemas (`Omit<TodoResourceSchema, 'user'>`
  and friends) for `denied_loads` / `allowed_loads`. ash_surface emits no `.ts`; the behavior
  those types prove is "a restricted action cannot select a denied or non-allowed load, and
  everything else stays selectable". It is asserted two ways, both against the real fixture:

    * Zod: `SelectionSchema` rendered from the real `Todo` read facts with the action's
      `allowed_loads` / `denied_loads` (top-level relationship names), parsed under node + real zod
    * runtime: the non-actuating RPC pipeline entries of the same names (`Rpc.parse/1`,
      `Rpc.run/2`), which also covers the nested paths and scalar (calculation) loads the Zod
      relationship facts do not nest
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{ResourceFacts, SelectionSchema}
  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.{Rpc, RpcFixtures, Tsa10}

  import RpcFixtures, only: [todo: 1, user: 1]

  setup_all do
    facts = ResourceFacts.build(P.Todo, Ash.Resource.Info.action(P.Todo, :read))
    %{facts: facts}
  end

  defp selection(facts, opts) do
    {:ok, zod} =
      SelectionSchema.render_selection_schema(
        facts.public_attributes,
        [],
        [relationships: facts.relationships, calculations: facts.calculations] ++ opts
      )

    zod
  end

  defp sel(fields, load), do: %{"fields" => fields, "load" => load}
  defp sel(fields), do: %{"fields" => fields}

  defp parse(action, fields),
    do: Rpc.parse(%{"action" => action, "fields" => fields})

  defp refused?(action, fields) do
    match?(
      {:error, {tag, _}} when tag in [:load_denied, :load_not_allowed],
      parse(action, fields)
    )
  end

  defp loads(action, fields) do
    assert {:ok, request} = parse(action, fields)
    request.load
  end

  describe "denied_loads schema generation" do
    test "001 generates Omit schema for simple denied_loads", %{facts: facts} do
      zod = selection(facts, denied_loads: ["user"])

      assert Tsa10.node_eval(zod, [
               sel(["id"], %{"user" => sel(["id"])}),
               sel(["id"], %{"comments" => sel(["id"])}),
               sel(["id"])
             ]) == [false, true, true]

      assert refused?("list_todos_deny_user", ["id", %{"user" => ["id"]}])
      assert [{:comments, [:id]}] = loads("list_todos_deny_user", ["id", %{"comments" => ["id"]}])
    end

    test "002 uses restricted schema in Fields type", %{facts: facts} do
      # attribute selection is untouched by a relationship denial
      zod = selection(facts, denied_loads: ["user"])
      assert Tsa10.node_eval(zod, [sel(["id", "title", "status"])]) == [true]
      assert [] == loads("list_todos_deny_user", ["id", "title", "status"])
    end

    test "003 uses restricted schema in InferResult" do
      # the shaped result carries exactly the selected, permitted fields
      u = user(id: "u1", name: "N", email: "n@example.com")
      t = todo(id: "t1", title: "T", user_id: "u1", user: u)

      result =
        Rpc.run(%{"action" => "list_todos_deny_user", "fields" => ["id", "title"]}, [t])

      assert result["success"] == true
      assert result["data"] == [%{"id" => "t1", "title" => "T"}]
    end

    test "004 keeps nullability of a restricted array of embedded resources" do
      # list_todos_deny_history_calc denies metadata_history.display_category only
      assert refused?("list_todos_deny_history_calc", [
               "id",
               %{"metadataHistory" => ["category", "displayCategory"]}
             ])

      fields = ["id", %{"metadataHistory" => ["category"]}]

      nil_result =
        Rpc.run(
          %{"action" => "list_todos_deny_history_calc", "fields" => fields},
          [todo(id: "t1", metadata_history: nil)]
        )

      assert nil_result["success"] == true, inspect(nil_result)
      assert [%{"id" => "t1", "metadataHistory" => nil}] = nil_result["data"]
    end
  end

  describe "allowed_loads schema generation" do
    test "005 generates Omit schema and overrides allowed fields with AttributesOnlySchema", %{
      facts: facts
    } do
      zod = selection(facts, allowed_loads: ["user"])

      assert Tsa10.node_eval(zod, [
               sel(["id"], %{"user" => sel(["id", "email"])}),
               sel(["id"], %{"comments" => sel(["id"])}),
               sel(["id"], %{"user" => sel(["id"], %{"comments" => sel(["id"])})})
             ]) == [true, false, false]

      assert [{:user, [:id, :email]}] =
               loads("list_todos_allow_only_user", ["id", %{"user" => ["id", "email"]}])

      assert refused?("list_todos_allow_only_user", ["id", %{"comments" => ["id"]}])
      # the allowed relationship is attributes-only: no nested loads on it
      assert refused?("list_todos_allow_only_user", [
               "id",
               %{"user" => ["id", %{"todos" => ["id"]}]}
             ])
    end

    test "006 uses restricted schema in Fields type", %{facts: facts} do
      zod = selection(facts, allowed_loads: ["user"])
      assert Tsa10.node_eval(zod, [sel(["id", "title"])]) == [true]
      assert [] == loads("list_todos_allow_only_user", ["id", "title"])
    end
  end

  describe "nested denied_loads schema generation" do
    test "007 generates nested restricted schema for denied_loads: [comments: [:todo]]" do
      assert refused?("list_todos_deny_nested", [
               "id",
               %{"comments" => ["id", %{"todo" => ["id"]}]}
             ])

      assert [{:comments, [:id, :content]}] =
               loads("list_todos_deny_nested", ["id", %{"comments" => ["id", "content"]}])
    end

    test "008 generates main schema that overrides comments relationship", %{facts: facts} do
      # only comments.todo is denied: comments itself and other relationships stay selectable
      zod = selection(facts, denied_loads: ["comments.todo"])

      assert Tsa10.node_eval(zod, [
               sel(["id"], %{"comments" => sel(["id"])}),
               sel(["id"], %{"user" => sel(["id"])})
             ]) == [true, true]

      assert [{:user, [:id]}] =
               loads("list_todos_deny_nested", ["id", %{"user" => ["id"]}])
    end
  end

  describe "nested allowed_loads schema generation" do
    test "009 generates nested restricted schema for allowed_loads: [:user, comments: [:todo]]" do
      assert [{:comments, [:id, {:todo, [:id]}]}] =
               loads("list_todos_allow_nested", [
                 "id",
                 %{"comments" => ["id", %{"todo" => ["id"]}]}
               ])

      assert refused?("list_todos_allow_nested", [
               "id",
               %{"comments" => ["id", %{"user" => ["id"]}]}
             ])
    end

    test "010 generates main schema with user and comments using appropriate schemas", %{
      facts: facts
    } do
      zod = selection(facts, allowed_loads: ["user", "comments.todo"])

      assert Tsa10.node_eval(zod, [
               sel(["id"], %{"user" => sel(["id"]), "comments" => sel(["id"])}),
               sel(["id"], %{"offset_comments" => sel(["id"])})
             ]) == [true, false]

      assert [{:user, [:id]}] = loads("list_todos_allow_nested", ["id", %{"user" => ["id"]}])
    end
  end

  describe "scalar loads (calculations and aggregates)" do
    test "011 an allowed scalar calculation is not omitted" do
      assert [{:comments, [:id, :weighted_score]}] =
               loads("list_todos_allow_nested_calc", [
                 "id",
                 %{"comments" => ["id", "weightedScore"]}
               ])

      # while the relationship inside the allowed comments path is still omitted
      assert refused?("list_todos_allow_nested_calc", [
               "id",
               %{"comments" => ["id", %{"todo" => ["id"]}]}
             ])
    end

    test "012 restricted schemas rewrite primitive fields so scalar loads are actually restricted" do
      assert refused?("list_todos_deny_nested_calc", [
               "id",
               %{"comments" => ["id", "weightedScore"]}
             ])

      assert [{:comments, [:id, :content]}] =
               loads("list_todos_deny_nested_calc", ["id", %{"comments" => ["id", "content"]}])
    end

    test "013 omit keys use the resource-aware field name mapping" do
      # User maps is_active? -> "isActive": the restriction must bite on the wire name
      assert refused?("list_users_deny_mapped_calc", ["id", "isActive"])
      assert [] == loads("list_users_deny_mapped_calc", ["id", "email"])

      assert refused?("list_todos_deny_mapped_calc", ["id", %{"user" => ["id", "isActive"]}])

      assert [{:user, [:id, :email]}] =
               loads("list_todos_deny_mapped_calc", ["id", %{"user" => ["id", "email"]}])

      # the unmapped spelling is not a field of the wire contract
      refute match?({:ok, _}, parse("list_users_deny_mapped_calc", ["id", "isActive?"]))
    end
  end

  describe "unrestricted actions" do
    test "014 use base resource schema when no restrictions", %{facts: facts} do
      zod = selection(facts, [])

      assert Tsa10.node_eval(zod, [
               sel(["id"], %{"user" => sel(["id"]), "comments" => sel(["id"])})
             ]) == [true]

      assert [{:user, [:id]}, {:comments, [:id]}] |> Enum.sort() ==
               Enum.sort(
                 loads("list_todos", ["id", %{"user" => ["id"]}, %{"comments" => ["id"]}])
               )
    end
  end

  describe "schema integration with InferResult" do
    test "015 restricted schema works with pagination types" do
      u = user(id: "u1", name: "N", email: "n@example.com")
      t = todo(id: "t1", title: "T", user_id: "u1", user: u)

      page =
        struct(Ash.Page.Offset, %{results: [t], limit: 10, offset: 0, count: 1, more?: false})

      params = %{
        "action" => "list_todos_deny_user",
        "fields" => ["id", "title"],
        "page" => %{"limit" => 10, "offset" => 0, "count" => true}
      }

      result = Rpc.run(params, page)
      assert result["success"] == true, inspect(result)
      assert result["data"]["results"] == [%{"id" => "t1", "title" => "T"}]
      assert to_string(result["data"]["type"]) == "offset"
      assert result["data"]["count"] == 1

      # denial still bites inside a paginated request
      assert {:error, {:load_denied, _}} =
               Rpc.parse(%{params | "fields" => ["id", %{"user" => ["id"]}]})
    end
  end
end
