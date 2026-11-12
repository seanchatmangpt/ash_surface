Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.CalculationFieldFormattingTest do
  @moduledoc """
  Adapted from ash_typescript `calculation_field_formatting_test.exs`. Same adaptation as the
  aggregate sibling: `.ts` text assertions become `FieldName` spelling over the real calculation
  and calculation-argument names, plus real node+zod acceptance of calculations in the generated
  filter/sort schemas and of calculation arguments in the calculation schema. Artifact keys
  following the formatter is a registered gap (`formatter_artifact_gap_test.exs`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Config, FieldName}
  alias AshSurface.Ported.{T1, Todo, TodoMetadata, TodoContent}

  @todo_calcs [:is_overdue, :days_until_due, :self]
  @meta_calcs [:display_category, :adjusted_priority, :is_overdue, :formatted_summary]
  @arg_names [:urgency_multiplier, :deadline_factor, :user_bias, :include_metadata]

  defp calc_names(resource), do: T1.public_names(resource).calculations

  defp arg_names do
    for c <- Ash.Resource.Info.public_calculations(TodoMetadata),
        a <- c.arguments,
        do: a.name
  end

  test "fixture declares the calculations and arguments under test" do
    for c <- @todo_calcs, do: assert(c in calc_names(Todo))
    for c <- @meta_calcs, do: assert(c in calc_names(TodoMetadata))
    assert :display_text in calc_names(TodoContent.TextContent)
    assert :is_formatted in calc_names(TodoContent.TextContent)
    assert :display_title in calc_names(TodoContent.LinkContent)
    assert :is_accessible in calc_names(TodoContent.LinkContent)
    for a <- [:urgency_multiplier, :user_bias, :include_metadata], do: assert(a in arg_names())
  end

  describe "calculation field formatting with configured formatters" do
    test "PascalCase calculation names under :pascal_case" do
      T1.with_env(:output_field_formatter, :pascal_case, fn ->
        f = Config.output_field_formatter()

        expected = %{
          is_overdue: "IsOverdue",
          days_until_due: "DaysUntilDue",
          self: "Self",
          display_category: "DisplayCategory",
          adjusted_priority: "AdjustedPriority",
          formatted_summary: "FormattedSummary",
          display_text: "DisplayText",
          is_formatted: "IsFormatted",
          display_title: "DisplayTitle",
          is_accessible: "IsAccessible"
        }

        for {atom, name} <- expected do
          assert FieldName.format(atom, f) == name
          refute FieldName.format(atom, f) == FieldName.format(atom, :camel_case)
        end
      end)
    end

    test "snake_case calculation names under :snake_case" do
      T1.with_env(:output_field_formatter, :snake_case, fn ->
        f = Config.output_field_formatter()

        for atom <-
              @todo_calcs ++
                [
                  :display_category,
                  :adjusted_priority,
                  :formatted_summary,
                  :display_text,
                  :is_formatted,
                  :display_title,
                  :is_accessible
                ] do
          assert FieldName.format(atom, f) == Atom.to_string(atom)

          refute FieldName.format(atom, f) == FieldName.format(atom, :camel_case) and
                   String.contains?(Atom.to_string(atom), "_")
        end
      end)
    end

    test "calculation argument names use the configured formatter" do
      assert Enum.map(@arg_names, &FieldName.format(&1, :pascal_case)) ==
               ["UrgencyMultiplier", "DeadlineFactor", "UserBias", "IncludeMetadata"]

      for a <- @arg_names, do: refute(FieldName.format(a, :pascal_case) =~ "_")
    end

    test "calculation return-type names (self) follow the formatter" do
      assert FieldName.format(:self, :pascal_case) == "Self"
      assert FieldName.format(:self, :camel_case) == "self"
    end

    test "calculations work in the generated read schemas (real zod)" do
      assert [true, true, true, false, false] ==
               T1.node_accepts([
                 {"Todo_read_filter_schema", %{field: "is_overdue", op: "eq", value: true}},
                 {"Todo_read_filter_schema", %{field: "days_until_due", op: "lt", value: 3}},
                 {"Todo_read_sort_schema", "-filtered_data"},
                 {"Todo_read_filter_schema", %{field: "IsOverdue", op: "eq", value: true}},
                 {"Todo_read_filter_schema", %{field: "is_overdue", op: "eq", value: "yes"}}
               ])
    end

    test "regression: no hardcoded camelCase / PascalCase when snake_case configured" do
      T1.with_env(:output_field_formatter, :snake_case, fn ->
        f = Config.output_field_formatter()

        for {atom, camel, pascal} <- [
              {:is_overdue, "isOverdue", "IsOverdue"},
              {:days_until_due, "daysUntilDue", "DaysUntilDue"},
              {:display_category, "displayCategory", "DisplayCategory"},
              {:adjusted_priority, "adjustedPriority", "AdjustedPriority"},
              {:urgency_multiplier, "urgencyMultiplier", "UrgencyMultiplier"},
              {:deadline_factor, "deadlineFactor", "DeadlineFactor"},
              {:user_bias, "userBias", "UserBias"},
              {:include_metadata, "includeMetadata", "IncludeMetadata"}
            ] do
          assert FieldName.format(atom, f) == Atom.to_string(atom)
          refute FieldName.format(atom, f) in [camel, pascal]
        end
      end)
    end
  end
end
