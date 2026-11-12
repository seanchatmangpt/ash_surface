defmodule AshSurface.Ported.Rpc.C.PaginationAdvancedSurfaceTest do
  @moduledoc """
  Port of the reference pagination_advanced tests that are decidable without a data layer:
  page-option validation at request parse and the result shape of caller-built empty
  pages. Tests that depend on the data layer's limit/offset/sort semantics, performance and
  cross-request consistency stay loud skips in `pagination_advanced_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.Ported, as: P

  test "unknown page option returns an invalid pagination error" do
    result =
      R.error(%{
        "action" => "list_todos",
        "fields" => ["id"],
        "page" => %{"limit" => 10, "notAPageOptionXyz" => 1}
      })

    assert result["success"] == false
    assert [error] = result["errors"]
    assert error["type"] == "invalid_pagination"
    assert error["vars"] == %{"keys" => "notAPageOptionXyz"}
    assert error["fields"] == ["notAPageOptionXyz"]
    assert error["path"] == ["page"]
  end

  test "empty result set returns empty array with pagination" do
    params = %{
      "action" => "list_todos",
      "fields" => ["id", "title"],
      "limit" => 10,
      "offset" => 0
    }

    assert {:ok, _request} = R.parse(params)

    result = R.run(params, [])
    assert result["success"] == true
    assert result["data"] == []
  end

  test "offset beyond available results returns empty array" do
    params = %{
      "action" => "list_todos",
      "fields" => ["id", "title"],
      "page" => %{"limit" => 10, "offset" => 100}
    }

    page =
      struct(Ash.Page.Offset, %{results: [], limit: 10, offset: 100, count: nil, more?: false})

    result = R.run(params, page)
    assert result["success"] == true
    assert result["data"]["results"] == []
  end

  test "limit larger than available results returns all available" do
    params = %{
      "action" => "list_todos",
      "fields" => ["id", "title"],
      "page" => %{"limit" => 100, "offset" => 0}
    }

    todos = for i <- 1..3, do: struct(P.Todo, %{id: "t#{i}", title: "Todo #{i}"})

    page =
      struct(Ash.Page.Offset, %{results: todos, limit: 100, offset: 0, count: nil, more?: false})

    result = R.run(params, page)
    assert result["success"] == true
    assert length(result["data"]["results"]) == 3
    assert result["data"]["hasMore"] == false
  end
end
