Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.ResourceSchemaMappedFieldsTest do
  @moduledoc """
  Adaptation of ash_typescript `resource_schema_mapped_fields_test.exs` (Task: `archived?` ->
  `isArchived`; TaskMetadata: `created_by?` -> `createdBy`, `is_public?` -> `isPublic`).

  The reference asserts `export type TaskResourceSchema = {...}` text. ash_surface emits Zod: the
  record schema (`RecordSchema.render/2`) and the embedded resource Zod (`EmbeddedSchema`) are
  executed under real node + zod, with the resource `field_names` mapping applied verbatim to the
  emitted keys (`archived?` -> `isArchived`, `created_by?` -> `createdBy`). Also asserted: the
  resolved client names the `AshSurface.Resource` transformer persists
  (`:ash_surface_formatted_fields`) and the field facts (type kind, nullability) from Ash.
  The TS-only `__type`/`__primitiveFields` discriminators and the per-action input keys are loud
  skips in `resource_schema_mapped_fields_gap_test.exs`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{EmbeddedSchema, TypeFacts}
  alias AshSurface.Ported.{T2, Task, TaskMetadata}
  alias AshSurface.Resource.Info

  defp mapping(resource),
    do: Spark.Dsl.Extension.get_persisted(resource, :ash_surface_formatted_fields)

  defp fact(resource, name) do
    attr = Ash.Resource.Info.attribute(resource, name)
    analysis = TypeFacts.analyze(attr.type, attr.constraints)
    {analysis.kind, attr.allow_nil?}
  end

  defp embedded_zod(resource) do
    definition = TypeFacts.analyze(resource, []).definition

    {:ok, zod} =
      AshSurface.Ported.AshNames.with_verbatim(fn ->
        EmbeddedSchema.render(definition, resources: TypeFacts.embedded_resources([definition]))
      end)

    zod
  end

  describe "resource schema generation with mapped field names" do
    test "resolved client names include the mapped name and not the internal name" do
      %{mapped: mapped, reverse: reverse} = mapping(Task)
      assert mapped[:archived?] == "isArchived"
      assert reverse["isArchived"] == :archived?
      refute Map.has_key?(reverse, "archived?")
      refute "archived?" in Map.values(mapped)
    end

    test "unmapped fields appear unchanged" do
      %{mapped: mapped} = mapping(Task)
      assert mapped[:id] == "id"
      assert mapped[:title] == "title"
      assert mapped[:completed] == "completed"
    end

    test "mapped boolean field has the boolean type and is not nullable" do
      assert fact(Task, :archived?) == {"boolean", false}
      assert fact(Task, :completed) == {"boolean", false}
    end

    test "all primitive fields are present in the resolved name set" do
      %{reverse: reverse} = mapping(Task)

      for name <- ["id", "title", "completed", "isArchived"],
          do: assert(Map.has_key?(reverse, name))
    end

    test "embedded fields are classified separately from primitive fields" do
      # The reference omits embedded fields from the primitive union when not allowed; here the
      # type kind distinguishes them.
      assert fact(Task, :metadata) == {"embedded_resource", true}
      assert {"boolean", false} == fact(Task, :archived?)
    end
  end

  describe "resource facts wire names" do
    test "public attribute facts carry the mapped wire name, not the internal one" do
      facts = T2.read_facts(Task)
      assert "isArchived" in facts.public_attributes
      refute "archived?" in facts.public_attributes
      assert "title" in facts.public_attributes
    end
  end

  describe "record schema with mapped field names (was: generate_unified_resource_schema)" do
    test "Task record schema emits the mapped key and not the internal name" do
      zod = T2.record_zod(Task)
      assert zod =~ "isArchived: z.boolean()"
      refute zod =~ "archived?"

      assert %{"keys" => keys, "mapped" => [true, false], "required" => false} =
               T2.node_probe(zod, """
               return { keys: Object.keys(s.shape),
                        mapped: [true, "yes"].map((v) => s.shape.isArchived.safeParse(v).success),
                        required: s.shape.isArchived.safeParse(undefined).success };
               """)

      assert "isArchived" in keys
      refute "archived?" in keys
      assert Enum.all?(["id", "title", "completed", "metadata"], &(&1 in keys))
    end

    test "embedded attribute is rendered with its mapped keys (nested)" do
      zod = T2.record_zod(Task)
      assert zod =~ "createdBy"
      refute zod =~ "created_by?"
    end

    test "embedded resource Zod uses the mapped names, unmapped keep the Ash name" do
      zod = embedded_zod(TaskMetadata)
      assert zod =~ "createdBy:"
      assert zod =~ "isPublic:"
      assert zod =~ "priority_level:"
      assert zod =~ "notes:"
      refute zod =~ "created_by?"
      refute zod =~ "is_public?"
    end
  end

  describe "field type definitions" do
    test "non-nullable fields are not marked as nullable" do
      assert fact(Task, :title) == {"string", false}
      assert fact(Task, :completed) == {"boolean", false}
      assert fact(Task, :archived?) == {"boolean", false}
    end

    test "uuid fields have the uuid kind" do
      assert fact(Task, :id) == {"uuid", false}
      assert AshSurface.Ported.T2.zod(Ash.Type.UUID) == "z.guid()"
    end

    test "string fields have the string kind" do
      assert T2.zod(Ash.Resource.Info.attribute(Task, :title).type) == "z.string()"
    end

    test "boolean fields have the boolean kind" do
      assert T2.zod(Ash.Resource.Info.attribute(Task, :completed).type) == "z.boolean()"
      assert T2.zod(Ash.Resource.Info.attribute(Task, :archived?).type) == "z.boolean()"
    end
  end

  describe "embedded resource schema generation" do
    test "embedded resource generates its own object schema" do
      zod = embedded_zod(TaskMetadata)
      assert String.starts_with?(zod, "z.object({")
      assert String.ends_with?(zod, "}).strict()")
    end

    test "embedded resource resolved names use the mapped field names" do
      %{mapped: mapped, reverse: reverse} = mapping(TaskMetadata)
      assert mapped[:created_by?] == "createdBy"
      assert mapped[:is_public?] == "isPublic"
      assert reverse["createdBy"] == :created_by?
      refute Map.has_key?(reverse, "created_by?")
      refute Map.has_key?(reverse, "is_public?")

      # unmapped fields keep their (formatter-applied) names
      assert mapped[:notes] == "notes"
      assert mapped[:priority_level] == "priorityLevel"
    end

    test "embedded resource resolved name set includes mapped and unmapped names" do
      %{reverse: reverse} = mapping(TaskMetadata)

      assert Enum.sort(Map.keys(reverse)) == [
               "createdBy",
               "id",
               "isPublic",
               "notes",
               "priorityLevel"
             ]
    end

    test "embedded resource non-nullable mapped fields are not marked nullable" do
      assert fact(TaskMetadata, :created_by?) == {"string", false}
      assert fact(TaskMetadata, :is_public?) == {"boolean", false}
      zod = embedded_zod(TaskMetadata)
      assert zod =~ ~S|createdBy: z.string().min(1),|
      refute zod =~ ~S|createdBy: z.string().min(1).nullable()|
    end

    test "embedded resource nullable fields are marked nullable" do
      assert fact(TaskMetadata, :notes) == {"string", true}
      assert fact(TaskMetadata, :priority_level) == {"integer", true}
      zod = embedded_zod(TaskMetadata)
      assert zod =~ "notes: z.string().min(1).nullable().optional()"
      assert zod =~ "priority_level: z.number().int().min(1).max(5).nullable().optional()"
    end
  end

  describe "input schema generation with mapped field names (embedded input Zod, executed)" do
    test "required fields are required, defaulted and nullable fields are optional" do
      zod = embedded_zod(TaskMetadata)

      assert {:ok, oks} =
               T2.node_eval(zod, [
                 %{"createdBy" => "ann"},
                 %{
                   "createdBy" => "ann",
                   "isPublic" => true,
                   "notes" => nil,
                   "priority_level" => 3
                 },
                 %{},
                 %{"createdBy" => "ann", "priority_level" => 9},
                 %{"createdBy" => "ann", "unknown" => 1},
                 %{"created_by?" => "ann"}
               ])

      assert oks == [true, true, false, false, false, false]
    end

    test "input schema structure" do
      zod = embedded_zod(TaskMetadata)
      assert zod =~ ~S|createdBy: z.string().min(1)|
      assert zod =~ ~S|isPublic: z.boolean().optional()|
      refute zod =~ "created_by?"
    end
  end

  describe "comprehensive schema mapping coverage" do
    test "all Task fields resolve with the correct mappings" do
      %{mapped: mapped} = mapping(Task)

      assert Map.take(mapped, [:id, :title, :completed, :archived?]) == %{
               id: "id",
               title: "title",
               completed: "completed",
               archived?: "isArchived"
             }

      assert Info.field_names(Task) == [archived?: "isArchived"]
    end

    test "all TaskMetadata fields resolve with the correct mappings" do
      %{mapped: mapped} = mapping(TaskMetadata)
      assert Info.field_names(TaskMetadata) == [created_by?: "createdBy", is_public?: "isPublic"]
      assert mapped[:id] == "id"
      assert mapped[:notes] == "notes"
      assert mapped[:priority_level] == "priorityLevel"
      assert mapped[:created_by?] == "createdBy"
    end

    test "resolved names are consistent between the resource and its embedded input schema" do
      %{reverse: reverse} = mapping(TaskMetadata)
      zod = embedded_zod(TaskMetadata)

      # every writable attribute the embedded input schema carries has exactly one resolved client name
      for {key, atom} <- [
            {"createdBy", :created_by?},
            {"isPublic", :is_public?},
            {"notes", :notes},
            {"priority_level", :priority_level}
          ] do
        assert zod =~ key
        assert atom in Map.values(reverse)
      end
    end
  end

  describe "schema consistency" do
    test "embedded schema generation is deterministic and orders keys by field name" do
      assert embedded_zod(TaskMetadata) == embedded_zod(TaskMetadata)
      zod = embedded_zod(TaskMetadata)

      positions =
        for key <- ["createdBy", "isPublic", "notes", "priority_level"] do
          {pos, _} = :binary.match(zod, key)
          pos
        end

      assert positions == Enum.sort(positions)
    end

    test "Task mapping names resolve inversely to the internal names" do
      %{mapped: mapped, reverse: reverse} = mapping(Task)

      for {internal, client} <- mapped do
        assert reverse[client] == internal
      end
    end
  end
end
