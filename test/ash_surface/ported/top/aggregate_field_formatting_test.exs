Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.AggregateFieldFormattingTest do
  @moduledoc """
  Adapted from ash_typescript `aggregate_field_formatting_test.exs`. The reference asserts the
  generated `.ts` text follows `:output_field_formatter`. ash_surface emits no `.ts`: the formatter
  is applied by `AshSurface.FieldName` (the wire-name boundary) and the generated Zod artifact
  carries the Ash aggregate names verbatim. Each reference test maps to the real aggregate
  names + `FieldName` spelling under the configured formatter, plus real node+zod acceptance of the
  aggregate fields in the generated filter/sort schemas. Artifact keys following the formatter is a
  registered gap (`formatter_artifact_gap_test.exs`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Config, FieldName}
  alias AshSurface.Ported.{T1, Todo}

  @aggregates [:comment_count, :helpful_comment_count]

  setup_all do
    %{names: T1.public_names(Todo)}
  end

  test "fixture really declares the aggregates under test", %{names: names} do
    for a <- @aggregates, do: assert(a in names.aggregates)
  end

  describe "aggregate field formatting with configured formatters" do
    test "PascalCase aggregate names under :pascal_case (reference: pascal_case key test)" do
      T1.with_env(:output_field_formatter, :pascal_case, fn ->
        f = Config.output_field_formatter()
        assert f == :pascal_case
        assert FieldName.format(:comment_count, f) == "CommentCount"
        assert FieldName.format(:helpful_comment_count, f) == "HelpfulCommentCount"
        refute FieldName.format(:comment_count, f) == "commentCount"
        refute FieldName.format(:helpful_comment_count, f) == "helpfulCommentCount"
      end)
    end

    test "snake_case aggregate names under :snake_case (reference: snake_case key test)" do
      T1.with_env(:output_field_formatter, :snake_case, fn ->
        f = Config.output_field_formatter()
        assert FieldName.format(:comment_count, f) == "comment_count"
        assert FieldName.format(:helpful_comment_count, f) == "helpful_comment_count"

        for bad <- ["commentCount", "CommentCount", "helpfulCommentCount", "HelpfulCommentCount"],
            a <- @aggregates do
          refute FieldName.format(a, f) == bad
        end
      end)
    end

    test "aggregate fields work in generated filter types (real zod)" do
      assert [true, false, false, true] ==
               T1.node_accepts([
                 {"Todo_read_filter_schema", %{field: "comment_count", op: "gt", value: 1}},
                 {"Todo_read_filter_schema", %{field: "comment_count", op: "gt", value: "x"}},
                 {"Todo_read_filter_schema", %{field: "CommentCount", op: "gt", value: 1}},
                 {"Todo_read_filter_schema",
                  %{field: "helpful_comment_count", op: "lte", value: 3}}
               ])
    end

    test "aggregate fields in input position: sortable/filterable, never writable (real zod)" do
      # reference asserts CommentCount appears in input/filter schemas; ash_surface create input
      # has no aggregate key, while the sort schema admits it.
      art = T1.artifact!()
      [create] = Regex.run(~r/export const Todo_create_schema = z\.object\(\{.*?\}\)/s, art)
      refute create =~ "comment_count"

      assert [true, true, false] ==
               T1.node_accepts([
                 {"Todo_read_sort_schema", "comment_count"},
                 {"Todo_read_sort_schema", "-helpful_comment_count"},
                 {"Todo_read_sort_schema", "HelpfulCommentCount"}
               ])
    end

    test "aggregate fields are carried by the read action descriptor (RPC function analogue)" do
      art = T1.artifact!()
      assert art =~ ~s(export const Todo_read_filter_schema)
      assert art =~ ~s(export const Todo_read_sort_schema)
      assert art =~ ~s("comment_count")
      assert art =~ ~s("helpful_comment_count")
    end

    test "regression: no hardcoded camelCase, formatter drives the spelling" do
      for {f, expected} <- [
            {:snake_case, "helpful_comment_count"},
            {:camel_case, "helpfulCommentCount"},
            {:pascal_case, "HelpfulCommentCount"}
          ] do
        T1.with_env(:output_field_formatter, f, fn ->
          assert FieldName.format(:helpful_comment_count, Config.output_field_formatter()) ==
                   expected
        end)
      end
    end
  end
end
