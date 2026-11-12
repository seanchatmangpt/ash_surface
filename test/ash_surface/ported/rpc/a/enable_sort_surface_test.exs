defmodule AshSurface.Ported.Rpc.A.EnableSortSurfaceTest do
  @moduledoc """
  Non-actuating port of `enable_sort_test.exs` (request-parse behavior of `enable_sort?`).
  TypeScript-text tests stay in the gap file: ash_surface generates no `.ts`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Manifest.ActionManifest
  alias AshSurface.Ported.RFP
  alias AshSurface.Ported.Rpc

  defp manifest_action(fname) do
    RFP.manifest()
    |> ActionManifest.build(Rpc.entries())
    |> ActionManifest.to_json()
    |> Jason.decode!()
    |> Map.fetch!("actions")
    |> Enum.find(&(&1["functionName"] == fname))
  end

  @sort_disabled {:sort_not_supported, :top_level, :disabled}
  @filter_disabled {:filter_not_supported, :top_level, :disabled}

  describe "enable_sort? option - pipeline behavior" do
    test "sort errors when enable_sort? is false" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "sort" => "-createdAt"
      }

      assert {:error, @sort_disabled} = Rpc.parse(params)
      assert [%{"type" => "sort_not_supported"}] = Rpc.error(params)["errors"]
    end

    test "sort is preserved when enable_sort? is true (default)" do
      params = %{"action" => "list_todos", "fields" => ["id", "title"], "sort" => "-createdAt"}
      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "-created_at"
    end

    test "filter is not affected by enable_sort?" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "filter" => %{"status" => %{"eq" => "active"}}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == nil
      assert request.filter == %{status: %{eq: "active"}}
    end

    test "filter errors first when both enable options are false" do
      params = %{
        "action" => "list_todos_no_filter_no_sort",
        "fields" => ["id", "title"],
        "filter" => %{"status" => %{"eq" => "active"}},
        "sort" => "-createdAt"
      }

      assert {:error, @filter_disabled} = Rpc.parse(params)
    end
  end

  describe "enable_sort? - pagination independence" do
    test "pagination works with enable_sort?: false" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "page" => %{"limit" => 10, "offset" => 0}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.pagination == %{limit: 10, offset: 0}
      assert request.sort == nil
    end

    test "pagination works with both enable_filter?: false and enable_sort?: false" do
      params = %{
        "action" => "list_todos_no_filter_no_sort",
        "fields" => ["id", "title"],
        "page" => %{"limit" => 20, "offset" => 10}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.pagination == %{limit: 20, offset: 10}
      assert request.filter == nil
      assert request.sort == nil
    end
  end

  describe "enable_sort? - edge cases" do
    test "nil sort is handled correctly when enable_sort?: false" do
      assert {:ok, request} =
               Rpc.parse(%{"action" => "list_todos_no_sort", "fields" => ["id", "title"]})

      assert request.sort == nil
    end

    test "complex multi-field sort errors when enable_sort?: false" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "sort" => "-priority,+createdAt,title"
      }

      assert {:error, @sort_disabled} = Rpc.parse(params)
    end

    test "empty string sort counts as present and errors when enable_sort?: false" do
      params = %{"action" => "list_todos_no_sort", "fields" => ["id", "title"], "sort" => ""}
      assert {:error, @sort_disabled} = Rpc.parse(params)
    end
  end

  describe "enable_sort? - input preservation" do
    test "action input is preserved when enable_sort?: false" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "input" => %{"filterCompleted" => true}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.input == %{filter_completed: true}
      assert request.sort == nil
    end
  end

  describe "enable_sort? - combinations with filter and pagination" do
    test "filter only (sort disabled) with pagination" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "filter" => %{"status" => %{"eq" => "active"}},
        "page" => %{"limit" => 10}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == %{status: %{eq: "active"}}
      assert request.sort == nil
      assert request.pagination == %{limit: 10}
    end

    test "neither filter nor sort (both disabled) with pagination" do
      params = %{
        "action" => "list_todos_no_filter_no_sort",
        "fields" => ["id", "title"],
        "page" => %{"limit" => 10}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == nil
      assert request.sort == nil
      assert request.pagination == %{limit: 10}
    end
  end

  describe "enable_sort? - compiled action manifest and query schema (IR counterpart of TS)" do
    test "enable_sort?: false -> enableSort false while enableFilter stays true" do
      a = manifest_action("listTodosNoSort")
      assert a["enableSort"] == false
      assert a["enableFilter"] == true
    end

    test "both disabled -> neither flag" do
      a = manifest_action("listTodosNoFilterNoSort")
      assert a["enableFilter"] == false
      assert a["enableSort"] == false
    end

    test "enable_sort?: false keeps pagination facts of the default action" do
      assert manifest_action("listTodosNoSort")["pagination"] ==
               manifest_action("listTodos")["pagination"]
    end

    test "query schema omits sort when disabled, keeps page" do
      base = %{
        read?: true,
        enable_sort?: true,
        sortable_fields: ["title"],
        pagination: %{offset?: true}
      }

      assert {:ok, %{sort: sort, page: page}} =
               AshSurface.Compiler.QuerySchema.render_query_params(base)

      assert is_binary(sort) and is_binary(page)

      assert {:ok, %{sort: nil, page: ^page}} =
               AshSurface.Compiler.QuerySchema.render_query_params(%{base | enable_sort?: false})
    end

    test "function/channel payload: disabled sort is refused at parse, filter forwarded" do
      assert {:error, @sort_disabled} =
               Rpc.parse(%{
                 "action" => "list_todos_no_sort",
                 "fields" => ["id"],
                 "sort" => "title"
               })

      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos_no_filter_no_sort",
                 "fields" => ["id"],
                 "page" => %{"limit" => 5}
               })

      assert request.sort == nil and request.filter == nil
    end
  end
end
