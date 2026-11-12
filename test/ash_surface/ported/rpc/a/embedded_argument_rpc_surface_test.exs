defmodule AshSurface.Ported.Rpc.A.EmbeddedArgumentRpcSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `embedded_argument_rpc_test.exs`. The request (embedded
  resource passed as a plain map argument) is parsed by `Rpc.Pipeline.parse_request/2`; the
  action result is the literal map the fixture generic action's `run` returns, shaped by the
  result processor. Missing-argument failures are the `Ash.Error` the action would return,
  driven through `ErrorBuilder`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc

  @process_metadata_fields ["processed", "priority", "source"]
  @process_metadata_batch_fields ["processed", "priority"]

  defp required_error(field),
    do:
      {:error,
       Ash.Error.to_error_class([
         %Ash.Error.Changes.Required{field: field, type: :argument, resource: nil}
       ])}

  describe "process_metadata_todo action" do
    test "accepts embedded resource as plain map input" do
      params = %{
        "action" => "process_metadata_todo",
        "input" => %{
          "metadata" => %{
            "category" => "work",
            "priorityScore" => 85,
            "isUrgent" => true,
            "tags" => ["urgent", "important"]
          }
        },
        "fields" => @process_metadata_fields
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.action.name == :process_metadata

      result =
        Rpc.run(params, %{processed: true, priority: 85, source: "direct_embedded_argument"})

      assert result["success"] == true
      assert result["data"]["processed"] == true
      assert result["data"]["priority"] == 85
      assert result["data"]["source"] == "direct_embedded_argument"
    end

    test "accepts embedded resource with minimal fields" do
      params = %{
        "action" => "process_metadata_todo",
        "input" => %{"metadata" => %{"category" => "personal"}},
        "fields" => @process_metadata_fields
      }

      assert {:ok, _request} = Rpc.parse(params)

      result =
        Rpc.run(params, %{processed: true, priority: nil, source: "direct_embedded_argument"})

      assert result["success"] == true
      assert result["data"]["processed"] == true
      assert result["data"]["priority"] == nil
      assert result["data"]["source"] == "direct_embedded_argument"
    end

    test "fails when metadata is missing" do
      params = %{
        "action" => "process_metadata_todo",
        "input" => %{},
        "fields" => @process_metadata_fields
      }

      result = Rpc.run(params, required_error(:metadata))

      assert result["success"] == false
      assert is_list(result["errors"])
      assert [%{"type" => "required"} = error | _] = result["errors"]
      assert error["fields"] == ["metadata"]
    end

    test "refuses fields the action's constrained map does not declare" do
      result =
        Rpc.error(%{
          "action" => "process_metadata_todo",
          "input" => %{"metadata" => %{"category" => "work"}},
          "fields" => ["processed", "notAField"]
        })

      assert result["success"] == false
      assert [%{"type" => "unknown_map_field", "fields" => ["notAField"]} | _] = result["errors"]
    end
  end

  describe "process_metadata_batch_todo action" do
    test "accepts array of embedded resources as plain map input" do
      params = %{
        "action" => "process_metadata_batch_todo",
        "input" => %{
          "metadataItems" => [
            %{"category" => "work", "priorityScore" => 5},
            %{"category" => "personal", "priorityScore" => 2},
            %{"category" => "urgent", "priorityScore" => 10}
          ]
        },
        "fields" => @process_metadata_batch_fields
      }

      assert {:ok, _request} = Rpc.parse(params)

      result =
        Rpc.run(params, [
          %{processed: true, priority: 5},
          %{processed: true, priority: 2},
          %{processed: true, priority: 10}
        ])

      assert result["success"] == true
      assert is_list(result["data"])
      assert length(result["data"]) == 3
      assert Enum.map(result["data"], & &1["priority"]) == [5, 2, 10]
      Enum.each(result["data"], fn item -> assert item["processed"] == true end)
    end

    test "accepts empty array" do
      params = %{
        "action" => "process_metadata_batch_todo",
        "input" => %{"metadataItems" => []},
        "fields" => @process_metadata_batch_fields
      }

      assert {:ok, _request} = Rpc.parse(params)
      result = Rpc.run(params, [])

      assert result["success"] == true
      assert result["data"] == []
    end

    test "accepts single item array" do
      params = %{
        "action" => "process_metadata_batch_todo",
        "input" => %{"metadataItems" => [%{"category" => "solo", "priorityScore" => 7}]},
        "fields" => @process_metadata_batch_fields
      }

      assert {:ok, _request} = Rpc.parse(params)
      result = Rpc.run(params, [%{processed: true, priority: 7}])

      assert result["success"] == true
      assert length(result["data"]) == 1
      assert hd(result["data"])["processed"] == true
      assert hd(result["data"])["priority"] == 7
    end

    test "fails when metadataItems is missing" do
      params = %{
        "action" => "process_metadata_batch_todo",
        "input" => %{},
        "fields" => @process_metadata_batch_fields
      }

      result = Rpc.run(params, required_error(:metadata_items))

      assert result["success"] == false
      assert is_list(result["errors"])
      assert [%{"type" => "required"} = error | _] = result["errors"]
      assert error["fields"] == ["metadataItems"]
    end
  end
end
