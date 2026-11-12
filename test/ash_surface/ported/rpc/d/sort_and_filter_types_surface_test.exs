defmodule AshSurface.Ported.Rpc.D.SortAndFilterTypesSurfaceTest do
  @moduledoc """
  Surface port of the pipeline half of `sort_and_filter_types_test.exs` (list sort formatting,
  `sort` / `filter` / `page` request parsing, `isNil` pass-through). The TypeScript SortField /
  FilterField text tests stay loud skips in `sort_and_filter_types_gap_test.exs` (README: no
  generated `.ts`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  # Sort / filter field names resolve with `String.to_existing_atom` (AshSurface never mints
  # atoms from client input; an unknown name stays the client's string). The reference domain
  # defines these names; the surface fixtures may not, so the atoms are materialized here.
  @field_atoms [:due_date, :priority_score, :created_at, :is_nil, :priority, :title, :description]
  def field_atoms, do: @field_atoms

  describe "pipeline format_sort_string with list input" do
    test "formats single-element list" do
      assert Pipeline.format_sort_string(["-createdAt"], :camel_case) == "-created_at"
    end

    test "formats multi-element list" do
      result = Pipeline.format_sort_string(["-createdAt", "+title", "id"], :camel_case)
      assert result == "-created_at,+title,id"
    end

    test "formats list with all four prefix variants" do
      result =
        Pipeline.format_sort_string(
          ["title", "+title", "-title", "++title", "--title"],
          :camel_case
        )

      assert result == "title,+title,-title,++title,--title"
    end

    test "formats list with camelCase field names" do
      result =
        Pipeline.format_sort_string(
          ["--dueDate", "++priorityScore", "-createdAt"],
          :camel_case
        )

      assert result == "--due_date,++priority_score,-created_at"
    end

    test "formats empty list" do
      assert Pipeline.format_sort_string([], :camel_case) == ""
    end
  end

  describe "pipeline parse_request with list sort" do
    test "list sort is joined and formatted" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => ["-createdAt", "+title"]
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.sort == "-created_at,+title"
    end

    test "single-element list sort" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => ["--dueDate"]
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.sort == "--due_date"
    end

    test "list sort errors when enable_sort?: false" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", "title"],
        "sort" => ["-createdAt", "+title"]
      }

      assert {:error, {:sort_not_supported, :top_level, :disabled}} =
               Rpc.parse(params)
    end

    test "string sort still works" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "-createdAt,+title"
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.sort == "-created_at,+title"
    end
  end

  describe "isNil filter in pipeline" do
    test "isNil filter is passed through correctly" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{"dueDate" => %{"isNil" => true}}
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.filter == %{due_date: %{is_nil: true}}
    end

    test "isNil false value is passed through" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{"dueDate" => %{"isNil" => false}}
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.filter == %{due_date: %{is_nil: false}}
    end

    test "isNil combined with other operators" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{
          "and" => [
            %{"dueDate" => %{"isNil" => false}},
            %{"completed" => %{"eq" => false}}
          ]
        }
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.filter == %{
               and: [
                 %{due_date: %{is_nil: false}},
                 %{completed: %{eq: false}}
               ]
             }
    end
  end

  describe "combined sort + filter + pagination" do
    test "all three work together with list sort" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{
          "completed" => %{"eq" => false},
          "dueDate" => %{"isNil" => false}
        },
        "sort" => ["--dueDate", "+title"],
        "page" => %{"limit" => 20, "offset" => 0}
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.filter == %{
               completed: %{eq: false},
               due_date: %{is_nil: false}
             }

      assert request.sort == "--due_date,+title"
      assert request.pagination == %{limit: 20, offset: 0}
    end

    test "filter with isNil + string sort + keyset pagination" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{"description" => %{"isNil" => true}},
        "sort" => "-createdAt",
        "page" => %{"limit" => 10, "after" => "cursor123"}
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.filter == %{description: %{is_nil: true}}
      assert request.sort == "-created_at"
      assert request.pagination == %{limit: 10, after: "cursor123"}
    end

    test "list sort with filter disabled" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "sort" => ["++priority", "-createdAt"]
      }

      assert {:ok, request} = Rpc.parse(params)

      assert request.filter == nil
      assert request.sort == "++priority,-created_at"
    end
  end
end
