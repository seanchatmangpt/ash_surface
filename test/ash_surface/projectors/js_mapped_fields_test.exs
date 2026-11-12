defmodule AshSurface.Projectors.JSMappedFieldsTest do
  @moduledoc """
  w3-15: port of the applicable ash_typescript zod_mapped_fields_test cases:
  mapped/exposed field names appear as object keys in emitted schemas,
  non-identifier keys are quoted, output is deterministic, artifact executes.
  The real-resource cases run on the wave3-05 MappedNames.Gadget fixture; the key-ordering
  and quoting edge cases below stay synthetic definitions.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{IR, Compiler.EmbeddedSchema, Compiler.RecordSchema, Projectors.JS}
  alias AshSurface.ZodFixtures.MappedNames.Gadget

  @root Path.expand("../../..", __DIR__)
  @tmp Path.join(System.tmp_dir!(), "js_mapped_fields_cn")

  defp f(name, type, extra \\ %{}), do: Map.merge(%{"name" => name, "type" => type}, extra)
  defp s, do: %{"kind" => "string"}
  defp b, do: %{"kind" => "boolean"}

  defp typed_map(fields),
    do: %{"type" => %{"kind" => "typed_map", "fields" => fields}}

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(Path.join(@tmp, "node_modules"))
    File.ln_s!(Path.join(@root, "node_modules/zod"), Path.join(@tmp, "node_modules/zod"))
    on_exit(fn -> File.rm_rf!(@tmp) end)
    :ok
  end

  test "mapped names (isArchived, isCompleted) are keys; unmapped internal names absent" do
    {:ok, zod} =
      EmbeddedSchema.render(
        typed_map([
          f("title", s()),
          f("isArchived", b(), %{"omittable" => true}),
          f("isCompleted", b())
        ])
      )

    assert zod =~ "title: z.string()"
    assert zod =~ "isArchived: z.boolean().optional()"
    assert zod =~ "isCompleted: z.boolean()"
    refute zod =~ "archived?"
    refute zod =~ "completed?"
    refute zod =~ "isCompleted: z.boolean().optional()"
  end

  test "non-identifier keys are quoted, identifier-safe keys are bare; ?-names keep the ? (quoted)" do
    {:ok, zod} =
      EmbeddedSchema.render(
        typed_map([f("is_active?", b()), f("address-1", s()), f("line2Text", s()), f("1st", s())])
      )

    # RBY re-pin (reference parity, RBS): FieldName.clean/1 keeps a trailing `?`
    # (~/ash_typescript helpers.ex:25-30,73 snake_to_camel_case never strips it), so the camelized
    # key is `isActive?` -- not an identifier, hence quoted. A mapped name ("isActive") wins verbatim
    # (first test); an unmapped `?` name is refused upstream by the reference, never silently stripped.
    assert zod =~ ~s|"isActive?": z.boolean()|
    refute zod =~ "isActive: z.boolean()"
    refute zod =~ "is_active?"
    assert zod =~ ~s|"address-1": z.string()|
    assert zod =~ ~s|"1st": z.string()|
    assert zod =~ "line2Text: z.string()"
  end

  test "nullable + optional ordering and strict object structure" do
    {:ok, zod} =
      EmbeddedSchema.render(
        typed_map([f("note", s(), %{"allow_nil?" => true, "omittable" => true})])
      )

    assert zod =~ ~r/^z\.object\(\{ .* \}\)\.strict\(\)$/
    assert zod =~ "note: z.string().nullable().optional()"
  end

  test "map-form fields are emitted sorted by name; list-form keeps declared order" do
    m = %{"zeta" => %{"type" => s()}, "alpha" => %{"type" => s()}}
    {:ok, a} = EmbeddedSchema.render(%{"type" => %{"kind" => "typed_map", "fields" => m}})
    assert a =~ ~r/alpha:.*zeta:/
    {:ok, l} = EmbeddedSchema.render(typed_map([f("zeta", s()), f("alpha", s())]))
    assert l =~ ~r/zeta:.*alpha:/
  end

  test "deterministic across repeated renders" do
    d = typed_map([f("is_active?", b()), f("isReady", b()), f("slot1Name", s())])
    assert EmbeddedSchema.render(d) == EmbeddedSchema.render(d)
  end

  test "real Gadget fixture: ?-names keep the ? (quoted), digit names are identifier-safe, nested too" do
    assert {:ok, program} = RecordSchema.render(Gadget)
    zod = program.expression
    # RBY re-pin: Gadget has no typescript_field_names, so `?` is kept (reference helpers.ex:25-30,73)
    assert zod =~ ~s|"isActive?": z.boolean()|
    assert zod =~ "address1: z.string()"
    assert zod =~ "line2Text: z.string()"
    assert zod =~ ~s|"enabled?": z.boolean()|
    assert zod =~ "retry3Count: z.number()"
    assert zod =~ "slot1Name:"
    refute zod =~ "is_active?"
    refute zod =~ "address_1"
    assert RecordSchema.render(Gadget) == {:ok, program}
  end

  test "real Gadget record schema parses real payloads under node" do
    assert {:ok, program} = RecordSchema.render(Gadget)
    zod = EmbeddedSchema.declarations_source(program) <>
      "export const Gadget_create_inputSchema = #{program.expression};\n\nexport const Gadget_create_outputSchema = z.unknown();\n"

    ir =
      IR.new(
        ash: %IR.Ash{
          resource: "Gadget",
          action: :create,
          action_type: :create,
          policies: [%{"authorityBoundary" => "DO"}]
        },
        capability: %IR.Capability{capability_id: "gadget.write", receipt_required: true},
        schema: %IR.Schema{zod: zod}
      )

    assert {:ok, _, _} = JS.project_ir(ir, target_dir: @tmp)

    valid = %{
      id: "00000000-0000-4000-8000-000000000000",
      isActive?: true,
      address1: "a",
      line2Text: nil,
      plain: nil,
      settings: %{enabled?: true, retry3Count: 3, label: "x"}
    }

    script = Path.join(@tmp, "probe.mjs")

    File.write!(script, """
    import { dispatchIntent } from "./ash_surface_client.mjs";
    const ok = (input) => { try { dispatchIntent("Gadget.create", input); return true; } catch (e) { return e.code ?? String(e); } };
    const valid = #{Jason.encode!(valid)};
    const out = {
      valid: ok(valid),
      wrongType: ok({ ...valid, "isActive?": "yes" }),
      nestedWrong: ok({ ...valid, settings: { ...valid.settings, retry3Count: "3" } }),
    };
    console.log(JSON.stringify(out));
    """)

    {out, status} = System.cmd("node", [script], stderr_to_stdout: true, cd: @tmp)
    assert status == 0, out

    assert %{"valid" => true, "wrongType" => "INPUT_VALIDATION_FAILED", "nestedWrong" => "INPUT_VALIDATION_FAILED"} =
             out |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()
  end

  @tag skip:
         "ash_typescript ZodSchemaGenerator.generate_zod_schema/3 per-action accept/argument " <>
           "naming (createTaskZodSchema consts) has no ash_surface analogue pending w3-05 " <>
           "field-name wiring (FieldName not wired into compiler per wave3-02)"
  test "per-action accept/argument zod consts use mapped names" do
    flunk("unreachable")
  end
end
