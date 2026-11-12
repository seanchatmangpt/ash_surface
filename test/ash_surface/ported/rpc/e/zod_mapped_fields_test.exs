Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.ZodMappedFieldsTest do
  @moduledoc """
  Adaptation of ash_typescript `rpc/zod_mapped_fields_test.exs` (30 tests).

  Reference: `ZodSchemaGenerator.generate_zod_schema(Task, action, name)` /
  `generate_zod_schema_for_resource(TaskMetadata)` text. ash_surface counterpart: the real
  projected artifact (`Task_*_schema` exports of the shared ported domain; TaskMetadata is
  projected as the embedded attribute `task_metadata` of `OrderMixedHolder_create_schema`),
  asserted on the generated Zod text AND under real node + real zod.

  Per-test status (reference describe -> port):

    * create (2), read (1), unmapped-field edge (1), type correctness `title` (1), action
      coverage (3), embedded TaskMetadata (6), typed struct `stats` (7): real tests below.
      Keys: Ash names verbatim (snake_case) except type-level mapped names
      (`typescript_field_names`: `createdBy`, `isPublic`, `isUrgent`) which the artifact applies.
    * Resource-level `field_names`/`argument_names` in action input keys (`archived?` ->
      `isArchived`, `is_task_completed_now?` -> `isCompleted`) and the TaskMetadata
      validation-error shape (10 tests, lane F1-fieldwire): real tests in the last describe.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.E
  alias AshSurface.Ported.E.Zod

  setup_all do
    art = E.artifact!()
    holder_art = E.artifact!([AshSurface.Ported.E.Fixtures.Domain])

    %{
      art: art,
      holder_art: holder_art,
      create: Zod.block!(art, "Task_create_schema"),
      update: Zod.block!(art, "Task_update_schema"),
      mark: Zod.block!(art, "Task_mark_completed_schema"),
      meta: Zod.line!(Zod.block!(holder_art, "OrderMixedHolder_create_schema"), "task_metadata")
    }
  end

  describe "Zod schemas for create actions with mapped field names" do
    test "generate_zod_schema includes mapped field names for accepts", %{
      create: create,
      art: art
    } do
      assert Zod.line!(create, "title") =~ "title: z.string().min(1)"
      refute create =~ "archived?"

      assert [true, false] ==
               E.node_accepts(art, [
                 {"Task_create_schema", %{"title" => "t"}},
                 {"Task_create_schema", %{}}
               ])
    end

    test "generated Zod schema is valid object syntax", %{create: create, art: art} do
      assert create =~ "export const Task_create_schema = z.object({"
      assert create =~ "})"
      assert [true] == E.node_accepts(art, [{"Task_create_schema", %{"title" => "ok"}}])
    end
  end

  describe "Zod schemas for read actions" do
    test "read action with no arguments generates an empty object schema", %{art: art} do
      block = Zod.block!(art, "Task_read_schema")
      assert block =~ "z.object({"
      refute block =~ ": z."

      # reference: "" (no schema at all); ash_surface: a schema that accepts the empty input
      assert [true] == E.node_accepts(art, [{"Task_read_schema", %{}}])
    end
  end

  describe "field name mapping edge cases" do
    test "fields without mappings still appear correctly", %{create: create} do
      assert create =~ "title:"
    end
  end

  describe "Zod schema type correctness" do
    test "required string fields generate z.string().min(1)", %{update: update, art: art} do
      assert Zod.line!(update, "title") =~ "title: z.string().min(1)"

      assert [false] ==
               E.node_accepts(art, [{"Task_update_schema", %{"title" => ""}}])
    end
  end

  describe "action type coverage" do
    test "create action generates Zod schema when it has accepts", %{create: create} do
      refute create == ""
      assert create =~ "z.object"
    end

    test "update action generates Zod schema when it has accepts or arguments", %{update: update} do
      refute update == ""
      assert update =~ "z.object"
    end

    test "generic action generates Zod schema when it has arguments", %{mark: mark, art: art} do
      refute mark == ""
      assert mark =~ "z.object"
      assert mark =~ "z.boolean()"

      # the one required (non-nullable, no default) boolean argument
      assert [false] == E.node_accepts(art, [{"Task_mark_completed_schema", %{}}])
    end
  end

  describe "Zod schemas for embedded resources with mapped field names" do
    test "embedded schema includes mapped field names", %{meta: meta} do
      assert meta =~ "createdBy: z.string()"
      assert meta =~ "isPublic: z.boolean()"

      refute meta =~ "created_by?"
      refute meta =~ "is_public?"
    end

    test "embedded resource Zod schema has correct structure", %{meta: meta, holder_art: art} do
      assert meta =~ "task_metadata: z.object({"
      assert meta =~ "}).strict()"

      # strict: an undeclared key is rejected under real zod
      assert [true, false] ==
               E.node_accepts(art, [
                 {"OrderMixedHolder_create_schema", %{"task_metadata" => %{"createdBy" => "me"}}},
                 {"OrderMixedHolder_create_schema",
                  %{"task_metadata" => %{"createdBy" => "me", "bogus" => 1}}}
               ])
    end

    test "embedded resource Zod schema handles optional fields correctly", %{
      meta: meta,
      holder_art: art
    } do
      assert meta =~ "notes: z.string().min(1).nullable().optional()"
      assert meta =~ "priority_level: z.number().int().min(1).max(5).nullable().optional()"
      assert meta =~ "isPublic: z.boolean().optional()"
      refute meta =~ "is_public?"

      assert meta =~ "createdBy: z.string().min(1)"
      refute meta =~ "created_by?"
      refute meta =~ "createdBy: z.string().min(1).optional()"

      assert [true, false, false] ==
               E.node_accepts(art, [
                 {"OrderMixedHolder_create_schema",
                  %{"task_metadata" => %{"createdBy" => "me", "notes" => nil}}},
                 {"OrderMixedHolder_create_schema", %{"task_metadata" => %{"notes" => "n"}}},
                 {"OrderMixedHolder_create_schema",
                  %{"task_metadata" => %{"createdBy" => "me", "priority_level" => 6}}}
               ])
    end

    test "embedded resource uses mapped field names", %{meta: meta} do
      assert meta =~ "createdBy:"
      refute meta =~ "created_by?"
      assert meta =~ "isPublic:"
      refute meta =~ "is_public?"
      assert meta =~ "priority_level:"
    end

    test "embedded resource Zod schemas do not expose private fields", %{meta: meta} do
      assert meta =~ "notes:"
      assert meta =~ "createdBy:"
      refute meta =~ "created_by?"
      assert meta =~ "isPublic:"
      refute meta =~ "is_public?"
      assert meta =~ "priority_level:"

      # exactly the public attributes (the reference's `id` is a primary key and not projected)
      public =
        AshSurface.Ported.TaskMetadata |> Ash.Resource.Info.public_attributes() |> length()

      keys = Regex.scan(~r/(?:^|[{,]\s)"?(\w+\??)"?: z\./, meta) |> length()
      assert keys == public
    end
  end

  describe "comprehensive field/argument mapping coverage" do
    test "all mapped names in TaskMetadata resource are handled consistently", %{meta: meta} do
      assert meta =~ "createdBy"
      assert meta =~ "isPublic"

      refute meta =~ "created_by?"
      refute meta =~ "is_public?"
    end
  end

  describe "Zod schemas for typed structs with mapped field names" do
    test "typed struct fields use mapped field names in action Zod schemas", %{update: update} do
      assert update =~ "stats:"
      assert update =~ "z.object({"

      stats = stats_section(update)
      assert stats =~ "completed:"
      assert stats =~ "isUrgent:"

      refute stats =~ "completed?:"
      refute stats =~ "is_urgent?:"
    end

    test "typed struct mapped fields have correct types", %{update: update} do
      stats = stats_section(update)
      assert stats =~ "completed: z.boolean()"
      assert stats =~ "isUrgent: z.boolean()"
      # reference spelling `totalCount` / `averageDuration`: Ash names verbatim here (w3-15)
      assert stats =~ "total_count: z.number().int()"
      assert stats =~ "average_duration: z.number()"
    end

    test "typed struct nullable fields wrap with .nullable().optional()", %{update: update} do
      stats = stats_section(update)
      assert stats =~ "total_count: z.number().int().nullable().optional()"
      assert stats =~ "isUrgent: z.boolean().nullable().optional()"
      refute stats =~ "is_urgent?"
    end

    test "typed struct fields with allow_nil? true wrap with .nullable().optional()", %{
      update: update
    } do
      stats = stats_section(update)
      assert stats =~ "completed: z.boolean().nullable().optional()"
      refute stats =~ "completed?:"
      assert stats =~ "average_duration: z.number().nullable().optional()"
    end

    test "typed struct in nullable action accept wraps with .nullable().optional()", %{
      update: update,
      art: art
    } do
      assert update =~ "stats: z.object({"
      assert update =~ "}).strict().nullable().optional()"

      assert [true, true, false] ==
               E.node_accepts(art, [
                 {"Task_update_schema", %{"title" => "t"}},
                 {"Task_update_schema", %{"title" => "t", "stats" => nil}},
                 {"Task_update_schema", %{"title" => "t", "stats" => %{"isUrgent" => "yes"}}}
               ])
    end

    test "all typed struct fields use consistent mapped names", %{update: update} do
      stats = stats_section(update)
      assert stats =~ "completed:"
      assert stats =~ "isUrgent:"
      assert stats =~ "total_count:"
      assert stats =~ "average_duration:"

      refute stats =~ "completed?:"
      refute stats =~ "is_urgent?:"
    end
  end

  defp stats_section(update), do: update |> String.split("stats: ") |> Enum.at(1)

  # F1-fieldwire: resource-level `field_names` / `argument_names` reach the action input Zod keys
  # (Task: `archived?` -> `isArchived`; `mark_completed`: `is_task_completed_now?` -> `isCompleted`).
  describe "resource field_names / argument_names in action input Zod keys" do
    test "001 update: includes mapped field names for accepts", %{update: update, art: art} do
      assert update =~ "isArchived: z.boolean()"
      refute update =~ "archived?"
      assert update =~ "title: z.string()"

      assert [true, false] ==
               E.node_accepts(art, [
                 {"Task_update_schema", %{"isArchived" => true}},
                 {"Task_update_schema", %{"isArchived" => "yes"}}
               ])
    end

    test "002 update: optional fields are marked with .optional()", %{update: update} do
      # `archived?` is non-nullable but defaulted, so it is omittable on update
      assert update =~ "isArchived: z.boolean().optional()"
      refute update =~ "archived?"
    end

    test "003 arguments: includes mapped argument names", %{mark: mark, art: art} do
      assert mark =~ "isCompleted: z.boolean()"
      refute mark =~ "is_task_completed_now?"

      assert [true, false] ==
               E.node_accepts(art, [
                 {"Task_mark_completed_schema", %{"isCompleted" => true}},
                 {"Task_mark_completed_schema", %{"is_task_completed_now?" => true}}
               ])
    end

    test "004 arguments: required arguments are not marked optional", %{mark: mark, art: art} do
      assert mark =~ "isCompleted: z.boolean()"
      refute mark =~ "isCompleted: z.boolean().optional()"
      assert [false] == E.node_accepts(art, [{"Task_mark_completed_schema", %{}}])
    end

    test "005 integration: all Task action schemas use consistent field/argument mappings", %{
      create: create,
      update: update,
      mark: mark
    } do
      for block <- [create, update, mark] do
        refute block =~ "archived?"
        refute block =~ "is_task_completed_now?"
      end
    end

    test "006 integration: schemas match the TypeScript client expectation (isArchived)", %{
      update: update
    } do
      assert update =~ "isArchived"
      refute update =~ "archived?"
    end

    test "007 edge cases: schemas handle mixed mapped and unmapped fields", %{update: update} do
      assert update =~ "title:"
      assert update =~ "isArchived:"
      refute update =~ "archived?"
    end

    test "008 type correctness: boolean fields with mapped names generate z.boolean()", %{
      update: update
    } do
      assert Zod.line!(update, "isArchived") =~ "isArchived: z.boolean()"
      refute update =~ "archived?"
    end

    test "009 comprehensive: all mapped names in Task and TaskMetadata are consistent", %{
      update: update,
      mark: mark,
      meta: meta
    } do
      assert update =~ "isArchived"
      assert mark =~ "isCompleted"
      assert meta =~ "createdBy"
      assert meta =~ "isPublic"
      refute update =~ "archived?"
      refute mark =~ "is_task_completed_now?"
      refute meta =~ "created_by?"
      refute meta =~ "is_public?"
    end

    test "010 comprehensive: validation error schemas use mapped field names" do
      alias AshSurface.Compiler.{TypeFacts, ValidationErrorSchema}

      definition = TypeFacts.analyze(AshSurface.Ported.TaskMetadata, []).definition

      {:ok, error_schema} =
        ValidationErrorSchema.render(definition,
          resources: TypeFacts.embedded_resources([definition])
        )

      assert error_schema =~ "createdBy"
      assert error_schema =~ "isPublic"
      refute error_schema =~ "created_by?"
      refute error_schema =~ "is_public?"
    end
  end
end
