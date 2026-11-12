defmodule AshSurface.Ported.Rpc.B.LoadRestrictionsSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of the `run_action ...` describes of ash_typescript
  `rpc/load_restrictions_test`. The reference creates users/todos/comments through RPC
  create actions then lists them; ash_surface never actuates, so the listed result is the
  caller-built (already materialized) term with the relationships loaded, fed through
  `Rpc.run/2` (parse with load restrictions -> result processor -> output formatter).
  Refusals happen at parse time, before any result is consulted.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1, user: 1, comment: 1]

  defp scenario(title, content, uid) do
    u = user(id: uid, name: "Restriction User", email: "#{uid}@example.com")
    t = todo(id: "t-#{uid}", title: title, user_id: uid, user: u)
    c = comment(id: "c-#{uid}", content: content, todo_id: t.id, user_id: uid, user: u, todo: t)
    t = %{t | comments: [c]}
    %{user: u, todo: t}
  end

  defp run(action, fields, result, page \\ nil) do
    params = %{"action" => action, "fields" => fields}
    params = if page, do: Map.put(params, "page", page), else: params
    Rpc.run(params, result)
  end

  defp assert_refused(result, type, field_pred) do
    assert result["success"] == false
    assert is_list(result["errors"])
    [error | _] = result["errors"]
    assert error["type"] == type
    assert field_pred.(error["fields"])
  end

  defp offset_page(results, opts \\ []) do
    struct(
      Ash.Page.Offset,
      %{
        results: results,
        limit: Keyword.get(opts, :limit, 10),
        offset: 0,
        count: Keyword.get(opts, :count),
        more?: false
      }
    )
  end

  defp keyset_page(results, limit) do
    results =
      Enum.with_index(results, fn r, i ->
        Map.put(r, :__metadata__, %{keyset: "k#{i}"})
      end)

    struct(Ash.Page.Keyset, %{
      results: results,
      limit: limit,
      before: nil,
      after: nil,
      count: nil,
      more?: false
    })
  end

  describe "run_action with allowed_loads - no pagination" do
    setup do: scenario("Restriction Test Todo", "Test comment for restrictions", "u-allow")

    test "allows loading user when in allowed_loads list", %{user: u, todo: t} do
      result =
        run("list_todos_allow_only_user", ["id", "title", %{"user" => ["id", "email"]}], [t])

      assert result["success"] == true
      [out] = result["data"]
      assert out["title"] == "Restriction Test Todo"
      assert out["user"] == %{"id" => u.id, "email" => u.email}
    end

    test "rejects loading comments when not in allowed_loads list", %{todo: t} do
      result =
        run("list_todos_allow_only_user", ["id", "title", %{"comments" => ["id", "content"]}], [
          t
        ])

      assert_refused(result, "load_not_allowed", &("comments" in &1))
    end

    test "allows primitive fields without loads", %{todo: t} do
      result = run("list_todos_allow_only_user", ["id", "title", "description"], [t])
      assert result["success"] == true
      [out] = result["data"]
      assert Map.keys(out) |> Enum.sort() == ["description", "id", "title"]
    end

    test "rejects nested loads on allowed relationship (user.todos)", %{todo: t} do
      result =
        run(
          "list_todos_allow_only_user",
          ["id", "title", %{"user" => ["id", "email", %{"todos" => ["id", "title"]}]}],
          [t]
        )

      assert_refused(result, "load_not_allowed", fn f -> Enum.any?(f, &(&1 =~ "todos")) end)
    end
  end

  describe "run_action with denied_loads - no pagination" do
    setup do: scenario("Deny Test Todo", "Deny test comment", "u-deny")

    test "allows loading comments when not in denied_loads list", %{todo: t} do
      result =
        run("list_todos_deny_user", ["id", "title", %{"comments" => ["id", "content"]}], [t])

      assert result["success"] == true
      [out] = result["data"]
      assert [%{"content" => "Deny test comment"}] = out["comments"]
    end

    test "rejects loading user when in denied_loads list", %{todo: t} do
      result = run("list_todos_deny_user", ["id", "title", %{"user" => ["id", "email"]}], [t])
      assert_refused(result, "load_denied", &("user" in &1))
    end

    test "allows primitive fields without loads", %{todo: t} do
      result = run("list_todos_deny_user", ["id", "title", "status"], [t])
      assert result["success"] == true
      [out] = result["data"]
      assert Map.has_key?(out, "id") and Map.has_key?(out, "title")
    end
  end

  describe "run_action with nested allowed_loads" do
    setup do: scenario("Nested Allow Todo", "Nested allow comment", "u-nallow")

    test "allows user and comments.todo as per allowed_loads: [:user, comments: [:todo]]",
         %{user: u, todo: t} do
      result =
        run(
          "list_todos_allow_nested",
          [
            "id",
            "title",
            %{"user" => ["id", "email"]},
            %{"comments" => ["id", "content", %{"todo" => ["id", "title"]}]}
          ],
          [t]
        )

      assert result["success"] == true, inspect(result)
      [out] = result["data"]
      assert out["user"]["id"] == u.id
      [comment] = out["comments"]
      assert comment["todo"] == %{"id" => t.id, "title" => "Nested Allow Todo"}
    end

    test "rejects comments.user because only comments.todo is allowed", %{todo: t} do
      result =
        run(
          "list_todos_allow_nested",
          ["id", "title", %{"comments" => ["id", %{"user" => ["id", "email"]}]}],
          [t]
        )

      assert_refused(result, "load_not_allowed", &is_list/1)
    end
  end

  describe "run_action with nested denied_loads" do
    setup do: scenario("Nested Deny Todo", "Nested deny comment", "u-ndeny")

    test "allows comments without loading todo (denied_loads: [comments: [:todo]])", %{todo: t} do
      result =
        run("list_todos_deny_nested", ["id", "title", %{"comments" => ["id", "content"]}], [t])

      assert result["success"] == true
      [out] = result["data"]
      assert [comment] = out["comments"]
      assert comment == %{"id" => "c-u-ndeny", "content" => "Nested deny comment"}
      refute Map.has_key?(comment, "todo")
    end

    test "rejects comments.todo which is in nested denied_loads", %{todo: t} do
      result =
        run("list_todos_deny_nested", ["id", %{"comments" => ["id", %{"todo" => ["id"]}]}], [t])

      assert_refused(result, "load_denied", &is_list/1)
    end

    test "allows user because it's not in denied_loads", %{user: u, todo: t} do
      result =
        run("list_todos_deny_nested", ["id", "title", %{"user" => ["id", "email"]}], [t])

      assert result["success"] == true
      [out] = result["data"]
      assert out["user"]["id"] == u.id
    end
  end

  describe "run_action with allowed_loads - with offset pagination" do
    setup do: scenario("Pagination Allow Todo", "c", "u-poff")

    test "allows loading user with offset pagination", %{user: u, todo: t} do
      result =
        run(
          "list_todos_allow_only_user",
          ["id", "title", %{"user" => ["id", "email"]}],
          offset_page([t]),
          %{"offset" => 0, "limit" => 10}
        )

      assert result["success"] == true, inspect(result)
      data = result["data"]
      assert Map.has_key?(data, "results") and Map.has_key?(data, "hasMore")
      assert [%{"title" => "Pagination Allow Todo", "user" => %{"id" => id}}] = data["results"]
      assert id == u.id
    end

    test "rejects loading comments with offset pagination", %{todo: t} do
      result =
        run(
          "list_todos_allow_only_user",
          ["id", "title", %{"comments" => ["id"]}],
          offset_page([t]),
          %{"offset" => 0, "limit" => 10}
        )

      assert_refused(result, "load_not_allowed", &is_list/1)
    end

    test "returns paginated structure with count when requested", %{todo: t} do
      result =
        run(
          "list_todos_allow_only_user",
          ["id", "title", %{"user" => ["id"]}],
          offset_page([t], limit: 5, count: 1),
          %{"offset" => 0, "limit" => 5, "count" => true}
        )

      assert result["success"] == true, inspect(result)
      assert result["data"]["count"] == 1
    end
  end

  describe "run_action with denied_loads - with keyset pagination" do
    setup do: scenario("Keyset Deny Todo", "Keyset comment", "u-kdeny")

    test "allows loading comments with limit-based pagination (keyset first page)", %{todo: t} do
      result =
        run(
          "list_todos_deny_user",
          ["id", "title", %{"comments" => ["id", "content"]}],
          keyset_page([t], 20),
          %{"limit" => 20}
        )

      assert result["success"] == true, inspect(result)
      data = result["data"]
      assert Map.has_key?(data, "results") and Map.has_key?(data, "hasMore")
      assert [%{"title" => "Keyset Deny Todo", "comments" => [_]}] = data["results"]
    end

    test "rejects loading user with keyset pagination", %{todo: t} do
      result =
        run(
          "list_todos_deny_user",
          ["id", "title", %{"user" => ["id"]}],
          keyset_page([t], 10),
          %{"limit" => 10}
        )

      assert_refused(result, "load_denied", &is_list/1)
    end
  end

  describe "run_action with nested restrictions - with pagination" do
    setup do: scenario("Nested Paginated Todo", "Nested paginated comment", "u-npag")

    test "nested allowed_loads works with offset pagination", %{todo: t} do
      result =
        run(
          "list_todos_allow_nested",
          [
            "id",
            "title",
            %{"user" => ["id", "email"]},
            %{"comments" => ["id", %{"todo" => ["id"]}]}
          ],
          offset_page([t]),
          %{"offset" => 0, "limit" => 10}
        )

      assert result["success"] == true, inspect(result)

      assert [%{"comments" => [%{"todo" => %{"id" => _}}], "user" => %{}}] =
               result["data"]["results"]
    end

    test "nested denied_loads works with offset pagination", %{todo: t} do
      result =
        run(
          "list_todos_deny_nested",
          ["id", %{"user" => ["id"]}, %{"comments" => ["id"]}],
          offset_page([t], limit: 5),
          %{"offset" => 0, "limit" => 5}
        )

      assert result["success"] == true, inspect(result)
      [out] = result["data"]["results"]
      assert Map.has_key?(out, "user") and Map.has_key?(out, "comments")
    end

    test "nested denied_loads rejects denied nested field with pagination", %{todo: t} do
      result =
        run(
          "list_todos_deny_nested",
          ["id", %{"comments" => ["id", %{"todo" => ["id"]}]}],
          offset_page([t], limit: 5),
          %{"offset" => 0, "limit" => 5}
        )

      assert_refused(result, "load_denied", &is_list/1)
    end

    test "nested allowed_loads rejects disallowed nested field with pagination", %{todo: t} do
      result =
        run(
          "list_todos_allow_nested",
          ["id", %{"comments" => ["id", %{"user" => ["id"]}]}],
          offset_page([t], limit: 5),
          %{"offset" => 0, "limit" => 5}
        )

      assert_refused(result, "load_not_allowed", &is_list/1)
    end
  end
end
