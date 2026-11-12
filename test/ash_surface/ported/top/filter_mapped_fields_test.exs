Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.FilterMappedFieldsTest do
  @moduledoc """
  Adapted from ash_typescript `filter_mapped_fields_test.exs` (Task resource, `archived?` ->
  `isArchived`). The reference reads `FilterTypes.generate_filter_type/1` TypeScript text; here the
  mapping is asserted where ash_surface owns it (`AshSurface.Resource.Info` / `FieldName`), and the
  filter structure (operators per field kind, logical combinators, id/string/boolean/embedded
  fields) is asserted by real node+zod against the generated `Task_read_filter_schema`.
  The artifact filter enumerates the mapped `isArchived` (lane F1-fieldwire; it listed the Ash
  name `archived?` before the mapping reached the compiler). It still emits no
  per-embedded-resource filter type: those reference tests are loud skips in
  `formatter_artifact_gap_test.exs`.
  """
  use ExUnit.Case, async: true

  # first use compiles the whole ported domain (cached per VM); allow for a loaded machine
  @moduletag timeout: 900_000

  alias AshSurface.FieldName
  alias AshSurface.Ported.{T1, Task, TaskMetadata}

  @uuid "7b0a1b0e-0000-4000-8000-000000000000"
  defp f(field, op, value), do: %{field: field, op: op, value: value}
  defp accepts(cases), do: T1.node_accepts(Enum.map(cases, &{"Task_read_filter_schema", &1}))

  describe "filter type generation with mapped field names" do
    test "mapped name for the attribute comes from the resource field_names" do
      assert FieldName.format_field_for_client(:archived?, Task, :camel_case) == "isArchived"
      refute FieldName.format_field_for_client(:archived?, Task, :camel_case) == "archived?"
      assert :archived? in T1.public_names(Task).attributes
    end

    test "mapped boolean field has correct filter operations" do
      assert [true, true, true, false, false] ==
               accepts([
                 f("isArchived", "eq", true),
                 f("isArchived", "neq", true),
                 f("isArchived", "in", [true]),
                 f("isArchived", "gt", true),
                 f("isArchived", "lt", true)
               ])
    end

    test "unmapped fields still appear correctly" do
      assert [true, true] == accepts([f("title", "eq", "t"), f("completed", "eq", true)])
    end

    test "filter type structure is valid (and/or/not combinators over the same field set)" do
      assert [true, true, true, false] ==
               accepts([
                 %{op: "and", value: [f("title", "eq", "t")]},
                 %{op: "or", value: [f("completed", "eq", true)]},
                 %{op: "not", value: f("title", "eq", "t")},
                 %{op: "and", value: [f("nope", "eq", "t")]}
               ])
    end

    test "all mapped fields use consistent naming (single field-name source)" do
      assert FieldName.format_field_for_client(:archived?, Task, :pascal_case) == "isArchived"
      assert FieldName.format_field_for_client(:archived?, Task, :snake_case) == "isArchived"

      assert [true, true] ==
               accepts([f("isArchived", "eq", false), f("isArchived", "neq", false)])
    end

    test "filter includes id field with UUID operations" do
      assert [true, true, true, false, false] ==
               accepts([
                 f("id", "eq", @uuid),
                 f("id", "neq", @uuid),
                 f("id", "in", [@uuid]),
                 f("id", "eq", "not-a-uuid"),
                 f("id", "gt", @uuid)
               ])
    end

    test "filter includes string field operations (contains and ordered comparisons)" do
      assert [true, true, true, true, true, true] ==
               accepts([
                 f("title", "eq", "t"),
                 f("title", "neq", "t"),
                 f("title", "in", ["a", "b"]),
                 f("title", "contains", "t"),
                 f("title", "gt", "a"),
                 f("title", "lt", "z")
               ])
    end

    test "filter includes boolean field operations" do
      assert [true, true, true, false, false] ==
               accepts([
                 f("completed", "eq", true),
                 f("completed", "neq", true),
                 f("completed", "in", [true, false]),
                 f("completed", "gt", true),
                 f("completed", "lt", true)
               ])
    end
  end

  describe "filter type with embedded resource" do
    test "embedded resource field appears in filter with eq/neq/in" do
      assert [true, true, true, false] ==
               accepts([
                 f("metadata", "eq", %{}),
                 f("metadata", "neq", %{}),
                 f("metadata", "in", [%{}]),
                 f("metadata", "gt", %{})
               ])
    end
  end

  describe "field ordering and structure" do
    test "mapped fields sit in the same sorted field enums as the other fields" do
      art = T1.artifact!()
      [filter] = Regex.run(~r/export const Task_read_filter_schema = [^\n]*/, art)
      enums = Regex.scan(~r/z\.enum\(\[([^\]]*)\]\)/, filter, capture: :all_but_first)
      names = enums |> List.flatten() |> Enum.flat_map(&String.split(&1, ", "))
      assert ~s("isArchived") in names
      refute ~s("archived?") in names
      assert ~s("title") in names
      assert ~s("completed") in names

      # every enum group is sorted by Ash name
      for [group] <- enums do
        group_names = String.split(group, ", ")
        assert group_names == Enum.sort(group_names)
      end
    end

    test "each field object closes properly (artifact module parses under node)" do
      assert [true, false] == accepts([f("isArchived", "eq", true), f("archived?", "eq", true)])
    end
  end

  describe "comprehensive filter mapping coverage" do
    test "all Task fields are present with their mapping" do
      assert [true, true, true, true, true] ==
               accepts([
                 f("id", "eq", @uuid),
                 f("title", "eq", "t"),
                 f("completed", "eq", true),
                 f("isArchived", "eq", true),
                 f("metadata", "eq", %{})
               ])

      assert FieldName.format_field_for_client(:archived?, Task, :camel_case) == "isArchived"
    end

    test "logical operators are present in the filter schema" do
      assert [true, true, true] ==
               accepts([
                 %{op: "and", value: [f("title", "eq", "a"), f("completed", "eq", false)]},
                 %{op: "or", value: [f("title", "eq", "a"), f("title", "eq", "b")]},
                 %{op: "not", value: f("completed", "eq", true)}
               ])
    end

    test "filter operations use fixed snake literals, not camelCase" do
      assert [true, true, false, false] ==
               accepts([
                 f("title", "eq", "a"),
                 f("title", "neq", "a"),
                 f("title", "notEq", "a"),
                 f("title", "not_eq", "a")
               ])
    end
  end

  describe "filter type for TaskMetadata embedded resource (mapping at the resource)" do
    test "embedded resource mapping: created_by? -> createdBy, is_public? -> isPublic" do
      assert FieldName.format_field_for_client(:created_by?, TaskMetadata, :camel_case) ==
               "createdBy"

      assert FieldName.format_field_for_client(:is_public?, TaskMetadata, :camel_case) ==
               "isPublic"

      assert FieldName.format_field_for_client(:notes, TaskMetadata, :camel_case) == "notes"

      assert FieldName.format_field_for_client(:priority_level, TaskMetadata, :camel_case) ==
               "priorityLevel"
    end

    test "embedded resource attributes carry the expected types" do
      attrs = Map.new(Ash.Resource.Info.public_attributes(TaskMetadata), &{&1.name, &1.type})
      assert attrs[:created_by?] == Ash.Type.String
      assert attrs[:is_public?] == Ash.Type.Boolean
      assert attrs[:priority_level] == Ash.Type.Integer
    end
  end

  describe "filter type consistency with the client" do
    test "filter schema matches client expectations (mapped name known, fixed operators)" do
      assert FieldName.format_field_for_client(:archived?, Task, :camel_case) == "isArchived"

      assert [true, true, true] ==
               accepts([
                 f("isArchived", "eq", true),
                 f("isArchived", "neq", true),
                 f("title", "eq", "t")
               ])
    end

    test "nested filter structures work with mapped names" do
      assert [true] ==
               accepts([
                 %{
                   op: "and",
                   value: [
                     %{op: "not", value: f("isArchived", "eq", true)},
                     f("title", "eq", "t")
                   ]
                 }
               ])

      assert FieldName.format_field_for_client(:archived?, Task, :camel_case) == "isArchived"
    end
  end
end
