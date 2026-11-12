defmodule AshSurface.ZodTypeParityTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{Schema, ZodType}

  test "Schema, Expo-facing and ZodType agree on every kind (single source)" do
    for kind <- ZodType.kinds() do
      arg = %{"name" => "f", "type" => %{"kind" => kind}, "allow_nil?" => false}
      discovery = %{"actions" => [%{"id" => "R#a", "arguments" => [arg], "returns" => nil}]}
      {:ok, ir, _} = Schema.build(discovery)
      expected = ZodType.fragment(Map.delete(arg, "name"))
      assert ir["R#a"].zod =~ "  f: #{expected}"
    end
  end

  test "Expo's table is the shared table (no private copy)" do
    src = File.read!("lib/ash_surface/projector/expo.ex")
    assert src =~ "AshSurface.Compiler.ZodType.fragment"
    refute src =~ ~s|"decimal" => "z.number()"|
    refute File.read!("lib/ash_surface/compiler/schema.ex") =~ "@zod_kinds"
  end

  test "UnionSchema output is admitted and uses shared fragments" do
    {:ok, expr} =
      AshSurface.Compiler.UnionSchema.render_union_schema_admitted([
        %{tag: "a", kind: :uuid, constraints: %{}},
        %{tag: "b", kind: :string, constraints: %{"one_of" => ["y", "x"]}}
      ])

    assert expr =~ "z.guid()"
    assert expr =~ ~s|z.enum(["x", "y"])|
  end
end
