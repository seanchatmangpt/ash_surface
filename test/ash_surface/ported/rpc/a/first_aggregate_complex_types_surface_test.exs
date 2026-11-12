defmodule AshSurface.Ported.Rpc.A.FirstAggregateComplexTypesSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `first_aggregate_complex_types_test.exs`. The `first`
  aggregates (`firstCommentMetadata`: embedded resource, `firstCommentAuthorInfo`: union) are
  carried as loaded values on a hand-built `Todo`, exactly as the data layer would return
  them; field selection through them is performed by the result processor.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures, TodoMetadata}

  defp metadata,
    do:
      struct(TodoMetadata,
        id: "55555555-5555-5555-5555-555555555555",
        category: "test",
        priority_score: 75,
        is_urgent: true,
        tags: ["x"],
        internal_notes: "secret"
      )

  defp author_info_union,
    do: %Ash.Union{
      type: :metadata,
      value:
        struct(TodoMetadata,
          id: "55555555-5555-5555-5555-555555555556",
          category: "author-metadata",
          priority_score: 50,
          is_urgent: false
        )
    }

  defp loaded_todo(attrs \\ []),
    do:
      RpcFixtures.todo(
        [
          title: "Aggregate Test Todo",
          first_comment_metadata: metadata(),
          first_comment_author_info: author_info_union()
        ] ++ attrs
      )

  defp get(fields, record),
    do: Rpc.run(%{"action" => "get_single_todo", "fields" => fields}, record)

  describe "first aggregates returning complex types" do
    test "can load first aggregate returning embedded resource type" do
      result =
        get(
          [
            "id",
            "title",
            %{"firstCommentMetadata" => ["category", "priorityScore", "isUrgent"]}
          ],
          loaded_todo()
        )

      assert result["success"] == true
      assert Map.has_key?(result["data"], "firstCommentMetadata")
      metadata = result["data"]["firstCommentMetadata"]

      assert metadata != nil
      assert metadata["category"] == "test"
      assert metadata["priorityScore"] == 75
      assert metadata["isUrgent"] == true
      refute Map.has_key?(metadata, "tags")
      refute Map.has_key?(metadata, "internalNotes")
    end

    test "can load first aggregate returning union type" do
      result =
        get(
          [
            "id",
            "title",
            %{
              "firstCommentAuthorInfo" => %{
                "metadata" => ["category", "priorityScore"],
                "anonymous" => []
              }
            }
          ],
          loaded_todo()
        )

      assert result["success"] == true
      assert Map.has_key?(result["data"], "firstCommentAuthorInfo")
      author_info = result["data"]["firstCommentAuthorInfo"]

      assert author_info != nil
      assert Map.has_key?(author_info, "metadata")

      metadata = author_info["metadata"]
      assert metadata["category"] == "author-metadata"
      assert metadata["priorityScore"] == 50
      refute Map.has_key?(metadata, "isUrgent")
    end

    test "can load both complex first aggregates together" do
      result =
        get(
          [
            "id",
            "title",
            %{"firstCommentMetadata" => ["category", "priorityScore", "isUrgent"]},
            %{
              "firstCommentAuthorInfo" => %{
                "metadata" => ["category", "priorityScore"],
                "anonymous" => []
              }
            }
          ],
          loaded_todo()
        )

      assert result["success"] == true
      data = result["data"]
      assert Map.has_key?(data, "firstCommentMetadata")
      assert Map.has_key?(data, "firstCommentAuthorInfo")

      assert data["firstCommentMetadata"]["category"] == "test"
      assert data["firstCommentAuthorInfo"]["metadata"]["category"] == "author-metadata"
    end

    test "refuses an unknown member field inside the first-aggregate selection" do
      result =
        Rpc.error(%{
          "action" => "get_single_todo",
          "fields" => ["id", %{"firstCommentMetadata" => ["category", "notAMetadataField"]}]
        })

      assert result["success"] == false
      assert [%{"type" => "unknown_field"} | _] = result["errors"]
    end
  end
end
