defmodule AshSurface.Ported.Rpc.A.InputFieldFormattingSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc/input_field_formatting_test.exs`: untyped map keys
  (`custom_data`) must survive request parsing and output formatting untouched while typed
  fields are formatted. Requests go through `Rpc.parse/1` (asserting `request.input`), the
  created record is a hand-built real `Todo` struct (no data layer) run through `Rpc.run/2`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Todo}

  @user_id "11111111-1111-1111-1111-111111111111"
  @todo_id "22222222-2222-2222-2222-222222222222"

  defp create(input, fields, attrs) do
    params = %{"action" => "create_todo", "input" => input, "fields" => fields}
    assert {:ok, request} = Rpc.parse(params)

    record =
      struct(Todo, Keyword.merge([id: @todo_id, user_id: @user_id, completed: false], attrs))

    {request, Rpc.run(params, record)}
  end

  describe "input field formatting with untyped maps" do
    test "input field formatting preserves untyped map keys" do
      custom = %{
        "userDefinedKey" => "should_not_be_formatted",
        "anotherCustom_field" => "also_preserved",
        "nested" => %{"deepKey" => "deep_value"}
      }

      {request, result} =
        create(
          %{"title" => "Test Todo", "userId" => @user_id, "customData" => custom},
          ["id", "title", "userId", "customData"],
          title: "Test Todo",
          custom_data: custom
        )

      assert request.input.custom_data == custom

      assert %{"success" => true, "data" => todo_data} = result
      custom_data = todo_data["customData"]

      assert custom_data["userDefinedKey"] == "should_not_be_formatted"
      assert custom_data["anotherCustom_field"] == "also_preserved"
      assert custom_data["nested"]["deepKey"] == "deep_value"

      refute Map.has_key?(custom_data, "user_defined_key")
      refute Map.has_key?(custom_data, "another_custom_field")
      refute Map.has_key?(custom_data["nested"], "deep_key")
    end

    test "input field formatting works for typed fields while preserving untyped maps" do
      custom = %{"clientKey" => "preserved_value", "another_Key" => "also_preserved"}

      {request, result} =
        create(
          %{"title" => "Formatted Title", "userId" => @user_id, "customData" => custom},
          ["id", "title", "userId", "customData"],
          title: "Formatted Title",
          custom_data: custom
        )

      # typed keys are renamed to internal atoms; untyped map keys are untouched
      assert request.input.title == "Formatted Title"
      assert request.input.user_id == @user_id
      refute Map.has_key?(request.input, :userId)
      assert request.input.custom_data == custom

      assert %{"success" => true, "data" => todo_data} = result
      assert todo_data["title"] == "Formatted Title"
      assert Map.has_key?(todo_data, "userId")
      refute Map.has_key?(todo_data, "user_id")

      custom_data = todo_data["customData"]
      assert custom_data["clientKey"] == "preserved_value"
      assert custom_data["another_Key"] == "also_preserved"
    end

    test "mixed typed and untyped fields in same request" do
      custom = %{
        "API_Version" => "v2",
        "client_metadata" => %{"browser" => "Chrome", "user_agent" => "Mozilla/5.0..."},
        "feature_flags" => ["new_ui", "beta_feature"]
      }

      {request, result} =
        create(
          %{
            "title" => "Mixed Fields Test",
            "userId" => @user_id,
            "completed" => false,
            "customData" => custom
          },
          ["id", "title", "userId", "completed", "customData"],
          title: "Mixed Fields Test",
          custom_data: custom
        )

      assert request.input.title == "Mixed Fields Test"
      assert request.input.user_id == @user_id
      # `completed` is not an accepted input of create_todo: the input formatter does not
      # rename it (divergence note: it stays under its client key for Ash to refuse/drop)
      assert request.input["completed"] == false
      assert request.input.custom_data == custom

      assert %{"success" => true, "data" => todo_data} = result
      assert todo_data["title"] == "Mixed Fields Test"
      assert Map.has_key?(todo_data, "userId")
      assert Map.has_key?(todo_data, "completed")

      custom_data = todo_data["customData"]
      assert custom_data["API_Version"] == "v2"
      assert custom_data["client_metadata"]["browser"] == "Chrome"
      assert custom_data["client_metadata"]["user_agent"] == "Mozilla/5.0..."
      assert custom_data["feature_flags"] == ["new_ui", "beta_feature"]
    end
  end
end
