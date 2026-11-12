Code.require_file("support/t1.exs", __DIR__)
Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.FormatterArtifactTest do
  @moduledoc """
  Lane F1-fieldwire: the former `formatter_artifact_gap_test.exs` loud skips, now real. The
  reference tests assert the generated artifact's spelling follows `:output_field_formatter` and
  resource `field_names`; here every case compiles the real ported domain under the formatter,
  projects the real artifact (or reads the compiled IR zod) and executes it under real node + zod.
  Mapped (`field_names`) names are final and never re-formatted.
  """
  use ExUnit.Case, async: false

  # each formatter is a fresh compile + projection of the whole ported domain
  @moduletag timeout: 1_800_000

  alias AshSurface.Compiler.{EmbeddedSchema, TypeFacts}
  alias AshSurface.Ported.{T1, T2, Post, Task, TaskMetadata, Todo}

  defmodule Formatters do
    @moduledoc "Hand-written real custom formatter functions."
    def custom_format(field_name), do: "custom_#{field_name}"
    def with_prefix(field_name, prefix), do: "#{prefix}_#{field_name}"
  end

  defp accepts(fmt, cases), do: T1.node_accepts(cases, T1.artifact_under(fmt))
  defp ir(fmt, resource, action), do: T1.ir_under(fmt, resource, action)

  defp embedded_zod(fmt, resource) do
    AshSurface.FieldName.with_formatter(fmt, fn ->
      definition = TypeFacts.analyze(resource, []).definition

      {:ok, zod} =
        EmbeddedSchema.render(definition, resources: TypeFacts.embedded_resources([definition]))

      zod
    end)
  end

  describe "aggregate keys follow the formatter" do
    test "PascalCase under :pascal_case (artifact sort and IR selection/aggregates)" do
      assert [true, false, false] ==
               accepts(:pascal_case, [
                 {"Todo_read_sort_schema", "CommentCount"},
                 {"Todo_read_sort_schema", "comment_count"},
                 {"Todo_read_sort_schema", "commentCount"}
               ])

      schema = ir(:pascal_case, Todo, :read).schema
      assert "CommentCount" in Map.keys(schema.aggregates)
      refute "comment_count" in Map.keys(schema.aggregates)

      assert [true, false] ==
               T2.node_eval(schema.selection, [
                 %{fields: ["CommentCount", "HelpfulCommentCount"]},
                 %{fields: ["comment_count"]}
               ])
               |> elem(1)
    end

    test "snake_case under :snake_case" do
      assert [true, false, true, false] ==
               accepts(:snake_case, [
                 {"Todo_read_sort_schema", "comment_count"},
                 {"Todo_read_sort_schema", "commentCount"},
                 {"Todo_read_sort_schema", "-helpful_comment_count"},
                 {"Todo_read_sort_schema", "HelpfulCommentCount"}
               ])

      assert "helpful_comment_count" in Map.keys(ir(:snake_case, Todo, :read).schema.aggregates)
    end
  end

  describe "calculation keys follow the formatter" do
    test "PascalCase calculation load keys (and arguments) under :pascal_case" do
      load = ir(:pascal_case, Todo, :read).schema.calculations["load"]

      assert {:ok, [true, true, false, false]} =
               T2.node_eval(load, [
                 %{IsOverdue: %{args: %{}}},
                 %{DaysUntilDue: %{}},
                 %{is_overdue: %{args: %{}}},
                 %{isOverdue: %{args: %{}}}
               ])

      assert load =~ ~s|"Prefix"|
      refute load =~ ~s|"prefix"|
    end
  end

  describe "embedded resource keys follow the formatter" do
    test "PascalCase keys, mapped names stay verbatim, under :pascal_case" do
      zod = embedded_zod(:pascal_case, TaskMetadata)
      assert zod =~ "PriorityLevel:"
      assert zod =~ "Notes:"
      # `field_names` mappings are final: neither re-formatted nor spelled with the Ash name
      assert zod =~ "createdBy:"
      assert zod =~ "isPublic:"
      refute zod =~ "priority_level"
      refute zod =~ "created_by?"
    end

    test "snake_case keys under :snake_case" do
      zod = embedded_zod(:snake_case, TaskMetadata)
      assert zod =~ "priority_level:"
      refute zod =~ "priorityLevel"
      assert zod =~ "createdBy:"
    end
  end

  describe "relationship keys follow the formatter" do
    test "PascalCase load keys under :pascal_case" do
      load = ir(:pascal_case, Todo, :read).schema.load

      assert {:ok, [true, false, false]} =
               T2.node_eval(load, [%{Commenters: true}, %{commenters: true}, %{comments: true}])
    end
  end

  describe "filter keys follow the formatter" do
    test "filter field names are viewCount (camel) / ViewCount (pascal), never view_count" do
      assert [true, false] ==
               accepts(:camel_case, [
                 {"Post_read_filter_schema", %{field: "viewCount", op: "gt", value: 1}},
                 {"Post_read_filter_schema", %{field: "view_count", op: "gt", value: 1}}
               ])

      assert [true, false] ==
               accepts(:pascal_case, [
                 {"Post_read_filter_schema", %{field: "ViewCount", op: "gt", value: 1}},
                 {"Post_read_filter_schema", %{field: "viewCount", op: "gt", value: 1}}
               ])
    end

    test "relationship filters use formatted names" do
      filter = ir(:camel_case, Post, :read).schema.filter
      assert filter =~ ~s|"author"|
      refute filter =~ ~s|"Author"|
    end

    test "mapped filter: enumerates isArchived, not archived?, under every formatter" do
      for fmt <- [nil, :camel_case, :pascal_case, :snake_case] do
        assert [true, false] ==
                 accepts(fmt, [
                   {"Task_read_filter_schema", %{field: "isArchived", op: "eq", value: true}},
                   {"Task_read_filter_schema", %{field: "archived?", op: "eq", value: true}}
                 ])
      end
    end
  end

  describe "codegen: generated input keys follow the formatter" do
    defp todo_create_keys(fmt),
      do: T1.node_shape_keys(["Todo_create_schema"], T1.artifact_under(fmt))["Todo_create_schema"]

    test "camelCase with :camel_case" do
      keys = todo_create_keys(:camel_case)
      assert "autoComplete" in keys
      refute "auto_complete" in keys
    end

    test "PascalCase with :pascal_case" do
      keys = todo_create_keys(:pascal_case)
      assert "AutoComplete" in keys
      refute "autoComplete" in keys
    end

    test "snake_case with :snake_case" do
      keys = todo_create_keys(:snake_case)
      assert "auto_complete" in keys
      refute "autoComplete" in keys
    end

    test "custom {module, function} formatter" do
      keys = todo_create_keys({Formatters, :custom_format})
      assert "custom_auto_complete" in keys
      refute "auto_complete" in keys
    end

    test "custom {module, function, args} formatter" do
      keys = todo_create_keys({Formatters, :with_prefix, ["pre"]})
      assert "pre_auto_complete" in keys
    end

    test "unset formatter is the camel_case reference default" do
      keys = todo_create_keys(nil)
      assert "autoComplete" in keys
      refute "auto_complete" in keys
    end
  end

  describe "resource and action name mappings are applied at every site" do
    test "field_names reach the Task read filter, sort, selection and inverse table" do
      schema = ir(nil, Task, :read).schema
      assert schema.selection =~ "isArchived"
      refute schema.selection =~ "archived?"
      assert schema.sort =~ "isArchived"
      assert schema.facts["field_names"]["fields"]["isArchived"] == "archived?"
    end

    test "argument_names reach the action input keys, validation shape and inverse table" do
      schema = ir(:camel_case, Task, :mark_completed).schema
      assert schema.zod =~ "isCompleted:"
      refute schema.zod =~ "is_task_completed_now?"
      assert schema.validation_error =~ "isCompleted"
      assert schema.facts["field_names"]["arguments"]["isCompleted"] == "is_task_completed_now?"
    end
  end
end
