defmodule AshSurface.Ported.RpcRunActionAggregatesSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_aggregates_test.exs`: refusals come from
  `Rpc.Pipeline.parse_request/2`; successful shapes come from the result processor over
  hand-built `Todo` structs that carry loaded aggregate values.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1, user: 1, comment: 1]

  defp list(fields, todos),
    do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos)

  defp error_for(fields), do: Rpc.error(%{"action" => "list_todos", "fields" => fields})

  defp first_error(result) do
    assert result["success"] == false
    assert is_list(result["errors"])
    hd(result["errors"])
  end

  defp loaded_todos do
    [
      todo(
        comment_count: 2,
        helpful_comment_count: 1,
        has_comments: true,
        average_rating: 4.0,
        highest_rating: 5,
        latest_comment_content: "Second comment",
        comment_authors: ["John Doe", "John Doe"]
      )
    ]
  end

  describe "primitive aggregates (no nested field selection)" do
    test "processes simple count aggregate" do
      result = list(["id", "title", "commentCount"], loaded_todos())
      assert result["success"] == true
      assert is_list(result["data"])

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
        assert is_integer(t["commentCount"])
        assert t["commentCount"] >= 0
      end)
    end

    test "processes filtered count aggregate" do
      result = list(["id", "helpfulCommentCount"], loaded_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert is_integer(t["helpfulCommentCount"])
        assert t["helpfulCommentCount"] >= 0
      end)
    end

    test "processes exists aggregate" do
      result = list(["id", "hasComments"], loaded_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert is_boolean(t["hasComments"])
      end)
    end

    test "processes avg and max aggregates" do
      result = list(["id", "averageRating", "highestRating"], loaded_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        if t["averageRating"], do: assert(is_number(t["averageRating"]))
        if t["highestRating"], do: assert(is_number(t["highestRating"]))
      end)
    end

    test "processes first aggregate of primitive field" do
      result = list(["id", "latestCommentContent"], loaded_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        if t["latestCommentContent"], do: assert(is_binary(t["latestCommentContent"]))
      end)
    end

    test "processes list aggregate of primitive field" do
      result = list(["id", "commentAuthors"], loaded_todos())
      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert is_list(t["commentAuthors"])
      end)
    end

    test "rejects nested field selection on primitive aggregates" do
      error = first_error(error_for([%{"commentCount" => ["id"]}]))
      assert error["message"] == "Cannot select fields from %{fieldType} %{field}"
    end

    test "rejects nested field selection on exists aggregate" do
      error = first_error(error_for([%{"hasComments" => ["id"]}]))
      assert error["message"] == "Cannot select fields from %{fieldType} %{field}"
    end

    test "rejects nested field selection on primitive list aggregate" do
      error = first_error(error_for([%{"commentAuthors" => ["id"]}]))
      assert error["message"] == "Cannot select fields from %{fieldType} %{field}"
    end
  end

  describe "validation of non-existent complex aggregates" do
    test "rejects non-existent complex aggregate (latest_comment)" do
      error =
        first_error(error_for(["id", %{"latestComment" => ["id", "content", "authorName"]}]))

      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "latestComment"
    end

    test "rejects non-existent complex aggregate (recent_comments)" do
      error = first_error(error_for(["id", %{"recentComments" => ["id", "content", "rating"]}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "recentComments"
    end

    test "rejects non-existent complex aggregate with nested relationships" do
      error =
        first_error(
          error_for([
            "id",
            %{"latestComment" => ["id", "content", %{"user" => ["id", "name"]}]}
          ])
        )

      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "latestComment"
    end

    test "rejects non-existent complex aggregate with empty field selection" do
      error = first_error(error_for([%{"latestComment" => []}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "latestComment"
    end

    test "rejects non-existent complex aggregate as simple string" do
      error = first_error(error_for(["latestComment"]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "latestComment"
    end
  end

  describe "mixed aggregate types" do
    test "processes multiple primitive aggregates together" do
      todos = [
        todo(
          comment_count: 1,
          has_comments: true,
          latest_comment_content: "Test comment",
          comment_authors: ["Mixed User"],
          title: "Mixed Aggregates Todo",
          user: user(name: "Mixed User", email: "mixed@example.com")
        )
      ]

      result =
        list(
          [
            "id",
            "commentCount",
            "hasComments",
            "latestCommentContent",
            "commentAuthors",
            "title",
            %{"user" => ["id", "name"]}
          ],
          todos
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "user")
        assert is_integer(t["commentCount"])
        assert is_boolean(t["hasComments"])
        assert is_binary(t["title"])
        assert is_list(t["commentAuthors"])
        if t["latestCommentContent"], do: assert(is_binary(t["latestCommentContent"]))

        if t["user"] do
          assert Map.has_key?(t["user"], "id")
          assert Map.has_key?(t["user"], "name")
        end
      end)
    end

    test "processes primitive aggregates with calculations" do
      inner = todo(title: "inner", description: "inner desc")

      todos = [
        todo(
          comment_count: 1,
          recent_comment_ids: [RpcFixtures.comment_id()],
          is_overdue: false,
          self: inner
        )
      ]

      result =
        list(
          [
            "id",
            "commentCount",
            "recentCommentIds",
            "isOverdue",
            %{"self" => %{"args" => %{"prefix" => "test"}, "fields" => ["title", "description"]}}
          ],
          todos
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert is_integer(t["commentCount"])
        assert is_list(t["recentCommentIds"])
        assert is_boolean(t["isOverdue"])

        if t["self"] do
          assert Map.has_key?(t["self"], "title")
          assert Map.has_key?(t["self"], "description")
        end
      end)
    end
  end

  describe "aggregate validation and error handling" do
    test "rejects non-existent aggregate" do
      error = first_error(error_for(["id", "nonExistentAggregate"]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "nonExistentAggregate"
    end

    test "rejects duplicate aggregate fields" do
      error = first_error(error_for(["commentCount", "commentCount"]))
      assert error["message"] == "Field %{field} was requested multiple times"
    end

    test "rejects mixed atom and map for same aggregate" do
      error = first_error(error_for(["commentCount", %{"commentCount" => []}]))
      assert error["message"] == "Field %{field} was requested multiple times"
    end
  end

  describe "aggregates in different action types" do
    test "processes aggregates in create actions" do
      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "input" => %{
              "title" => "New Todo with Aggregates",
              "userId" => RpcFixtures.user_id(),
              "autoComplete" => false
            },
            "fields" => ["id", "title", "commentCount", "latestCommentContent"]
          },
          todo(title: "New Todo with Aggregates", comment_count: 0, latest_comment_content: nil)
        )

      assert result["success"] == true
      created = result["data"]
      assert Map.has_key?(created, "id")
      assert created["title"] == "New Todo with Aggregates"
      assert is_integer(created["commentCount"])
      assert created["commentCount"] == 0
      assert is_nil(created["latestCommentContent"])
    end

    test "processes aggregates in update actions" do
      c = comment(content: "Update test comment", author_name: "Action User", rating: 4)

      result =
        Rpc.run(
          %{
            "action" => "update_todo",
            "identity" => RpcFixtures.todo_id(),
            "input" => %{"title" => "Updated Title"},
            "fields" => ["id", "title", "commentCount", "recentCommentIds"]
          },
          todo(title: "Updated Title", comment_count: 1, recent_comment_ids: [c.id])
        )

      assert result["success"] == true
      updated = result["data"]
      assert updated["id"] == RpcFixtures.todo_id()
      assert updated["title"] == "Updated Title"
      assert is_integer(updated["commentCount"])
      assert updated["commentCount"] == 1
      assert is_list(updated["recentCommentIds"])
      assert length(updated["recentCommentIds"]) == 1
      Enum.each(updated["recentCommentIds"], fn id -> assert is_binary(id) end)
    end
  end

  describe "aggregate value shaping (mutation-killing)" do
    test "every aggregate kind comes out with its exact wire value, Decimal as string" do
      t =
        todo(
          comment_count: 2,
          helpful_comment_count: 1,
          has_comments: true,
          average_rating: Decimal.new("4.50"),
          highest_rating: 5,
          latest_comment_content: "Second comment",
          comment_authors: ["A", "B"]
        )

      fields = [
        "commentCount",
        "helpfulCommentCount",
        "hasComments",
        "averageRating",
        "highestRating",
        "latestCommentContent",
        "commentAuthors"
      ]

      assert list(fields, [t])["data"] == [
               %{
                 "commentCount" => 2,
                 "helpfulCommentCount" => 1,
                 "hasComments" => true,
                 "averageRating" => "4.50",
                 "highestRating" => 5,
                 "latestCommentContent" => "Second comment",
                 "commentAuthors" => ["A", "B"]
               }
             ]
    end

    test "zero, false, nil and empty-list aggregates are preserved, not dropped" do
      t = todo(comment_count: 0, has_comments: false, average_rating: nil, comment_authors: [])

      assert list(["commentCount", "hasComments", "averageRating", "commentAuthors"], [t])[
               "data"
             ] ==
               [
                 %{
                   "commentCount" => 0,
                   "hasComments" => false,
                   "averageRating" => nil,
                   "commentAuthors" => []
                 }
               ]
    end

    test "an unloaded aggregate is omitted from the row rather than leaked as a struct" do
      t = todo([])
      row = hd(list(["id", "commentCount", "hasComments"], [t])["data"])
      assert Map.keys(row) == ["id"]
      assert {:ok, _} = Jason.encode(row)
    end

    test "aggregates across rows keep per-row values and order" do
      a = todo(id: "22222222-2222-2222-2222-22222222222a", comment_count: 1)
      b = todo(id: "22222222-2222-2222-2222-22222222222b", comment_count: 7)

      assert list(["id", "commentCount"], [a, b])["data"] == [
               %{"id" => a.id, "commentCount" => 1},
               %{"id" => b.id, "commentCount" => 7}
             ]
    end

    test "aggregate field kinds map to number/boolean/string/array zod under node" do
      cases = [
        {Ash.Type.Integer, "z.number().int()", [1, 0, 1.5, "1"], [true, true, false, false]},
        {Ash.Type.Boolean, "z.boolean()", [true, false, 1, "t"], [true, true, false, false]},
        {{:array, Ash.Type.String}, "z.array(z.string())", [["a"], [], [1], "a"],
         [true, true, false, false]}
      ]

      root = Path.expand("../../../../..", __DIR__)

      for {type, expected, samples, verdicts} <- cases do
        f =
          AshSurface.Compiler.ZodType.fragment(
            AshSurface.Compiler.TypeFacts.analyze(type, []).definition
          )

        assert f == expected

        script = """
        import { z } from "zod";
        const s = #{f};
        console.log(JSON.stringify(#{Jason.encode!(samples)}.map((v) => s.safeParse(v).success)));
        """

        {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: root)
        assert Jason.decode!(out) == verdicts
      end
    end
  end
end
