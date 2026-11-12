defmodule AshSurface.Ported.RpcRunActionSortFilterSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of the request-side of `rpc_run_action_sort_filter_test.exs`.

  Converted: every `enable_sort?: false` / `enable_filter?: false` refusal test (decided at
  request-parse, so the "works without the parameter" half runs through the result processor
  over caller-supplied records). Added (not reference tests): the sort/filter/page parameters
  reach the parsed `Request` in the documented shapes. Tests whose assertion is the ORDER or
  MEMBERSHIP computed by the data layer (sort/filter/aggregate/pagination results) stay in the
  gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1]

  @records [
    todo(
      id: "22222222-2222-2222-2222-222222222211",
      title: "Alpha Todo",
      description: "First item"
    ),
    todo(
      id: "22222222-2222-2222-2222-222222222212",
      title: "Charlie Todo",
      description: nil,
      completed: true
    ),
    todo(
      id: "22222222-2222-2222-2222-222222222213",
      title: "Bravo Todo",
      description: "Second item"
    )
  ]

  defp types(result), do: Enum.map(List.wrap(result["errors"]), & &1["type"])

  describe "sort with enable_sort?: false" do
    test "string sort errors as disabled" do
      without_sort =
        Rpc.run(%{"action" => "list_todos_no_sort", "fields" => ["id", "title"]}, @records)

      with_sort =
        Rpc.error(%{
          "action" => "list_todos_no_sort",
          "fields" => ["id", "title"],
          "sort" => "-title"
        })

      assert without_sort["success"] == true
      assert with_sort["success"] == false
      assert "sort_not_supported" in types(with_sort)
    end

    test "list sort errors as disabled" do
      result =
        Rpc.error(%{
          "action" => "list_todos_no_sort",
          "fields" => ["id", "title"],
          "sort" => ["-title", "+completed"]
        })

      assert result["success"] == false
      assert "sort_not_supported" in types(result)
    end
  end

  describe "filter with enable_filter?: false" do
    test "isNil filter errors when filtering disabled" do
      all = Rpc.run(%{"action" => "list_todos_no_filter", "fields" => ["id", "title"]}, @records)

      with_filter =
        Rpc.error(%{
          "action" => "list_todos_no_filter",
          "fields" => ["id", "title"],
          "filter" => %{"description" => %{"isNil" => true}}
        })

      assert all["success"] == true
      assert with_filter["success"] == false
      assert "filter_not_supported" in types(with_filter)
    end
  end

  describe "combined sort, filter, and pagination (disabled flags)" do
    test "combined with enable_filter?: false errors on filter but sort alone works" do
      refused =
        Rpc.error(%{
          "action" => "list_todos_no_filter",
          "fields" => ["id", "title"],
          "filter" => %{"completed" => %{"eq" => false}},
          "sort" => ["title"]
        })

      assert refused["success"] == false
      assert "filter_not_supported" in types(refused)

      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "sort" => ["title"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "title"

      result = Rpc.run(params, @records)
      assert result["success"] == true
      assert length(result["data"]) >= 3
    end

    test "combined with enable_sort?: false errors on sort but filter alone works" do
      refused =
        Rpc.error(%{
          "action" => "list_todos_no_sort",
          "fields" => ["id", "title", "description"],
          "filter" => %{"description" => %{"isNil" => true}},
          "sort" => ["-title"]
        })

      assert refused["success"] == false
      assert "sort_not_supported" in types(refused)

      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title", "description"],
        "filter" => %{"description" => %{"isNil" => true}}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == %{description: %{is_nil: true}}
      assert Rpc.run(params, Enum.filter(@records, &is_nil(&1.description)))["success"] == true
    end

    test "combined with both disabled errors on filter first" do
      all =
        Rpc.run(
          %{"action" => "list_todos_no_filter_no_sort", "fields" => ["id", "title"]},
          @records
        )

      both =
        Rpc.error(%{
          "action" => "list_todos_no_filter_no_sort",
          "fields" => ["id", "title"],
          "filter" => %{"completed" => %{"eq" => false}},
          "sort" => ["-title"]
        })

      assert all["success"] == true
      assert both["success"] == false
      assert "filter_not_supported" in types(both)
    end
  end

  describe "request parse of sort/filter/page (added; not reference tests)" do
    test "string sort with prefixes and a filter reach the request unchanged" do
      assert {:ok, r} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title"],
                 "sort" => "-title,+completed",
                 "filter" => %{"description" => %{"isNil" => true}}
               })

      assert r.sort == "-title,+completed"
      assert r.filter == %{description: %{is_nil: true}}
    end

    test "list sort with nil-ordering prefixes and camelCase names is snake-cased; page parsed" do
      assert {:ok, r} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id"],
                 "sort" => ["++description", "-createdAt"],
                 "page" => %{"limit" => 1, "offset" => 1}
               })

      assert r.sort == "++description,-created_at"
      assert r.pagination == %{limit: 1, offset: 1}
    end
  end
end
