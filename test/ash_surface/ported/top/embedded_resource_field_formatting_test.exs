Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.EmbeddedResourceFieldFormattingTest do
  @moduledoc """
  Adapted from ash_typescript `embedded_resource_field_formatting_test.exs`. `.ts` text assertions
  become `FieldName` spelling over the real embedded-resource attribute/calculation names plus real
  node+zod acceptance of embedded objects in the generated create schema (strict embedded objects
  reject a non-Ash key spelling). Artifact keys following the formatter is a registered gap
  (`formatter_artifact_gap_test.exs`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Config, FieldName}
  alias AshSurface.Ported.{T1, TodoContent, TodoMetadata}

  @metadata_attrs ~w(priority_score external_reference estimated_hours is_urgent created_at
                     custom_fields creator_id project_id reminder_time)a
  @text_attrs ~w(word_count content_type)a
  @link_attrs ~w(preview_image_url is_external last_checked_at)a

  @pascal %{
    priority_score: "PriorityScore",
    external_reference: "ExternalReference",
    estimated_hours: "EstimatedHours",
    is_urgent: "IsUrgent",
    created_at: "CreatedAt",
    custom_fields: "CustomFields",
    creator_id: "CreatorId",
    project_id: "ProjectId",
    reminder_time: "ReminderTime",
    word_count: "WordCount",
    content_type: "ContentType",
    preview_image_url: "PreviewImageUrl",
    is_external: "IsExternal",
    last_checked_at: "LastCheckedAt"
  }

  test "fixture embedded resources declare the attributes under test" do
    assert @metadata_attrs -- T1.public_names(TodoMetadata).attributes == []
    assert @text_attrs -- T1.public_names(TodoContent.TextContent).attributes == []
    assert @link_attrs -- T1.public_names(TodoContent.LinkContent).attributes == []
  end

  describe "embedded resource field formatting with configured formatters" do
    test "PascalCase embedded attribute names under :pascal_case" do
      T1.with_env(:output_field_formatter, :pascal_case, fn ->
        f = Config.output_field_formatter()

        for {atom, name} <- @pascal do
          assert FieldName.format(atom, f) == name
          refute FieldName.format(atom, f) == FieldName.format(atom, :camel_case)
        end
      end)
    end

    test "snake_case embedded attribute names under :snake_case" do
      T1.with_env(:output_field_formatter, :snake_case, fn ->
        f = Config.output_field_formatter()

        for {atom, _} <- @pascal do
          assert FieldName.format(atom, f) == Atom.to_string(atom)

          refute FieldName.format(atom, f) in [FieldName.format(atom, :camel_case) | []] and
                   String.contains?(Atom.to_string(atom), "_")
        end
      end)
    end

    test "embedded calculation names use the configured formatter" do
      calcs = T1.public_names(TodoMetadata).calculations

      for c <- [:display_category, :adjusted_priority, :is_overdue, :formatted_summary],
          do: assert(c in calcs)

      assert Enum.map(
               [:display_category, :adjusted_priority, :is_overdue, :formatted_summary],
               &FieldName.format(&1, :pascal_case)
             ) == ["DisplayCategory", "AdjustedPriority", "IsOverdue", "FormattedSummary"]

      assert Enum.map(
               [:display_text, :is_formatted, :display_title, :is_accessible],
               &FieldName.format(&1, :pascal_case)
             ) == ["DisplayText", "IsFormatted", "DisplayTitle", "IsAccessible"]
    end

    test "embedded fields appear in input and output schemas (real zod, strict embedded object)" do
      art = T1.artifact!()
      # priority_score is spelled once per input schema that embeds TodoMetadata (>1 occurrences)
      assert length(String.split(art, "priority_score:")) > 2

      base = %{
        title: "t",
        user_id: "7b0a1b0e-0000-4000-8000-000000000000",
        metadata: %{category: "c", priority_score: 3}
      }

      assert [true, false] ==
               T1.node_accepts([
                 {"Todo_create_schema", base},
                 {"Todo_create_schema", put_in(base, [:metadata, :priorityScore], 3)}
               ])
    end

    test "regression: formatter-driven spelling, never hardcoded camelCase" do
      for {f, expected} <- [
            {:snake_case, "priority_score"},
            {:camel_case, "priorityScore"},
            {:pascal_case, "PriorityScore"}
          ] do
        T1.with_env(:output_field_formatter, f, fn ->
          assert FieldName.format(:priority_score, Config.output_field_formatter()) == expected

          assert FieldName.format(:external_reference, Config.output_field_formatter()) ==
                   FieldName.compute(:external_reference, f)
        end)
      end
    end
  end
end
