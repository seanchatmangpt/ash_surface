defmodule AshSurface.Ported.Rpc.D.RpcPipelineSurfaceTest do
  @moduledoc """
  Surface port of `rpc_pipeline_test.exs` against the non-actuating `Rpc.Pipeline` (stages 1, 3,
  4; stage 2 execution is not ported: README "it never actuates").
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Todo}
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Request}

  # Sort-field parsing resolves names with `String.to_existing_atom` (AshSurface never mints
  # atoms from client input; unknown names stay as the client's string). The reference domain
  # happens to define these attributes; the surface fixtures do not, so the atoms are
  # materialized here, making the camelCase -> snake_case sort assertions deterministic.
  @sort_atoms [:start_date, :end_date, :due_date, :inserted_at, :user_name, :updated_at]
  def sort_atoms, do: @sort_atoms

  describe "strict field validation - fail fast architecture" do
    test "fails immediately on unknown field" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title", "unknown_field"]
      }

      assert {:error, error} = Rpc.parse(params)
      assert {:unknown_field, :unknown_field, Todo, []} = error
    end

    test "fails on invalid field format" do
      params = %{
        "action" => "list_todos",
        # Invalid field format
        "fields" => [123]
      }

      assert {:error, error} = Rpc.parse(params)
      assert {:invalid_field_type, 123, []} = error
    end

    test "fails on invalid nested field specification" do
      params = %{
        "action" => "list_todos",
        # Should be a list
        "fields" => [%{"user" => "invalid_spec"}]
      }

      assert {:error, error} = Rpc.parse(params)
      # Should fail when trying to process relationship with invalid spec
      assert {:unsupported_field_combination, :relationship, :user, "invalid_spec", []} =
               error
    end

    test "fails on simple attribute with specification" do
      params = %{
        "action" => "list_todos",
        # title is simple attribute, cannot have spec
        "fields" => [%{"title" => ["nested"]}]
      }

      assert {:error, error} = Rpc.parse(params)
      assert {:field_does_not_support_nesting, :title, []} = error
    end

    test "succeeds with valid fields" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title", "description"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.resource == Todo
      assert :id in request.select
      assert :title in request.select
      assert :description in request.select
    end
  end

  describe "four-stage pipeline architecture" do
    test "stage 1: parse_request validates and structures request" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "input" => %{"filterCompleted" => true},
        "filter" => %{"status" => "active"},
        "sort" => "title"
      }

      assert {:ok, request} = Rpc.parse(params)

      # Verify structured request contains all parsed data
      assert request.resource == Todo
      assert request.action.name == :read
      assert request.select == [:id, :title]
      assert request.load == []
      # Formatted from camelCase - only known arguments are converted
      assert request.input == %{filter_completed: true}
      assert request.filter == %{status: "active"}
      assert request.sort == "title"
    end

    test "stage 3: filter_result_fields applies extraction template" do
      # Mock result data
      ash_result = [
        %{id: 1, title: "Test Todo", description: "Test description"},
        %{id: 2, title: "Another Todo", description: "Another description"}
      ]

      # Create extraction template for id and title only (list format used by implementation)
      extraction_template = [:id, :title]

      # Need to provide an action for unconstrained_map_action? check
      action = Ash.Resource.Info.action(Todo, :read)

      request = %Request{
        extraction_template: extraction_template,
        action: action,
        resource: Todo
      }

      assert {:ok, filtered_result} = Pipeline.process_result(ash_result, request)

      # Verify only requested fields are present (still with atom keys at this stage)
      assert is_list(filtered_result)
      first_item = List.first(filtered_result)
      assert Map.has_key?(first_item, :id)
      assert Map.has_key?(first_item, :title)
      # Should be filtered out
      refute Map.has_key?(first_item, :description)
    end

    test "stage 4: format_output applies field name formatting" do
      # Mock filtered result with atom keys
      filtered_result = [
        %{id: 1, title: "Test Todo"},
        %{id: 2, title: "Another Todo"}
      ]

      _request = %Request{}

      formatted_result = Pipeline.format_output(filtered_result)

      # Verify field names are formatted for client consumption (camelCase by default)
      assert is_list(formatted_result)
      first_item = List.first(formatted_result)
      # Simple field
      assert Map.has_key?(first_item, "id")
      # Simple field
      assert Map.has_key?(first_item, "title")
      # No atom keys in output
      refute Map.has_key?(first_item, :id)
    end
  end

  describe "comprehensive field type support" do
    test "handles simple attributes correctly" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title", "description", "status"]
      }

      assert {:ok, request} = Rpc.parse(params)

      # All simple attributes should go to select
      assert :id in request.select
      assert :title in request.select
      assert :description in request.select
      assert :status in request.select
      assert request.load == []
    end

    test "handles simple calculations correctly" do
      params = %{
        "action" => "list_todos",
        # isOverdue is a simple calculation
        "fields" => ["id", "isOverdue"]
      }

      assert {:ok, request} = Rpc.parse(params)

      # Simple attributes go to select, calculations go to load
      assert :id in request.select
      # Converted from camelCase
      assert :is_overdue in request.load
      refute :is_overdue in request.select
    end

    test "handles complex calculations with arguments" do
      params = %{
        "action" => "list_todos",
        "fields" => [
          "id",
          %{"self" => %{"args" => %{"prefix" => "test"}, "fields" => ["id", "title"]}}
        ]
      }

      assert {:ok, request} = Rpc.parse(params)

      # Verify complex calculation load statement
      assert :id in request.select

      # Should have a load statement for the self calculation
      # Updated to match the new format with field selection
      self_load =
        Enum.find(request.load, fn
          {:self, {%{prefix: "test"}, [:id, :title]}} -> true
          _ -> false
        end)

      assert self_load != nil
    end

    test "handles relationships with nested fields" do
      params = %{
        "action" => "list_todos",
        "fields" => [
          "id",
          %{"user" => ["id", "name", "email"]}
        ]
      }

      assert {:ok, request} = Rpc.parse(params)

      # Simple field goes to select
      assert :id in request.select

      # Relationship should create nested load
      user_load =
        Enum.find(request.load, fn
          {:user, nested_fields} when is_list(nested_fields) -> true
          _ -> false
        end)

      assert user_load != nil

      # Verify nested fields are parsed
      {_user, nested_fields} = user_load
      assert :id in nested_fields
      assert :name in nested_fields
      assert :email in nested_fields
    end

    test "handles embedded resources with field selection" do
      params = %{
        "action" => "list_todos",
        "fields" => [
          "id",
          # displayCategory is a calculation
          %{"metadata" => ["category", "displayCategory"]}
        ]
      }

      assert {:ok, request} = Rpc.parse(params)

      # Simple field goes to select
      assert :id in request.select

      # Embedded resource should handle both select and load appropriately
      # This tests the dual-nature processing of embedded resources
      # Check if metadata field is present in the extraction template list
      metadata_present =
        Enum.any?(request.extraction_template, fn
          {:metadata, _} -> true
          _ -> false
        end)

      assert metadata_present
    end
  end

  describe "format_sort_string/2 function" do
    test "formats nil sort string" do
      assert Pipeline.format_sort_string(nil, :camel_case) == nil
    end

    test "formats single field without modifier" do
      assert Pipeline.format_sort_string("userName", :camel_case) == "user_name"
    end

    test "formats single field with + modifier" do
      assert Pipeline.format_sort_string("+userName", :camel_case) == "+user_name"
    end

    test "formats single field with ++ modifier" do
      assert Pipeline.format_sort_string("++startDate", :camel_case) == "++start_date"
    end

    test "formats single field with - modifier" do
      assert Pipeline.format_sort_string("-endDate", :camel_case) == "-end_date"
    end

    test "formats single field with -- modifier" do
      assert Pipeline.format_sort_string("--dueDate", :camel_case) == "--due_date"
    end

    test "formats multiple fields with mixed modifiers" do
      input = "userName,-createdAt,++priority,--dueDate,+status"
      expected = "user_name,-created_at,++priority,--due_date,+status"
      assert Pipeline.format_sort_string(input, :camel_case) == expected
    end

    test "handles empty field names correctly" do
      # Edge case: empty string should be handled gracefully
      assert Pipeline.format_sort_string("", :camel_case) == ""
    end

    test "preserves whitespace-free formatting" do
      # No spaces should be added or removed
      input = "-userName,+createdAt"
      expected = "-user_name,+created_at"
      assert Pipeline.format_sort_string(input, :camel_case) == expected
    end
  end

  describe "sort parameter formatting" do
    test "formats simple sort field with camelCase to snake_case" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "createdAt"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "created_at"
    end

    test "preserves descending modifier while formatting field name" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "-updatedAt"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "-updated_at"
    end

    test "preserves descending with nils last modifier" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "--dueDate"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "--due_date"
    end

    test "preserves ascending with nils first modifier" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "++startDate"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "++start_date"
    end

    test "preserves explicit ascending modifier" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "+insertedAt"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "+inserted_at"
    end

    test "handles multiple sort fields with different modifiers" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "--dueDate,+insertedAt,-userName"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "--due_date,+inserted_at,-user_name"
    end

    test "handles complex multi-field sort with all modifier types" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "status,++priority,--dueDate,-updatedAt,+createdAt"
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == "status,++priority,--due_date,-updated_at,+created_at"
    end

    test "handles nil sort parameter" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"]
        # No sort parameter
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort == nil
    end

    test "preserves already snake_case field names" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id", "title"],
        "sort" => "-user_id,++is_active"
      }

      assert {:ok, request} = Rpc.parse(params)
      # Should preserve snake_case fields as-is
      assert request.sort == "-user_id,++is_active"
    end
  end

  describe "comprehensive error handling" do
    test "provides clear error for action not found" do
      params = %{
        "action" => "nonexistent_action",
        "fields" => ["id"]
      }

      assert {:error, {:action_not_found, "nonexistent_action"}} =
               Rpc.parse(params)
    end

    test "tenant is carried on the parsed request; the non-actuating pipeline never demands one (reference parity: tenant is enforced by Ash at execution)" do
      params = %{"action" => "list_org_todos", "fields" => ["id"]}

      # OrgTodo is multitenant; parse stage does not enforce it (stage 2 would, and never runs here).
      assert {:ok, %Request{resource: AshSurface.Ported.OrgTodo, tenant: nil}} = Rpc.parse(params)

      assert {:ok, %Request{tenant: "org-1"}} = Rpc.parse(params, tenant: "org-1")
      assert {:ok, %Request{tenant: "org-2"}} = Rpc.parse(Map.put(params, "tenant", "org-2"))
    end

    test "parity: an Ash TenantRequired error (raised at execution) surfaces as typed tenant_required" do
      reason = Ash.Error.Invalid.TenantRequired.exception(resource: AshSurface.Ported.OrgTodo)

      assert %{"success" => false, "errors" => [error]} = Pipeline.error_response(reason)
      assert error["type"] == "tenant_required"
      assert error["shortMessage"] == "Tenant required"
    end

    test "parity: a bare {:tenant_required, _} tuple is not a reference clause (unknown_error, as in reference)" do
      reason = {:tenant_required, AshSurface.Ported.OrgTodo}

      assert %{"success" => false, "errors" => [error]} = Pipeline.error_response(reason)
      assert error["type"] == "unknown_error"
      assert error["shortMessage"] == "Unknown error"
      assert error["message"] =~ "Unique error id: "
      assert is_binary(error["details"]["errorId"])
      assert error["fields"] == []
      assert error["path"] == []
    end

    test "provides clear error for invalid pagination" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id"],
        # Should be a map
        "page" => "invalid"
      }

      assert {:error, {:invalid_pagination, "invalid"}} =
               Rpc.parse(params)
    end

    test "handles valid pagination correctly" do
      params = %{
        "action" => "list_todos",
        "fields" => ["id"],
        "page" => %{"limit" => 10, "offset" => 0}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.pagination == %{limit: 10, offset: 0}
    end
  end
end
