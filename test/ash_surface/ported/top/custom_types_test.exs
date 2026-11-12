Code.require_file("support/t1.exs", __DIR__)
Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.CustomTypesTest do
  @moduledoc """
  Port/adaptation of ash_typescript `custom_types_test.exs`. Ash.Type behaviour tests are ported
  verbatim against the shared fixtures. The reference's TypeScript-name assertions
  (`get_ts_type` -> `"CustomTypes.PriorityScore"`, `import * as CustomTypes`) become the ash_surface
  Zod projection: a custom `Ash.Type` has no structural Zod mapping and projects `z.unknown()`
  (a `NewType` projects its subtype), a module-keyed `zod_mapping_overrides` entry replaces it
  (executed under real node+zod), and the artifact imports only `zod` (no custom-type module).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{T1, T2, Todo}
  alias AshSurface.Ported.Todo.{ColorPalette, Percentage, PriorityScore}

  describe "custom type detection" do
    test "detects custom types using Ash.Type behaviour" do
      assert Spark.implements_behaviour?(PriorityScore, Ash.Type)
      # the real compiler classifies it as an unmapped custom kind
      assert AshSurface.Compiler.TypeFacts.kind(PriorityScore) == "unknown"
    end

    test "custom type has typescript_type_name/0 callback" do
      assert function_exported?(PriorityScore, :typescript_type_name, 0)
      assert PriorityScore.typescript_type_name() == "CustomTypes.PriorityScore"
      # ash_surface ignores the TS name and projects Zod
      assert T2.zod(PriorityScore) == "z.number().int()"
    end

    test "custom type has required Ash.Type callbacks" do
      assert function_exported?(PriorityScore, :cast_input, 2)
      assert function_exported?(PriorityScore, :cast_stored, 2)
      assert function_exported?(PriorityScore, :dump_to_native, 2)
      assert function_exported?(PriorityScore, :storage_type, 1)
      assert AshSurface.Compiler.TypeFacts.analyze(PriorityScore).definition["type"]["kind"] == "unknown"
    end

    test "complex custom type has typescript callbacks" do
      assert function_exported?(ColorPalette, :typescript_type_name, 0)
      assert ColorPalette.typescript_type_name() == "CustomTypes.ColorPalette"
      assert AshSurface.Compiler.TypeFacts.kind(ColorPalette) == "unknown"
      assert T2.zod(ColorPalette) == "z.record(z.string(), z.unknown())"
    end
  end

  describe "custom type functionality" do
    @score_zod "z.number().int().min(1).max(100)"

    # Ash-type verdict and the real Zod projection (via override) agree on integer payloads.
    defp assert_zod_agrees(values) do
      T2.with_env(:zod_mapping_overrides, [{PriorityScore, @score_zod}], fn ->
        assert {:ok, zod} = T2.node_eval(T2.zod(PriorityScore), values)
        ash = Enum.map(values, &match?({:ok, _}, PriorityScore.cast_input(&1, [])))
        assert zod == ash
      end)
    end

    test "PriorityScore casts valid integers" do
      assert {:ok, 50} = PriorityScore.cast_input(50, [])
      assert {:ok, 1} = PriorityScore.cast_input(1, [])
      assert {:ok, 100} = PriorityScore.cast_input(100, [])
      assert_zod_agrees([50, 1, 100])
    end

    test "PriorityScore casts valid string integers" do
      assert {:ok, 50} = PriorityScore.cast_input("50", [])
      assert {:ok, 1} = PriorityScore.cast_input("1", [])
      assert {:ok, 100} = PriorityScore.cast_input("100", [])
      # derived (un-overridden) Zod is integer-only: the wire form is a number, not a string
      assert {:ok, [false]} = T2.node_eval(T2.zod(PriorityScore), ["50"])
    end

    test "PriorityScore rejects invalid values" do
      assert {:error, _} = PriorityScore.cast_input(0, [])
      assert {:error, _} = PriorityScore.cast_input(101, [])
      assert {:error, _} = PriorityScore.cast_input("invalid", [])
      assert {:error, _} = PriorityScore.cast_input([], [])
      assert_zod_agrees([0, 101, 1.5, -3])
    end

    test "PriorityScore handles nil" do
      assert {:ok, nil} = PriorityScore.cast_input(nil, [])
      assert {:ok, nil} = PriorityScore.cast_stored(nil, [])
      assert {:ok, nil} = PriorityScore.dump_to_native(nil, [])
      # compiled create input: priority_score is nullable+optional, accepts null under real zod
      art = T1.artifact!()
      [create] = Regex.run(~r/export const Todo_create_schema = z\.object\(\{.*?\n\}\)/s, art)
      assert create =~ "priority_score: z.number().int().nullable().optional()"
    end
  end

  describe "Zod projection - custom types (reference: TypeScript type generation)" do
    test "custom types do not generate type aliases or definitions in the artifact" do
      art = T1.artifact!()
      refute art =~ "PriorityScore"
      refute art =~ "ColorPalette"
      refute art =~ "type PriorityScore = number;"

      # complex type no longer generates a definition (its primary/secondary/accent shape is absent)
      refute art =~ "secondary"
      refute art =~ "accent:"
    end

    test "zod fragment maps a custom type (derived z.number().int() by default, override replaces it)" do
      assert T2.zod(PriorityScore) == "z.number().int()"

      T2.with_env(
        :zod_mapping_overrides,
        [{PriorityScore, "z.number().int().min(1).max(100)"}],
        fn ->
          assert T2.zod(PriorityScore) == "z.number().int().min(1).max(100)"

          assert {:ok, [true, true, false, false, false]} =
                   T2.node_eval(T2.zod(PriorityScore), [1, 100, 0, 101, "x"])
        end
      )
    end

    test "custom type in array projects a Zod array of the element mapping" do
      assert T2.zod({:array, PriorityScore}) == "z.array(z.number().int())"

      T2.with_env(:zod_mapping_overrides, [{PriorityScore, "z.number().int()"}], fn ->
        assert T2.zod({:array, PriorityScore}) == "z.array(z.number().int())"
      end)
    end

    test "complex custom type with map storage projects z.record (shape lives in the type)" do
      assert T2.zod(ColorPalette) == "z.record(z.string(), z.unknown())"

      assert {:ok, %{primary: "a", secondary: "b", accent: "c"}} =
               ColorPalette.cast_input(%{primary: "a", secondary: "b", accent: "c"}, [])
    end

    test "complex custom type no longer generates a type definition (it is not inlined)" do
      art = T1.artifact!()
      refute art =~ "primary: z."
      refute art =~ "secondary: z."
    end
  end

  describe "resource schema generation with custom types (real zod)" do
    test "Todo includes priority_score with a custom type under its Ash name" do
      art = T1.artifact!()
      [create] = Regex.run(~r/export const Todo_create_schema = z\.object\(\{.*?\n\}\)/s, art)
      assert create =~ "priority_score: z.number().int().nullable().optional()"
      assert [true] == T1.node_accepts([{"Todo_read_sort_schema", "priority_score"}])
    end

    test "Todo includes color_palette with a complex custom type" do
      art = T1.artifact!()
      [create] = Regex.run(~r/export const Todo_create_schema = z\.object\(\{.*?\n\}\)/s, art)
      assert create =~ "color_palette: z.record(z.string(), z.unknown()).nullable().optional()"
      assert [true] == T1.node_accepts([{"Todo_read_sort_schema", "color_palette"}])
    end

    test "artifact imports only zod (no CustomTypes module import)" do
      art = T1.artifact!()
      assert art =~ ~s(import { z } from "zod";)
      refute art =~ "CustomTypes"
      assert Regex.scan(~r/^import /m, art) |> length() == 1
    end
  end

  describe "pipeline integration with custom types" do
    test "custom type values serialize through the Ash type (cast + dump round trip)" do
      assert {:ok, 77} = Ash.Type.cast_input(PriorityScore, 77, [])
      assert {:ok, 77} = Ash.Type.dump_to_native(PriorityScore, 77, [])
      assert {:error, _} = Ash.Type.cast_input(PriorityScore, 777, [])
    end

    test "field selection works with custom types (real RequestedFieldsProcessor)" do
      assert {:ok, {select, _load, template}} =
               AshSurface.Ported.RFP.process(Todo, :read, [:id, :priority_score, :color_palette])

      assert select == [:id, :priority_score, :color_palette]
      assert template == [:id, :priority_score, :color_palette]
    end
  end

  describe "NewType with typescript_type_name" do
    test "NewType wrapping :float is detected as a custom type" do
      assert Ash.Type.NewType.new_type?(Percentage)
      assert function_exported?(Percentage, :typescript_type_name, 0)
      assert Percentage.typescript_type_name() == "CustomTypes.Percentage"
    end

    test "zod fragment maps the NewType through its subtype (not a custom name)" do
      assert T2.zod(Percentage) == "z.number()"
    end

    test "NewType custom type in array projects an array of its subtype mapping" do
      assert T2.zod({:array, Percentage}) == "z.array(z.number())"
    end

    test "Todo includes percentage as a numeric filter/sort field (real zod)" do
      assert [true, false, true] ==
               T1.node_accepts([
                 {"Todo_read_filter_schema", %{field: "percentage", op: "gt", value: 0.5}},
                 {"Todo_read_filter_schema", %{field: "percentage", op: "gt", value: "x"}},
                 {"Todo_read_sort_schema", "percentage"}
               ])
    end

    test "full generation uses the NewType subtype mapping, not a custom type name" do
      art = T1.artifact!()
      assert art =~ "percentage: z.number()"
      refute art =~ "CustomTypes.Percentage"
    end
  end

  describe "artifact evaluates (reference: TypeScript compilation validation)" do
    test "generated module loads under real node and parses a custom-typed payload" do
      assert [true] ==
               T1.node_accepts([
                 {"Todo_read_filter_schema", %{field: "priority_score", op: "eq", value: 5}}
               ])
    end
  end
end
