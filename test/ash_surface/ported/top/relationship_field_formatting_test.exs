Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.RelationshipFieldFormattingTest do
  @moduledoc """
  Adapted from ash_typescript `relationship_field_formatting_test.exs`. `.ts` text assertions
  become `FieldName` spelling over the real relationship-adjacent fields (belongs_to foreign key,
  aggregates, calculations, user attributes) and real node+zod acceptance in the generated
  schemas. Relationship-typed filter inputs (`author?: UserFilterInput`) have no ash_surface
  artifact counterpart and the artifact keys following the formatter are registered gaps
  (`formatter_artifact_gap_test.exs`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Config, FieldName}
  alias AshSurface.Ported.{T1, Todo, User}

  test "fixture declares the relationship fields under test" do
    todo = T1.public_names(Todo)
    assert :user_id in todo.attributes
    assert :user in todo.relationships
    assert :comment_count in todo.aggregates
    assert :self in todo.calculations
    assert :is_super_admin in T1.public_names(User).attributes
  end

  describe "relationship field formatting with configured formatters" do
    test "PascalCase names under :pascal_case" do
      T1.with_env(:output_field_formatter, :pascal_case, fn ->
        f = Config.output_field_formatter()
        assert FieldName.format(:is_super_admin, f) == "IsSuperAdmin"
        assert FieldName.format(:comment_count, f) == "CommentCount"
        assert FieldName.format(:helpful_comment_count, f) == "HelpfulCommentCount"
        assert FieldName.format(:user_id, f) == "UserId"

        for atom <- ~w(is_super_admin comment_count helpful_comment_count user_id)a do
          refute FieldName.format(atom, f) == FieldName.format(atom, :camel_case)
        end

        for atom <- ~w(has_comments average_rating highest_rating latest_comment_content)a do
          refute FieldName.format(atom, f) == FieldName.format(atom, :camel_case)
        end
      end)
    end

    test "snake_case names under :snake_case" do
      T1.with_env(:output_field_formatter, :snake_case, fn ->
        f = Config.output_field_formatter()

        for atom <- ~w(is_super_admin comment_count helpful_comment_count user_id)a do
          assert FieldName.format(atom, f) == Atom.to_string(atom)

          refute FieldName.format(atom, f) in [
                   FieldName.format(atom, :camel_case),
                   FieldName.format(atom, :pascal_case)
                 ]
        end
      end)
    end

    test "relationship calculation names (self) follow the formatter" do
      assert FieldName.format(:self, :pascal_case) == "Self"
      refute FieldName.format(:self, :pascal_case) == "self"
    end

    test "relationship fields work in nested field selection (real zod: read select/sort)" do
      assert [true, true, false] ==
               T1.node_accepts([
                 {"Todo_read_sort_schema", "comment_count"},
                 {"Todo_read_sort_schema", "user_id"},
                 {"Todo_read_sort_schema", "CommentCount"}
               ])
    end

    test "relationship fields work in filter types (real zod)" do
      assert [true, true, false] ==
               T1.node_accepts([
                 {"User_read_filter_schema", %{field: "is_super_admin", op: "eq", value: true}},
                 {"Todo_read_filter_schema", %{field: "comment_count", op: "gt", value: 0}},
                 {"User_read_filter_schema", %{field: "IsSuperAdmin", op: "eq", value: true}}
               ])
    end

    test "belongs_to foreign key is required in the create schema under its Ash name" do
      assert [true, false] ==
               T1.node_accepts([
                 {"Todo_create_schema",
                  %{title: "t", user_id: "7b0a1b0e-0000-4000-8000-000000000000"}},
                 {"Todo_create_schema",
                  %{title: "t", userId: "7b0a1b0e-0000-4000-8000-000000000000"}}
               ])
    end

    test "regression: formatter-driven spelling, never hardcoded camelCase" do
      for {f, expected} <- [
            {:snake_case, "user_id"},
            {:camel_case, "userId"},
            {:pascal_case, "UserId"}
          ] do
        T1.with_env(:output_field_formatter, f, fn ->
          assert FieldName.format(:user_id, Config.output_field_formatter()) == expected
        end)
      end
    end
  end
end
