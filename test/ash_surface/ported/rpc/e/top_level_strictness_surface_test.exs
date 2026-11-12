defmodule AshSurface.Ported.Rpc.E.TopLevelStrictnessSurfaceTest do
  @moduledoc """
  Port of ash_typescript `rpc/top_level_strictness_test.exs` (9 tests) onto
  `Rpc.Pipeline.parse_request/2` over the installed RPC entry table (request-shape validation).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc

  describe "top-level filter strictness" do
    test "001 filter on an enable_filter?: false action errors as disabled" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id"],
        "filter" => %{"status" => %{"eq" => "active"}}
      }

      assert {:error, {:filter_not_supported, :top_level, :disabled}} = Rpc.parse(params)
    end

    test "002 filter on a get? read errors as unsupported" do
      params = %{
        "action" => "get_single_todo",
        "fields" => ["id"],
        "filter" => %{"status" => %{"eq" => "active"}}
      }

      assert {:error, {:filter_not_supported, :top_level, :unsupported}} = Rpc.parse(params)
    end

    test "003 filter on a mutation errors as unsupported" do
      params = %{
        "action" => "create_todo",
        "fields" => ["id"],
        "input" => %{},
        "filter" => %{"status" => %{"eq" => "active"}}
      }

      assert {:error, {:filter_not_supported, :top_level, :unsupported}} = Rpc.parse(params)
    end

    test "004 absent filter never errors" do
      assert {:ok, _} = Rpc.parse(%{"action" => "list_todos_no_filter", "fields" => ["id"]})
    end
  end

  describe "top-level sort strictness" do
    test "005 sort on an enable_sort?: false action errors as disabled" do
      params = %{"action" => "list_todos_no_sort", "fields" => ["id"], "sort" => "-createdAt"}
      assert {:error, {:sort_not_supported, :top_level, :disabled}} = Rpc.parse(params)
    end

    test "006 sort on a get_by action errors as unsupported" do
      params = %{
        "action" => "get_todo_by_user_and_status",
        "fields" => ["id"],
        "input" => %{
          "userId" => "00000000-0000-0000-0000-000000000001",
          "status" => "pending"
        },
        "sort" => "-createdAt"
      }

      assert {:error, {:sort_not_supported, :top_level, :unsupported}} = Rpc.parse(params)
    end
  end

  describe "top-level page strictness" do
    test "007 page on a get? read errors as unsupported" do
      params = %{"action" => "get_single_todo", "fields" => ["id"], "page" => %{"limit" => 5}}
      assert {:error, {:pagination_not_supported, :top_level, :unsupported}} = Rpc.parse(params)
    end

    test "008 empty page map counts as present" do
      params = %{"action" => "get_single_todo", "fields" => ["id"], "page" => %{}}
      assert {:error, {:pagination_not_supported, :top_level, :unsupported}} = Rpc.parse(params)
    end

    test "009 page on a paginatable read still works" do
      params = %{"action" => "list_todos", "fields" => ["id"], "page" => %{"limit" => 5}}
      assert {:ok, request} = Rpc.parse(params)
      assert request.pagination == %{limit: 5}
    end
  end
end
