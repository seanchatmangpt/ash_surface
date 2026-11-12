defmodule AshSurface.Ported.Rpc.A.EnableFilterSurfaceTest do
  @moduledoc """
  Non-actuating port of `enable_filter_test.exs` (request-parse behavior of `enable_filter?`).
  TypeScript-text tests (config types, function bodies, channel functions) stay in the gap file:
  ash_surface generates no `.ts`.
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

  @disabled {:filter_not_supported, :top_level, :disabled}

  describe "enable_filter? option - pipeline behavior" do
    test "filter errors when enable_filter? is false" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "filter" => %{"status" => %{"eq" => "active"}}
      }

      assert {:error, @disabled} = Rpc.parse(params)
      assert [%{"type" => "filter_not_supported"}] = Rpc.error(params)["errors"]
    end

    test "filter is preserved when enable_filter? is true (default)" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{"status" => %{"eq" => "active"}}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == %{status: %{eq: "active"}}
    end

    test "sort is not affected by enable_filter?" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "sort" => "-createdAt"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == nil
      assert request.sort == "-created_at"
    end
  end

  describe "enable_filter? - pagination independence" do
    test "pagination works with enable_filter?: false" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "page" => %{"limit" => 10, "offset" => 0}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.pagination == %{limit: 10, offset: 0}
      assert request.filter == nil
    end
  end

  describe "enable_filter? - edge cases" do
    test "nil filter is handled correctly when enable_filter?: false" do
      assert {:ok, request} =
               Rpc.parse(%{"action" => "list_todos_no_filter", "fields" => ["id", "title"]})

      assert request.filter == nil
    end

    test "complex nested filter errors when enable_filter?: false" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "filter" => %{
          "and" => [
            %{"status" => %{"eq" => "active"}},
            %{"priority" => %{"greaterThan" => 5}}
          ]
        }
      }

      assert {:error, @disabled} = Rpc.parse(params)
    end

    test "empty map filter errors when enable_filter?: false" do
      params = %{"action" => "list_todos_no_filter", "fields" => ["id", "title"], "filter" => %{}}
      assert {:error, @disabled} = Rpc.parse(params)
    end
  end

  describe "enable_filter? - input preservation" do
    test "action input is preserved when enable_filter?: false" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "input" => %{"filterCompleted" => true}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.input == %{filter_completed: true}
      assert request.filter == nil
    end
  end

  describe "enable_filter? - combinations with sort and pagination" do
    test "sort only (filter disabled) with pagination" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => ["id", "title"],
        "sort" => "-createdAt",
        "page" => %{"limit" => 10}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == nil
      assert request.sort == "-created_at"
      assert request.pagination == %{limit: 10}
    end

    test "both filter and sort enabled (default) with pagination" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "filter" => %{"status" => %{"eq" => "active"}},
        "sort" => "-createdAt",
        "page" => %{"limit" => 10}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.filter == %{status: %{eq: "active"}}
      assert request.sort == "-created_at"
      assert request.pagination == %{limit: 10}
    end
  end

  describe "enable_filter? - compiled action manifest (IR counterpart of TS config/function/channel)" do
    test "enable_filter?: false -> enableFilter false while enableSort stays true" do
      a = manifest_action("listTodosNoFilter")
      assert a["enableFilter"] == false
      assert a["enableSort"] == true
    end

    test "enable_filter? default -> enableFilter true" do
      a = manifest_action("listTodos")
      assert a["enableFilter"] == true
      assert a["enableSort"] == true
    end

    test "enable_filter?: false still exposes the same pagination facts as the default action" do
      off = manifest_action("listTodosNoFilter")
      assert off["pagination"] == manifest_action("listTodos")["pagination"]
    end

    test "function/channel payload: disabled filter is refused at parse, never forwarded" do
      params = %{"action" => "list_todos_no_filter", "fields" => ["id"], "filter" => %{"a" => 1}}
      assert {:error, @disabled} = Rpc.parse(params)

      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos_no_filter",
                 "fields" => ["id"],
                 "sort" => "title"
               })

      assert request.filter == nil
      assert request.sort == "title"
    end
  end
end
