defmodule AshSurface.Ported.Rpc.D.RunTypedQueryRunnerSurfaceTest do
  @moduledoc """
  Surface port of `run_typed_query_test.exs` (12 cases formerly loud skips). The typed query is
  the real DSL entity of the private `TqTodo` fixture; the runner
  (`AshSurface.RuntimeParity.Rpc.TypedQuery`) resolves it by name, expands its declared fields
  through the pipeline's requested-fields processor and formats a caller-built result (real Ash
  structs, no data layer read: README, it never actuates). Filter / sort / page / input are
  asserted as the parsed request the action would receive; row selection by an Ash read is the
  caller's, so the result handed to the runner is already filtered / sorted / paged.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TypedQueryRpc, as: T

  @name :list_todos_user_page

  defp todos do
    [
      T.todo(id: "aaaaaaaa-0000-0000-0000-000000000001", title: "Test Todo 1", priority: :high),
      T.todo(
        id: "aaaaaaaa-0000-0000-0000-000000000002",
        title: "Test Todo 2",
        description: "Second test todo",
        priority: :medium
      )
    ]
  end

  defp parsed(params) do
    assert {:ok, request} = T.parse(@name, params)
    request
  end

  test "typed query lookup is manifest-based, so otp_app does not affect discovery" do
    assert %{"success" => true} = T.run(@name, %{}, todos())
  end

  test "successfully finds typed query and executes RPC pipeline" do
    assert %{"success" => true, "data" => data} = T.run(@name, %{}, todos())
    assert length(data) == 2
    first = hd(data)

    for key <- ["id", "title", "description", "priority", "commentCount"],
        do: assert(Map.has_key?(first, key), "missing #{key}")
  end

  test "correctly passes input parameter to RPC action" do
    params = %{"input" => %{"priorityFilter" => "high"}}
    assert %{input: %{priority_filter: "high"}} = parsed(params)

    assert %{"success" => true, "data" => [row]} = T.run(@name, params, [hd(todos())])
    assert row["priority"] == "high"
  end

  test "correctly passes page parameter to RPC action" do
    params = %{"page" => %{"limit" => 1, "offset" => 0}}
    assert %{pagination: %{limit: 1, offset: 0}} = parsed(params)

    page = %Ash.Page.Offset{results: [hd(todos())], limit: 1, offset: 0, count: 2, more?: true}

    assert %{
             "success" => true,
             "data" => %{"limit" => 1, "offset" => 0, "results" => [_]} = data
           } = T.run(@name, params, page)

    assert Map.has_key?(data, "hasMore")
    assert Map.has_key?(data, "count")
  end

  test "handles empty params correctly" do
    assert parsed(%{}) == parsed(%{"input" => %{}})
    assert T.run(@name, %{}, todos()) == T.run(@name, %{"input" => %{}}, todos())
    assert %{"data" => data} = T.run(@name, %{}, todos())
    assert length(data) == 2
  end

  test "returns data with exact field structure from typed query" do
    assert %{"success" => true, "data" => [first | _]} = T.run(@name, %{}, todos())

    assert first |> Map.keys() |> Enum.sort() ==
             Enum.sort(["id", "title", "description", "priority", "commentCount", "comments"])

    assert first["comments"] == []
  end

  test "typed query declared nested fields select only the nested subset" do
    todo = T.todo(comments: [T.comment(content: "c1")], comment_count: 1)
    assert %{"data" => [row]} = T.run(@name, %{}, [todo])
    assert [%{"id" => _, "content" => "c1"} = comment] = row["comments"]
    assert map_size(comment) == 2
    assert row["commentCount"] == 1
  end

  test "correctly passes filter parameter to RPC action" do
    params = %{"filter" => %{"priority" => "high"}}
    assert %{filter: %{priority: "high"}} = parsed(params)

    assert %{"success" => true, "data" => [row]} = T.run(@name, params, [hd(todos())])
    assert row["priority"] == "high"
    assert row["title"] == "Test Todo 1"
  end

  test "correctly passes filter parameter with multiple conditions" do
    params = %{"filter" => %{"and" => [%{"priority" => "medium"}, %{"completed" => false}]}}
    assert %{filter: %{and: [%{priority: "medium"}, %{completed: false}]}} = parsed(params)

    assert %{"success" => true, "data" => [row]} = T.run(@name, params, [List.last(todos())])
    assert row["priority"] == "medium"
    assert row["title"] == "Test Todo 2"
  end

  test "correctly passes sort parameter to RPC action" do
    assert %{sort: "-priority"} = parsed(%{"sort" => "-priority"})

    sorted = Enum.reverse(todos())
    assert %{"success" => true, "data" => data} = T.run(@name, %{"sort" => "-priority"}, sorted)
    assert Enum.map(data, & &1["title"]) == ["Test Todo 2", "Test Todo 1"]
  end

  test "correctly passes sort parameter with multiple fields" do
    assert %{sort: "title,-priority"} = parsed(%{"sort" => "title,-priority"})

    assert %{"success" => true, "data" => data} =
             T.run(@name, %{"sort" => "title,-priority"}, todos())

    assert Enum.map(data, & &1["title"]) == ["Test Todo 1", "Test Todo 2"]
  end

  test "correctly combines filter, sort, and pagination parameters" do
    params = %{"sort" => "-title", "page" => %{"limit" => 1, "offset" => 0}}
    assert %{sort: "-title", pagination: %{limit: 1, offset: 0}} = parsed(params)

    page = %Ash.Page.Offset{
      results: [List.last(todos())],
      limit: 1,
      offset: 0,
      count: 2,
      more?: true
    }

    assert %{"success" => true, "data" => %{"results" => [first], "hasMore" => true} = data} =
             T.run(@name, params, page)

    assert first["title"] == "Test Todo 2"
    assert first["priority"] == "medium"
    assert data["limit"] == 1
    assert Map.has_key?(data, "count")
  end

  test "handles empty filter and sort parameters correctly" do
    params = %{"filter" => %{}, "sort" => nil}
    assert %{"success" => true, "data" => data} = T.run(@name, params, todos())
    assert data |> Enum.map(& &1["title"]) |> Enum.sort() == ["Test Todo 1", "Test Todo 2"]
  end

  test "unknown typed query refuses with typed_query_not_found" do
    assert %{"success" => false, "errors" => [%{"type" => "typed_query_not_found"}]} =
             T.run(:non_existent, %{}, [])
  end
end
