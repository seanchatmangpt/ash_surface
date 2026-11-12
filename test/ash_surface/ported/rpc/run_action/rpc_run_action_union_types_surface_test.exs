defmodule AshSurface.Ported.RpcRunActionUnionTypesSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_union_types_test.exs`. Union attributes
  (content / attachments / statusInfo) are carried as real `%Ash.Union{}` values on hand-built
  `Todo` structs (calculations of embedded members are set as loaded values) and shaped by the
  result processor; union input and field-selection refusals are asserted at request-parse.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  alias AshSurface.Ported.TodoContent.{ChecklistContent, LinkContent, TextContent}
  import RpcFixtures, only: [todo: 1, user: 1]

  @id_prefix "22222222-2222-2222-2222-2222222222"

  defp tid(n), do: @id_prefix <> String.pad_leading(Integer.to_string(n), 2, "0")
  defp union(type, value), do: %Ash.Union{type: type, value: value}

  defp text_member(attrs \\ []),
    do:
      union(
        :text,
        struct(
          TextContent,
          Keyword.merge(
            [
              id: "77777777-0000-0000-0000-000000000001",
              text: "Sample text content",
              formatting: :markdown,
              word_count: 3,
              display_text: "Sample text content",
              is_formatted: true
            ],
            attrs
          )
        )
      )

  defp checklist_member,
    do:
      union(
        :checklist,
        struct(ChecklistContent,
          id: "77777777-0000-0000-0000-000000000002",
          title: "Shopping List",
          items: [
            %{text: "Milk", completed: false},
            %{text: "Bread", completed: false},
            %{text: "Eggs", completed: false}
          ],
          allow_reordering: true,
          total_items: 3,
          completed_count: 0,
          progress_percentage: 0.0
        )
      )

  defp link_member,
    do:
      union(
        :link,
        struct(LinkContent,
          id: "77777777-0000-0000-0000-000000000003",
          url: "https://example.com",
          title: "Example Site",
          description: "A sample website",
          is_external: true,
          display_title: "Example Site",
          domain: "example.com"
        )
      )

  defp file_att,
    do: union(:file, %{filename: "document.pdf", size: 1024, mime_type: "application/pdf"})

  defp image_att,
    do: union(:image, %{filename: "photo.jpg", width: 800, height: 600, alt_text: "A photo"})

  defp url_att, do: union(:url, "https://example.com/resource")

  defp list(todos, fields),
    do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos)

  defp with_key(result, field, key) do
    Enum.find(result["data"], fn t ->
      is_map(t[field]) and Map.has_key?(t[field], key)
    end)
  end

  defp one_member?(map, keys), do: Enum.count(keys, &Map.has_key?(map, &1)) == 1

  defp content_todos do
    [
      todo(id: tid(1), title: "Text Todo", content: text_member()),
      todo(id: tid(2), title: "Checklist Todo", content: checklist_member()),
      todo(id: tid(3), title: "Link Todo", content: link_member())
    ]
  end

  describe "content union type - embedded resource members" do
    test "processes TextContent union member with field selection" do
      result =
        list(content_todos(), [
          "id",
          "title",
          %{"content" => [%{"text" => ["id", "text", "formatting", "wordCount"]}]}
        ])

      assert result["success"] == true
      t = with_key(result, "content", "text")
      assert t != nil
      content = t["content"]
      text_content = content["text"]

      for k <- ["id", "text", "formatting", "wordCount"],
          do: assert(Map.has_key?(text_content, k))

      assert text_content["text"] == "Sample text content"
      assert text_content["wordCount"] == 3
      refute Map.has_key?(content, "checklist")
      refute Map.has_key?(content, "link")
    end

    test "processes ChecklistContent union member with field selection" do
      result =
        list(content_todos(), [
          "id",
          %{
            "content" => [
              %{
                "checklist" => [
                  "id",
                  "title",
                  %{"items" => ["text", "completed"]},
                  "allow_reordering"
                ]
              }
            ]
          }
        ])

      assert result["success"] == true
      t = with_key(result, "content", "checklist")
      assert t != nil
      content = t["content"]
      checklist = content["checklist"]
      for k <- ["id", "title", "items", "allowReordering"], do: assert(Map.has_key?(checklist, k))
      assert length(checklist["items"]) == 3
      assert hd(checklist["items"]) == %{"text" => "Milk", "completed" => false}
      refute Map.has_key?(content, "text")
      refute Map.has_key?(content, "link")
    end

    test "processes LinkContent union member with field selection and calculations" do
      result =
        list(content_todos(), [
          "id",
          %{
            "content" => [
              %{
                "link" => [
                  "id",
                  "url",
                  "title",
                  "description",
                  "isExternal",
                  "displayTitle",
                  "domain"
                ]
              }
            ]
          }
        ])

      assert result["success"] == true
      t = with_key(result, "content", "link")
      assert t != nil
      content = t["content"]
      link = content["link"]

      for k <- ["id", "url", "title", "description", "isExternal", "displayTitle", "domain"],
          do: assert(Map.has_key?(link, k))

      assert link["domain"] == "example.com"
      assert link["displayTitle"] == "Example Site"
      refute Map.has_key?(content, "text")
      refute Map.has_key?(content, "checklist")
    end

    test "processes multiple embedded resource union members in single map" do
      result =
        list(content_todos(), [
          "id",
          %{
            "content" => [
              %{
                "text" => ["id", "text", "formatting"],
                "checklist" => ["id", "title", %{"items" => ["text", "completed"]}],
                "link" => ["id", "url", "title"]
              }
            ]
          }
        ])

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        content = t["content"]
        assert one_member?(content, ["text", "checklist", "link"])

        cond do
          Map.has_key?(content, "text") ->
            for k <- ["id", "text", "formatting"], do: assert(Map.has_key?(content["text"], k))

          Map.has_key?(content, "checklist") ->
            for k <- ["id", "title", "items"], do: assert(Map.has_key?(content["checklist"], k))

          true ->
            for k <- ["id", "url", "title"], do: assert(Map.has_key?(content["link"], k))
        end
      end)
    end

    test "processes multiple embedded resource union members in separate maps" do
      result =
        list(content_todos(), [
          "id",
          %{
            "content" => [
              %{"text" => ["id", "text", "formatting"]},
              %{"link" => ["id", "url", "title"]},
              %{"checklist" => ["id", "title", %{"items" => ["text", "completed"]}]}
            ]
          }
        ])

      assert result["success"] == true
      assert length(result["data"]) == 3

      Enum.each(
        result["data"],
        &assert(one_member?(&1["content"], ["text", "checklist", "link"]))
      )
    end
  end

  describe "content union type - simple members" do
    defp simple_todos do
      [
        todo(id: tid(4), title: "Note Todo", content: union(:note, "Simple note content")),
        todo(id: tid(5), title: "Priority Todo", content: union(:priority_value, 5))
      ]
    end

    test "processes note (string) union member" do
      result = list(simple_todos(), ["id", "title", %{"content" => ["note"]}])
      assert result["success"] == true
      t = with_key(result, "content", "note")
      assert t != nil
      content = t["content"]
      assert is_binary(content["note"])
      assert content["note"] == "Simple note content"
      refute Map.has_key?(content, "priorityValue")
      refute Map.has_key?(content, "text")
    end

    test "processes priorityValue (integer) union member" do
      result = list(simple_todos(), ["id", %{"content" => ["priorityValue"]}])
      assert result["success"] == true
      t = with_key(result, "content", "priorityValue")
      assert t != nil
      content = t["content"]
      assert is_integer(content["priorityValue"])
      assert content["priorityValue"] == 5
      refute Map.has_key?(content, "note")
      refute Map.has_key?(content, "text")
    end

    test "processes mixed simple and embedded resource union members" do
      result =
        list(simple_todos() ++ content_todos(), [
          "id",
          %{
            "content" => [
              "note",
              "priorityValue",
              %{"text" => ["id", "text", "formatting"]}
            ]
          }
        ])

      assert result["success"] == true
      with_content = Enum.filter(result["data"], & &1["content"])
      assert with_content != []

      Enum.each(
        Enum.filter(
          with_content,
          &(&1["title"] != "Checklist Todo" and &1["title"] != "Link Todo")
        ),
        fn t ->
          assert one_member?(t["content"], ["note", "priorityValue", "text"])
        end
      )
    end

    test "processes mixed simple and complex union members in single map" do
      result =
        list(simple_todos() ++ content_todos(), [
          "id",
          %{
            "content" => [
              "note",
              %{
                "text" => ["id", "text", "formatting", "displayText"],
                "checklist" => ["id", "title", "totalItems"]
              }
            ]
          }
        ])

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        c = t["content"]

        if c do
          count = Enum.count([c["note"], c["text"], c["checklist"]], &(&1 != nil))
          assert count <= 1
        end
      end)

      assert Enum.any?(
               result["data"],
               &(&1["content"]["text"]["displayText"] == "Sample text content")
             )

      assert Enum.any?(result["data"], &(&1["content"]["checklist"]["totalItems"] == 3))
    end
  end

  describe "attachments array union type" do
    defp attachment_todos do
      [
        todo(id: tid(6), title: "File Todo", attachments: [file_att()]),
        todo(id: tid(7), title: "Image Todo", attachments: [image_att()]),
        todo(id: tid(8), title: "URL Todo", attachments: [url_att()])
      ]
    end

    defp find_attachment(result, key) do
      result["data"]
      |> Enum.flat_map(&(&1["attachments"] || []))
      |> Enum.find(&Map.has_key?(&1, key))
    end

    test "processes file attachment union member with field selection" do
      result =
        list(attachment_todos(), [
          "id",
          %{"attachments" => [%{"file" => ["filename", "size", "mime_type"]}]}
        ])

      assert result["success"] == true
      file = find_attachment(result, "file")
      assert file != nil
      file_data = file["file"]
      for k <- ["filename", "size", "mimeType"], do: assert(Map.has_key?(file_data, k))
      assert file_data["filename"] == "document.pdf"
      assert file_data["mimeType"] == "application/pdf"
    end

    test "processes image attachment union member with field selection" do
      result =
        list(attachment_todos(), [
          "id",
          %{"attachments" => [%{"image" => ["filename", "width", "height", "alt_text"]}]}
        ])

      assert result["success"] == true
      image = find_attachment(result, "image")
      assert image != nil

      for k <- ["filename", "width", "height", "altText"],
          do: assert(Map.has_key?(image["image"], k))

      assert image["image"]["altText"] == "A photo"
    end

    test "processes url attachment union member (simple type)" do
      result = list(attachment_todos(), ["id", %{"attachments" => ["url"]}])
      assert result["success"] == true
      url = find_attachment(result, "url")
      assert url != nil
      assert is_binary(url["url"])
      assert url["url"] == "https://example.com/resource"
    end

    test "processes mixed attachment union members in separate maps" do
      result =
        list(attachment_todos(), [
          "id",
          %{
            "attachments" => [
              %{"file" => ["filename", "size", "mime_type"]},
              %{"image" => ["filename", "width", "height"]},
              "url"
            ]
          }
        ])

      assert result["success"] == true
      with_att = Enum.filter(result["data"], &(&1["attachments"] not in [nil, []]))
      assert with_att != []

      Enum.each(with_att, fn t ->
        Enum.each(t["attachments"], &assert(one_member?(&1, ["file", "image", "url"])))
      end)
    end

    test "processes mixed attachment union members in single map" do
      result =
        list(attachment_todos(), [
          "id",
          %{
            "attachments" => [
              "url",
              %{
                "file" => ["filename", "size", "mime_type"],
                "image" => ["filename", "width", "height"]
              }
            ]
          }
        ])

      assert result["success"] == true
      with_att = Enum.filter(result["data"], &(&1["attachments"] not in [nil, []]))
      assert length(with_att) == 3

      Enum.each(with_att, fn t ->
        Enum.each(t["attachments"], &assert(one_member?(&1, ["file", "image", "url"])))
      end)
    end
  end

  describe "status_info union type - map_with_tag storage" do
    defp status_todos do
      [
        todo(
          id: tid(9),
          title: "Simple Status Todo",
          status_info: union(:simple, %{value: "In Progress"})
        ),
        todo(
          id: tid(10),
          title: "Detailed Status Todo",
          status_info: union(:detailed, %{value: "Detailed status information"})
        ),
        todo(
          id: tid(11),
          title: "Automated Status Todo",
          status_info: union(:automated, %{value: "Automatically managed"})
        )
      ]
    end

    for {member, others} <- [
          {"simple", ["detailed", "automated"]},
          {"detailed", ["simple", "automated"]},
          {"automated", ["simple", "detailed"]}
        ] do
      test "processes #{member} statusInfo union member" do
        result = list(status_todos(), ["id", %{"statusInfo" => [unquote(member)]}])
        assert result["success"] == true
        t = with_key(result, "statusInfo", unquote(member))
        assert t != nil
        status_info = t["statusInfo"]
        assert Map.has_key?(status_info, unquote(member))
        for o <- unquote(others), do: refute(Map.has_key?(status_info, o))
      end
    end

    test "processes multiple statusInfo union members" do
      result =
        list(status_todos(), ["id", %{"statusInfo" => ["simple", "detailed", "automated"]}])

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert one_member?(t["statusInfo"], ["simple", "detailed", "automated"])
      end)
    end
  end

  describe "mixed union types with other field types" do
    defp complex_todo do
      u = user(name: "Mixed Test User", email: "mixed@example.com")

      todo(
        id: tid(12),
        title: "Complex Todo",
        user: u,
        completed: false,
        content: text_member(text: "Complex content"),
        custom_data: %{"customField1" => "value1", "custom_field2" => "value2"},
        attachments: [file_att(), union(:url, "https://example.com")],
        status_info: union(:detailed, %{value: "x"}),
        is_overdue: false,
        comment_count: 0
      )
    end

    test "processes union types with attributes and relationships" do
      u = complex_todo().user

      result =
        list([%{complex_todo() | user: %{u | todos: [complex_todo()]}}], [
          "id",
          "title",
          "completed",
          %{"user" => ["id", "name", %{"todos" => ["customData"]}]},
          %{"content" => ["note", %{"text" => ["id", "text", "formatting"]}]},
          %{"attachments" => [%{"file" => ["filename", "size"]}, "url"]}
        ])

      assert result["success"] == true
      t = Enum.find(result["data"], &(&1["title"] == "Complex Todo"))
      assert t != nil

      for k <- ["id", "title", "completed", "user", "content", "attachments"],
          do: assert(Map.has_key?(t, k))

      assert Map.has_key?(t["user"], "id")
      assert t["user"]["name"] == "Mixed Test User"

      assert t["user"]["todos"] |> hd() |> Map.get("customData") ==
               %{"customField1" => "value1", "custom_field2" => "value2"}

      assert t["content"]["text"]["text"] == "Complex content"
      assert length(t["attachments"]) == 2
      assert hd(t["attachments"])["file"] == %{"filename" => "document.pdf", "size" => 1024}
    end

    test "processes union types with calculations and aggregates" do
      result =
        list([complex_todo()], [
          "id",
          "isOverdue",
          "commentCount",
          %{"content" => [%{"text" => ["id", "text", "wordCount"]}]},
          %{"statusInfo" => ["detailed"]}
        ])

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert is_boolean(t["isOverdue"])
        assert is_integer(t["commentCount"])
        assert one_member?(t["content"], ["text", "checklist", "link"])
        assert Map.has_key?(t["statusInfo"], "detailed")
      end)
    end

    test "processes all union types together" do
      result =
        list([complex_todo()], [
          "id",
          %{"content" => ["note", %{"text" => ["id", "text"]}]},
          %{
            "attachments" => [
              %{"file" => ["filename", "size"]},
              %{"image" => ["filename", "width"]},
              "url"
            ]
          },
          %{"statusInfo" => ["simple", "detailed"]}
        ])

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert one_member?(t["content"], ["note", "text"])
        assert is_list(t["attachments"])
        Enum.each(t["attachments"], &assert(one_member?(&1, ["file", "image", "url"])))
        assert one_member?(t["statusInfo"], ["simple", "detailed"])
      end)
    end
  end

  describe "union type validation and error handling" do
    @uid "11111111-1111-1111-1111-111111111111"

    defp create_error(content_key, value) do
      Rpc.error(%{
        "action" => "create_todo",
        "input" => %{"title" => "Invalid", "userId" => @uid, content_key => value},
        "fields" => ["id"]
      })
    end

    defp first_error(result) do
      assert result["success"] == false
      assert is_list(result["errors"])
      hd(result["errors"])
    end

    defp fields_error(fields),
      do: first_error(Rpc.error(%{"action" => "list_todos", "fields" => fields}))

    test "returns error for non-map union input" do
      error = first_error(create_error("content", "direct string value not wrapped"))
      assert error["type"] == "invalid_union_input"
      assert error["message"] =~ "must be a map"
    end

    test "returns error for empty union input map" do
      error = first_error(create_error("content", %{}))
      assert error["type"] == "invalid_union_input"
      assert error["message"] =~ "does not contain any valid member key"
      assert is_list(error["details"]["expectedMembers"])
    end

    test "returns error for multiple union member keys" do
      error = first_error(create_error("content", %{"note" => "some note", "priorityValue" => 5}))
      assert error["type"] == "invalid_union_input"
      assert error["message"] == "Union input map contains multiple member keys: %{foundKeys}"
      assert error["shortMessage"] == "Invalid union input"
      assert is_binary(error["vars"]["foundKeys"])
      assert String.contains?(error["vars"]["foundKeys"], "note")
      assert String.contains?(error["vars"]["foundKeys"], "priorityValue")
    end

    test "returns error for invalid union member key" do
      error = first_error(create_error("content", %{"invalidMember" => "value"}))
      assert error["type"] == "invalid_union_input"
      assert error["message"] =~ "does not contain any valid member key"
    end

    test "returns error for invalid union member in attachment" do
      error = first_error(create_error("attachments", [%{"invalidType" => "value"}]))
      assert error["type"] == "invalid_union_input"
    end

    test "returns error for invalid union member" do
      error = fields_error([%{"content" => ["invalidMember"]}])
      assert error["type"] == "unknown_union_field"
      assert List.first(error["fields"]) == "content.invalidMember"
    end

    test "returns error for invalid field in embedded resource union member" do
      error = fields_error([%{"content" => [%{"text" => ["id", "invalidField"]}]}])
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "content.text.invalidField"
    end

    test "returns error for invalid field in map union member with field constraints" do
      error = fields_error([%{"attachments" => [%{"file" => ["filename", "invalidField"]}]}])
      assert error["type"] == "unknown_map_field"
      assert List.first(error["fields"]) == "attachments.file.invalidField"
    end

    test "returns error for invalid union member in attachments array" do
      error = fields_error([%{"attachments" => ["invalidAttachmentType"]}])
      assert error["type"] == "unknown_union_field"
      assert List.first(error["fields"]) == "attachments.invalidAttachmentType"
    end

    test "returns error for invalid union member in statusInfo" do
      error = fields_error([%{"statusInfo" => ["invalidStatus"]}])
      assert error["type"] == "unknown_union_field"
      assert List.first(error["fields"]) == "statusInfo.invalidStatus"
    end

    test "returns error for empty union field selection" do
      error = fields_error([%{"content" => []}])
      assert error["type"] in ["requires_field_selection", "invalid_field_format"]
    end

    test "returns error for union attribute requested as simple atom" do
      error = fields_error(["content"])
      assert error["type"] in ["requires_field_selection", "invalid_field_format"]
    end

    test "returns error for file attachment requested as simple atom (requires field selection)" do
      error = fields_error([%{"attachments" => ["file"]}])
      assert error["type"] in ["requires_field_selection", "invalid_field_format"]
    end

    test "returns error for image attachment requested as simple atom (requires field selection)" do
      error = fields_error([%{"attachments" => ["image"]}])
      assert error["type"] in ["requires_field_selection", "invalid_field_format"]
    end
  end

  describe "complex union field selection scenarios" do
    test "processes nested calculations within embedded resource union members" do
      t = todo(id: tid(13), title: "Complex Calculations Todo", content: text_member())

      result =
        list([t], [
          "id",
          %{
            "content" => [
              %{"text" => ["id", "text", "formatting", "displayText", "isFormatted"]}
            ]
          }
        ])

      assert result["success"] == true
      text = hd(result["data"])["content"]["text"]
      for k <- ["id", "text", "formatting"], do: assert(Map.has_key?(text, k))
      assert is_binary(text["displayText"])
      assert is_boolean(text["isFormatted"])
    end

    test "processes union field selection with deep nesting" do
      t = todo(id: tid(14), title: "Deep Checklist Todo", content: checklist_member())

      result =
        list([t], [
          "id",
          %{
            "content" => [
              %{
                "checklist" => [
                  "id",
                  "title",
                  %{"items" => ["text", "completed"]},
                  "totalItems",
                  "completedCount",
                  "progressPercentage"
                ]
              }
            ]
          }
        ])

      assert result["success"] == true
      checklist = hd(result["data"])["content"]["checklist"]
      for k <- ["id", "title", "items"], do: assert(Map.has_key?(checklist, k))
      assert is_integer(checklist["totalItems"])
      assert is_integer(checklist["completedCount"])
      assert is_number(checklist["progressPercentage"])
    end

    test "handles union members with no field selection needed (simple types only)" do
      result =
        list(
          simple_todos() ++ attachment_todos() ++ status_todos(),
          [
            "id",
            %{"content" => ["note", "priorityValue"]},
            %{"attachments" => ["url"]},
            %{"statusInfo" => ["simple", "detailed", "automated"]}
          ]
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")

        if t["content"] do
          assert Enum.count(["note", "priorityValue"], &Map.has_key?(t["content"], &1)) <= 1
          for k <- ["text", "checklist", "link"], do: refute(Map.has_key?(t["content"], k))
        end

        Enum.each(t["attachments"] || [], fn a ->
          if Map.has_key?(a, "url") do
            assert is_binary(a["url"])
            refute Map.has_key?(a, "file")
            refute Map.has_key?(a, "image")
          end
        end)

        if t["statusInfo"] do
          assert one_member?(t["statusInfo"], ["simple", "detailed", "automated"])
        end
      end)
    end
  end

  describe "union type edge cases" do
    test "handles single union member selection" do
      t = todo(id: tid(15), title: "Edge Case Todo", content: text_member())

      result =
        list([t], ["id", "title", %{"content" => [%{"text" => ["id", "text"]}]}])

      assert result["success"] == true
      content = hd(result["data"])["content"]
      assert Map.has_key?(content, "text")
      for k <- ["id", "text"], do: assert(Map.has_key?(content["text"], k))
      refute Map.has_key?(content, "checklist")
      refute Map.has_key?(content, "link")
    end

    test "handles union member with minimal field selection" do
      t = todo(id: tid(15), title: "Edge Case Todo", content: text_member())
      result = list([t], ["id", "title", %{"content" => [%{"text" => ["id"]}]}])
      assert result["success"] == true
      text = hd(result["data"])["content"]["text"]
      assert Map.has_key?(text, "id")
      refute Map.has_key?(text, "text")
      refute Map.has_key?(text, "formatting")
    end

    test "processes union attribute with only simple members" do
      t = todo(id: tid(16), title: "Simple Note Todo", content: union(:note, "Just a note"))
      result = list([t], ["id", %{"content" => ["note", "priorityValue"]}])
      assert result["success"] == true
      content = hd(result["data"])["content"]
      assert is_binary(content["note"])
      refute Map.has_key?(content, "text")
      refute Map.has_key?(content, "checklist")
      refute Map.has_key?(content, "link")
    end

    test "processes map union member with field selection" do
      t = todo(id: tid(17), title: "File Todo", attachments: [file_att()])

      result =
        list([t], ["id", %{"attachments" => [%{"file" => ["filename", "size", "mime_type"]}]}])

      assert result["success"] == true
      file = hd(hd(result["data"])["attachments"])["file"]
      for k <- ["filename", "size", "mimeType"], do: assert(Map.has_key?(file, k))
    end
  end
end
