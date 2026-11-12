defmodule AshSurface.Ported.RpcRunActionEmbeddedSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_embedded_test.exs`: embedded-resource and union
  attributes are hand-built real structs (`%TodoMetadata{}`, `%Ash.Union{}`) on `Todo` records.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures, TodoContent, TodoMetadata}
  import RpcFixtures, only: [todo: 1]

  defp meta(attrs \\ []),
    do:
      struct(
        TodoMetadata,
        Keyword.merge(
          [
            id: "55555555-5555-5555-5555-555555555555",
            category: "work",
            priority_score: 85,
            is_urgent: true,
            tags: ["important", "deadline"],
            internal_notes: "secret"
          ],
          attrs
        )
      )

  defp list(fields, todos), do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos)
  defp refuse(fields), do: Rpc.error(%{"action" => "list_todos", "fields" => fields})

  defp first_error(result) do
    assert result["success"] == false
    assert is_list(result["errors"])
    hd(result["errors"])
  end

  defp union(type, value), do: %Ash.Union{type: type, value: value}

  describe "simple embedded resource fields" do
    defp meta_todos,
      do: [
        todo(
          title: "Todo with Metadata",
          metadata: meta(display_category: "work", is_overdue: false)
        )
      ]

    test "processes embedded resource attribute fields correctly" do
      result =
        list(["id", "title", %{"metadata" => ["id", "category", "priorityScore"]}], meta_todos())

      assert result["success"] == true
      t = Enum.find(result["data"], &(&1["title"] == "Todo with Metadata"))
      assert Map.has_key?(t, "id")
      metadata = t["metadata"]
      assert Map.has_key?(metadata, "id")
      assert metadata["category"] == "work"
      assert metadata["priorityScore"] == 85
      refute Map.has_key?(metadata, "isUrgent")
      refute Map.has_key?(metadata, "tags")
    end

    test "processes embedded resource calculations" do
      result =
        list(["id", %{"metadata" => ["category", "displayCategory", "isOverdue"]}], meta_todos())

      assert result["success"] == true
      metadata = hd(result["data"])["metadata"]
      assert metadata["category"] == "work"
      assert is_binary(metadata["displayCategory"])
      assert is_boolean(metadata["isOverdue"])
    end

    test "processes embedded resource calculation with arguments" do
      fields = [
        "id",
        %{
          "metadata" => [
            "category",
            %{
              "adjusted_priority" => %{
                "args" => %{"urgency_multiplier" => 1.5, "deadline_factor" => true}
              }
            }
          ]
        }
      ]

      assert {:ok, _request} = Rpc.parse(%{"action" => "list_todos", "fields" => fields})

      result = list(fields, [todo(metadata: meta(adjusted_priority: 127))])
      assert result["success"] == true
      metadata = hd(result["data"])["metadata"]
      assert Map.has_key?(metadata, "category")
      assert metadata["adjustedPriority"] == 127
    end

    test "processes mixed embedded attributes and calculations" do
      result =
        list(
          [
            "id",
            %{
              "metadata" => [
                "category",
                "priorityScore",
                "isUrgent",
                "displayCategory",
                "isOverdue"
              ]
            }
          ],
          meta_todos()
        )

      assert result["success"] == true
      metadata = hd(result["data"])["metadata"]
      assert metadata["category"] == "work"
      assert metadata["priorityScore"] == 85
      assert metadata["isUrgent"] == true
      assert is_binary(metadata["displayCategory"])
      assert is_boolean(metadata["isOverdue"])
    end

    test "stress test: embedded resource with only attributes should be selected" do
      result =
        list(["id", %{"metadata" => ["category", "priorityScore", "isUrgent"]}], meta_todos())

      assert result["success"] == true
      metadata = hd(result["data"])["metadata"]
      assert metadata["category"] == "work"
      assert metadata["priorityScore"] == 85
      assert metadata["isUrgent"] == true
    end

    test "stress test: embedded resource mixing attributes and calculations" do
      result =
        list(["id", %{"metadata" => ["category", "displayCategory", "isOverdue"]}], meta_todos())

      assert result["success"] == true
      metadata = hd(result["data"])["metadata"]
      assert Map.has_key?(metadata, "category")

      if Map.has_key?(metadata, "displayCategory"),
        do: assert(is_binary(metadata["displayCategory"]))

      if Map.has_key?(metadata, "isOverdue"), do: assert(is_boolean(metadata["isOverdue"]))
    end
  end

  describe "array of embedded resources" do
    defp history_todos do
      [
        todo(
          title: "Todo with History",
          metadata_history: [
            meta(
              category: "personal",
              priority_score: 60,
              display_category: "personal",
              created_at: ~U[2026-01-01 00:00:00Z]
            ),
            meta(
              id: "66666666-6666-6666-6666-666666666666",
              category: "work",
              priority_score: 90,
              display_category: "work",
              created_at: ~U[2026-01-01 01:00:00Z]
            )
          ]
        )
      ]
    end

    test "processes array embedded resource fields correctly" do
      result =
        list(
          ["id", "title", %{"metadataHistory" => ["id", "category", "createdAt"]}],
          history_todos()
        )

      assert result["success"] == true
      t = Enum.find(result["data"], &(&1["title"] == "Todo with History"))
      history = t["metadataHistory"]
      assert is_list(history)
      assert length(history) >= 2

      Enum.each(history, fn m ->
        assert Map.has_key?(m, "id")
        assert Map.has_key?(m, "category")
        assert Map.has_key?(m, "createdAt")
        assert is_binary(m["category"])
        refute Map.has_key?(m, "priorityScore")
      end)

      categories = Enum.map(history, & &1["category"])
      assert "personal" in categories
      assert "work" in categories
    end

    test "processes array embedded resource with calculations" do
      result =
        list(
          ["id", %{"metadataHistory" => ["category", "priorityScore", "displayCategory"]}],
          history_todos()
        )

      assert result["success"] == true
      history = hd(result["data"])["metadataHistory"]
      assert is_list(history) and history != []

      Enum.each(history, fn m ->
        assert Map.has_key?(m, "category")
        assert Map.has_key?(m, "priorityScore")
        assert is_binary(m["displayCategory"])
      end)
    end
  end

  describe "union type with embedded resources" do
    defp text_todo,
      do:
        todo(
          title: "Text Content Todo",
          content:
            union(
              :text,
              struct(TodoContent.TextContent,
                text: "Sample text content",
                formatting: :markdown,
                id: RpcFixtures.todo_id()
              )
            )
        )

    defp checklist_todo,
      do:
        todo(
          title: "Checklist Content Todo",
          content:
            union(
              :checklist,
              struct(TodoContent.ChecklistContent,
                title: "My Checklist",
                id: RpcFixtures.todo_id(),
                items: [
                  %{text: "Item 1", completed: false},
                  %{text: "Item 2", completed: false},
                  %{text: "Item 3", completed: false}
                ]
              )
            )
        )

    defp link_todo,
      do:
        todo(
          title: "Link Content Todo",
          content:
            union(
              :link,
              struct(TodoContent.LinkContent,
                url: "https://example.com",
                title: "Example Link",
                id: RpcFixtures.todo_id()
              )
            )
        )

    test "processes union field selection for text content" do
      result =
        list(
          ["id", %{"content" => %{"text" => ["id", "text", "formatting"]}}],
          [text_todo(), checklist_todo(), link_todo()]
        )

      assert result["success"] == true

      t =
        Enum.find(
          result["data"],
          &(is_map(&1["content"]) and Map.has_key?(&1["content"], "text"))
        )

      content = t["content"]
      text_content = content["text"]
      assert Map.has_key?(text_content, "id")
      assert text_content["text"] == "Sample text content"
      assert text_content["formatting"] == "markdown"
      refute Map.has_key?(content, "checklist")
      refute Map.has_key?(content, "link")
    end

    test "processes union field selection for checklist content" do
      result =
        list(
          [
            "id",
            %{"content" => %{"checklist" => ["id", "title", %{"items" => ["text", "completed"]}]}}
          ],
          [text_todo(), checklist_todo(), link_todo()]
        )

      assert result["success"] == true

      t =
        Enum.find(
          result["data"],
          &(is_map(&1["content"]) and Map.has_key?(&1["content"], "checklist"))
        )

      content = t["content"]
      checklist_content = content["checklist"]
      assert Map.has_key?(checklist_content, "id")
      assert checklist_content["title"] == "My Checklist"
      assert is_list(checklist_content["items"])
      refute Map.has_key?(content, "text")
      refute Map.has_key?(content, "link")
    end

    test "processes union field selection for link content" do
      result =
        list(
          ["id", %{"content" => %{"link" => ["id", "url", "title"]}}],
          [text_todo(), checklist_todo(), link_todo()]
        )

      assert result["success"] == true

      t =
        Enum.find(
          result["data"],
          &(is_map(&1["content"]) and Map.has_key?(&1["content"], "link"))
        )

      content = t["content"]
      link_content = content["link"]
      assert Map.has_key?(link_content, "id")
      assert link_content["url"] == "https://example.com"
      assert link_content["title"] == "Example Link"
      refute Map.has_key?(content, "text")
      refute Map.has_key?(content, "checklist")
    end

    test "processes union field selection with calculations" do
      result =
        list(
          ["id", %{"content" => %{"text" => ["text", "displayText", "isFormatted"]}}],
          [text_todo()]
        )

      assert result["success"] == true
      text_content = hd(result["data"])["content"]["text"]
      assert text_content["text"] == "Sample text content"
    end
  end

  describe "error handling for embedded resources" do
    test "returns error for invalid embedded resource field" do
      error = first_error(refuse([%{"metadata" => ["invalidField"]}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "metadata.invalidField"
    end

    test "returns error for invalid nested embedded resource field" do
      error = first_error(refuse([%{"metadataHistory" => ["category", "invalidField"]}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "metadataHistory.invalidField"
    end

    test "returns error for invalid union member field" do
      error = first_error(refuse([%{"content" => %{"text" => ["invalidField"]}}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "content.text.invalidField"
    end

    test "returns error for accessing private embedded resource field" do
      error = first_error(refuse([%{"metadata" => ["internalNotes"]}]))
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "metadata.internalNotes"
    end

    test "returns error for calculation requiring args without providing them" do
      error = first_error(refuse([%{"metadata" => ["adjustedPriority"]}]))
      assert error["type"] == "invalid_field_format"
      assert List.first(error["fields"]) =~ "adjustedPriority"
    end

    test "returns error for providing args to calculation that doesn't accept them" do
      error =
        first_error(refuse([%{"metadata" => [%{"displayCategory" => %{"args" => %{}}}]}]))

      assert error["type"] == "invalid_calculation_args"
      assert List.first(error["fields"]) =~ "displayCategory"
    end

    test "returns error when embedded resource is requested as simple atom" do
      error = first_error(refuse(["metadata"]))
      assert error["type"] == "requires_field_selection"
    end

    test "returns error when primitive calculation with arguments includes fields parameter" do
      error =
        first_error(
          refuse([
            %{
              "metadata" => [
                %{
                  "adjustedPriority" => %{
                    "args" => %{"urgencyMultiplier" => 1.5, "deadlineFactor" => true},
                    "fields" => []
                  }
                }
              ]
            }
          ])
        )

      assert error["type"] == "invalid_field_selection"
    end
  end

  describe "create actions with embedded resources" do
    test "processes embedded resource fields correctly in create actions" do
      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "input" => %{
              "title" => "Create Todo with Metadata",
              "userId" => RpcFixtures.user_id(),
              "metadata" => %{"category" => "personal", "priorityScore" => 75}
            },
            "fields" => ["id", "title", %{"metadata" => ["category", "priorityScore"]}]
          },
          todo(
            title: "Create Todo with Metadata",
            metadata: meta(category: "personal", priority_score: 75)
          )
        )

      assert result["success"] == true
      created = result["data"]
      assert created["title"] == "Create Todo with Metadata"
      assert created["metadata"]["category"] == "personal"
      assert created["metadata"]["priorityScore"] == 75
    end

    test "processes union embedded resources in create actions" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "create_todo",
                 "input" => %{
                   "title" => "Create Todo with Text Content",
                   "userId" => RpcFixtures.user_id(),
                   "content" => %{
                     "text" => %{"text" => "Created text content", "formatting" => "plain"}
                   }
                 },
                 "fields" => ["id", %{"content" => %{"text" => ["text", "formatting"]}}]
               })

      assert %{
               content: %{content_type: "text", text: "Created text content", formatting: "plain"}
             } =
               request.input

      request.input

      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "fields" => ["id", %{"content" => %{"text" => ["text", "formatting"]}}]
          },
          todo(
            content:
              union(
                :text,
                struct(TodoContent.TextContent, text: "Created text content", formatting: :plain)
              )
          )
        )

      assert result["success"] == true
      content = result["data"]["content"]
      assert content["text"]["text"] == "Created text content"
      assert content["text"]["formatting"] == "plain"
      refute Map.has_key?(content, "checklist")
      refute Map.has_key?(content, "link")
    end
  end

  describe "update actions with embedded resources" do
    test "processes embedded resource fields correctly in update actions" do
      result =
        Rpc.run(
          %{
            "action" => "update_todo",
            "identity" => RpcFixtures.todo_id(),
            "input" => %{
              "title" => "Updated Todo",
              "metadata" => %{"category" => "work", "priorityScore" => 85, "isUrgent" => true}
            },
            "fields" => [
              "id",
              "title",
              %{"metadata" => ["category", "priorityScore", "isUrgent"]}
            ]
          },
          todo(title: "Updated Todo", metadata: meta())
        )

      assert result["success"] == true
      updated = result["data"]
      assert updated["id"] == RpcFixtures.todo_id()
      assert updated["title"] == "Updated Todo"
      assert updated["metadata"]["category"] == "work"
      assert updated["metadata"]["priorityScore"] == 85
      assert updated["metadata"]["isUrgent"] == true
    end
  end
end
