Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.FilterFormattingTest do
  @moduledoc """
  Adapted from ash_typescript `filter_formatting_test.exs`. The reference asserts the generated
  `XFilterInput` TypeScript type spells field names AND operator keys through
  `:output_field_formatter` (`notEq?:`, `greaterThan?:`). ash_surface's filter is a data-driven Zod
  union `{field: <Ash field name>, op: <fixed operator literal>, value}` (operators are the literals
  `eq neq gt gte lt lte in is_nil contains ...`, never formatter-dependent), so each reference
  test maps to (a) real node+zod acceptance of the equivalent filter terms, and (b) the
  `FieldName` spelling of the same fields under the formatter. Formatter-driven artifact keys and
  relationship-typed filter inputs are registered gaps (`formatter_artifact_gap_test.exs`).
  Pinned divergence (operator decision in the receipt): string fields expose
  `contains/starts_with/ends_with`, not `gt/lt`; the reference's `greaterThan?: string` has no
  counterpart.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Config, FieldName}
  alias AshSurface.Ported.T1

  defp f(field, op, value), do: %{field: field, op: op, value: value}

  describe "FilterInput field formatting" do
    test "camel_case: Post fields spell viewCount/publishedAt; operators are fixed literals" do
      T1.with_env(:output_field_formatter, :camel_case, fn ->
        fmt = Config.output_field_formatter()
        assert FieldName.format(:view_count, fmt) == "viewCount"
        assert FieldName.format(:published_at, fmt) == "publishedAt"
      end)

      # operators never go through the formatter: neq/gt/gte/lt/lte (not notEq/greaterThan/...)
      assert [true, true, true, true, true, false, false, false] ==
               T1.node_accepts([
                 {"Post_read_filter_schema", f("view_count", "neq", 1)},
                 {"Post_read_filter_schema", f("view_count", "gt", 1)},
                 {"Post_read_filter_schema", f("view_count", "gte", 1)},
                 {"Post_read_filter_schema", f("view_count", "lt", 1)},
                 {"Post_read_filter_schema", f("view_count", "lte", 1)},
                 {"Post_read_filter_schema", f("view_count", "notEq", 1)},
                 {"Post_read_filter_schema", f("view_count", "greaterThan", 1)},
                 {"Post_read_filter_schema", f("view_count", "not_eq", 1)}
               ])
    end

    test "snake_case: Post fields stay view_count/published_at" do
      T1.with_env(:output_field_formatter, :snake_case, fn ->
        fmt = Config.output_field_formatter()
        assert FieldName.format(:view_count, fmt) == "view_count"
        assert FieldName.format(:published_at, fmt) == "published_at"
        refute FieldName.format(:view_count, fmt) == "viewCount"
      end)

      assert [true, true, false, false] ==
               T1.node_accepts([
                 {"Post_read_filter_schema", f("view_count", "gt", 1)},
                 {"Post_read_filter_schema", f("published_at", "gt", "2020-01-01T00:00:00Z")},
                 {"Post_read_filter_schema", f("viewCount", "gt", 1)},
                 {"Post_read_filter_schema", f("publishedAt", "gt", "2020-01-01T00:00:00Z")}
               ])
    end

    test "pascal_case: Post fields spell ViewCount/PublishedAt" do
      T1.with_env(:output_field_formatter, :pascal_case, fn ->
        fmt = Config.output_field_formatter()
        assert FieldName.format(:view_count, fmt) == "ViewCount"
        assert FieldName.format(:published_at, fmt) == "PublishedAt"
        refute FieldName.format(:view_count, fmt) == "view_count"
      end)

      assert [false] == T1.node_accepts([{"Post_read_filter_schema", f("ViewCount", "gt", 1)}])
    end

    test "relationship filters use formatted field names (relationship fields exist, 'related' op absent)" do
      assert :author in T1.public_names(AshSurface.Ported.Post).relationships
      assert :comments in T1.public_names(AshSurface.Ported.Post).relationships
      assert FieldName.format(:author, :camel_case) == "author"
      # the artifact filter carries no relationship terms: a relationship name is not a field
      assert [false] ==
               T1.node_accepts([
                 {"Post_read_filter_schema",
                  f("author", "eq", "7b0a1b0e-0000-4000-8000-000000000000")}
               ])
    end

    test "aggregate/attribute filters of User: and-combinator + name/email/active/is_super_admin" do
      assert [true, true, true, true] ==
               T1.node_accepts([
                 {"User_read_filter_schema",
                  %{op: "and", value: [f("name", "eq", "x"), f("email", "contains", "@")]}},
                 {"User_read_filter_schema", f("active", "eq", true)},
                 {"User_read_filter_schema", f("is_super_admin", "eq", true)},
                 {"User_read_filter_schema", %{op: "or", value: [f("name", "eq", "a")]}}
               ])

      assert FieldName.format(:is_super_admin, :camel_case) == "isSuperAdmin"
    end

    test "mixed formatting scenarios work correctly (typed values per field kind)" do
      assert [true, true, true, true, true, true, false, false] ==
               T1.node_accepts([
                 {"Post_read_filter_schema", f("title", "eq", "t")},
                 {"Post_read_filter_schema", f("published", "eq", true)},
                 {"Post_read_filter_schema", f("view_count", "eq", 3)},
                 {"Post_read_filter_schema", f("published_at", "eq", "2020-01-01T00:00:00Z")},
                 {"Post_read_filter_schema", f("title", "neq", "t")},
                 {"Post_read_filter_schema", f("view_count", "gt", 3)},
                 {"Post_read_filter_schema", f("title", "eq", 3)},
                 {"Post_read_filter_schema", f("published", "gt", true)}
               ])
    end

    defmodule TestFormatter do
      def prefix_field(field_name), do: "prefix_#{field_name}"
    end

    test "custom formatter function spells fields (operators are literals, not prefixed)" do
      fmt = {TestFormatter, :prefix_field}

      T1.with_env(:output_field_formatter, fmt, fn ->
        assert :ok == FieldName.validate_formatter(Config.output_field_formatter())
        assert FieldName.format(:title, Config.output_field_formatter()) == "prefix_title"
        assert FieldName.format(:published, Config.output_field_formatter()) == "prefix_published"

        assert FieldName.format(:view_count, Config.output_field_formatter()) ==
                 "prefix_view_count"
      end)

      assert [false, true] ==
               T1.node_accepts([
                 {"Post_read_filter_schema", f("prefix_title", "prefix_eq", "t")},
                 {"Post_read_filter_schema", f("title", "in", ["t"])}
               ])
    end
  end
end
