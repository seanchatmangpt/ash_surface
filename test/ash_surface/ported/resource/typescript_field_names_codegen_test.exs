defmodule AshSurface.Ported.Resource.TypescriptFieldNamesCodegenTest do
  @moduledoc """
  Adaptation of ash_typescript `resource/typescript_field_names_codegen_test.exs`.

  The reference asserts generated TypeScript text and Zod text for a NewType whose
  `typescript_field_names/0` callback remaps `field_1`, `is_active?`, `line_2`. ash_surface
  emits no `.ts`/`.d.ts` (README), so the TS-text test becomes an assertion on the projected
  field-name table of the type facts, and the Zod test asserts the emitted Zod text plus
  accept/reject cases executed under node with real zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{EmbeddedSchema, TypeFacts}

  defmodule Metadata do
    use Ash.Type.NewType,
      subtype_of: :map,
      constraints: [
        fields: [
          field_1: [type: :string, allow_nil?: false],
          is_active?: [type: :boolean, allow_nil?: false],
          line_2: [type: :string, allow_nil?: true]
        ]
      ]

    def typescript_field_names do
      [field_1: "field1", is_active?: "isActive", line_2: "line2"]
    end
  end

  defmodule MapFieldResource do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    surface do
      type_name("MapFieldResource")
    end

    attributes do
      uuid_primary_key(:id)

      attribute :metadata, AshSurface.Ported.Resource.TypescriptFieldNamesCodegenTest.Metadata do
        public?(true)
      end
    end
  end

  defp definition do
    attr = Ash.Resource.Info.attribute(MapFieldResource, :metadata)
    TypeFacts.analyze(attr.type, attr.constraints).definition
  end

  defp node_parse(zod, value) do
    js =
      "import {z} from 'zod'; const s = #{zod}; " <>
        "const r = s.safeParse(JSON.parse(process.argv[1])); process.stdout.write(String(r.success));"

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", js, Jason.encode!(value)],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    out == "true"
  end

  describe "NewType with typescript_field_names callback" do
    test "type facts carry the mapped field names (adapts the generated-TS text test)" do
      assert %{"type" => %{"kind" => "map", "field_names" => names, "fields" => fields}} =
               definition()

      assert names == %{"field_1" => "field1", "is_active?" => "isActive", "line_2" => "line2"}
      assert Enum.map(fields, & &1["name"]) == ["field_1", "is_active?", "line_2"]
      assert AshSurface.VerifierChecker.check_all_verifiers([MapFieldResource]) == :ok
    end

    test "generates Zod schemas with mapped field names" do
      assert {:ok, zod} = EmbeddedSchema.render(definition())

      assert zod =~ "field1: z.string()"
      assert zod =~ "isActive: z.boolean()"
      assert zod =~ "line2: z.string()"
      assert zod =~ ".nullable()"

      refute zod =~ "field_1"
      refute zod =~ "is_active"
      refute zod =~ "line_2"

      # Executed under real zod: mapped keys are the wire keys.
      assert node_parse(zod, %{field1: "a", isActive: true, line2: nil})
      assert node_parse(zod, %{field1: "a", isActive: false, line2: "x"})
      refute node_parse(zod, %{field_1: "a", is_active?: true, line_2: nil})
      refute node_parse(zod, %{field1: "a", line2: "x"})
    end
  end
end
