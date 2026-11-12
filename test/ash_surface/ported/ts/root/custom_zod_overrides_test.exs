defmodule AshSurface.Ported.TS.Root.CustomZodOverridesTest do
  @moduledoc """
  Adapts ash_typescript `test/ts/custom/nestedZodSchemas.ts`, `customZodSchemas.ts` and
  `customTypes.ts`. The reference files are user-supplied Zod schemas (`objectId`, `geoPoint`)
  that a `zod_mapping_overrides` entry swaps in for a custom type, plus the TS shapes of
  custom types. Here the override reaches the real `ZodType.fragment/2`, and the resulting
  expression runs under node with real zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType
  alias AshSurface.ZodFixtures.HarnessExt

  defp check(expr, cases) do
    cases =
      Enum.with_index(cases, fn {expect, payload}, i ->
        %{label: "c#{i}", expect: expect, payload: payload}
      end)

    for r <- HarnessExt.run_fragment!(expr, cases) do
      assert r["success"] == r["expect"], "#{r["label"]} #{expr}: #{inspect(r["issues"])}"
    end
  end

  defp custom(module), do: %{"type" => %{"kind" => "unknown", "module" => module}}

  test "customZodSchemas.ts objectId: module override replaces the generated schema" do
    expr =
      ZodType.fragment(custom("MyApp.ObjectId"),
        overrides: %{"MyApp.ObjectId" => "z.string().min(3)"}
      )

    assert expr =~ "z.string().min(3)"
    check(expr, [{true, "abc"}, {true, "abcdef"}, {false, "ab"}, {false, 12}])
  end

  test "without an override the module is not silently swapped for the user schema" do
    refute ZodType.fragment(custom("MyApp.ObjectId"), overrides: %{}) =~ "min(3)"
  end

  test "nestedZodSchemas.ts geoPoint: a nested override validates its bounded members" do
    geo =
      "z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) })"

    expr = ZodType.fragment(custom("MyApp.GeoPoint"), overrides: %{"MyApp.GeoPoint" => geo})

    check(expr, [
      {true, %{lat: 45, lng: 90}},
      {true, %{lat: -90, lng: 180}},
      {false, %{lat: 91, lng: 0}},
      {false, %{lat: 0, lng: -181}},
      {false, %{lat: 0}}
    ])
  end

  test "an override applies to array elements of the custom type" do
    def = %{
      "type" => %{
        "kind" => "array",
        "items" => %{"kind" => "unknown", "module" => "MyApp.ObjectId"}
      }
    }

    expr = ZodType.fragment(def, overrides: %{"MyApp.ObjectId" => "z.string().min(3)"})
    check(expr, [{true, ["abc", "abcd"]}, {false, ["abc", "x"]}, {true, []}])
  end

  test "customTypes.ts Percentage/PriorityScore (integer storage) validate as numbers" do
    expr = ZodType.fragment(%{"type" => %{"kind" => "integer"}})
    check(expr, [{true, 42}, {false, "42"}])
  end

  test "customTypes.ts ColorPalette/GeoPoint (map storage) validate as open records" do
    expr = ZodType.fragment(%{"type" => %{"kind" => "map"}})

    check(expr, [
      {true, %{primary: "#fff", secondary: "#000", accent: "#f00"}},
      {false, "red"},
      {false, 3}
    ])
  end

  test "customTypes.ts per-field ValidationErrors types: constrained map exposes per-field issues" do
    definition =
      AshSurface.Compiler.TypeFacts.analyze(Ash.Type.Map,
        fields: [
          primary: [type: :string, allow_nil?: false],
          secondary: [type: :string, allow_nil?: false]
        ]
      ).definition

    {:ok, expr} = AshSurface.Compiler.EmbeddedSchema.render(definition)

    [bad] =
      HarnessExt.run_fragment!(expr, [
        %{label: "x", expect: false, payload: %{primary: 1, secondary: "b"}}
      ])

    assert bad["success"] == false
    assert Enum.any?(bad["issues"], &String.starts_with?(&1, "primary:"))
    refute Enum.any?(bad["issues"], &String.starts_with?(&1, "secondary:"))
  end

  test "the override expression is emitted verbatim and only for the overridden module" do
    expr =
      ZodType.fragment(custom("MyApp.ObjectId"),
        overrides: %{"MyApp.ObjectId" => "z.string().min(3)", "MyApp.Other" => "z.number()"}
      )

    assert expr == "z.string().min(3)"
  end

  test "an override for a different module does not apply" do
    expr =
      ZodType.fragment(custom("MyApp.ObjectId"),
        overrides: %{"MyApp.Other" => "z.string().min(3)"}
      )

    refute expr =~ "min(3)"
    check(expr, [{true, "ab"}, {true, 5}])
  end

  test "an override inside an array applies per element and rejects non-arrays" do
    def = %{
      "type" => %{
        "kind" => "array",
        "items" => %{"kind" => "unknown", "module" => "MyApp.ObjectId"}
      }
    }

    expr = ZodType.fragment(def, overrides: %{"MyApp.ObjectId" => "z.string().min(3)"})
    check(expr, [{false, "abc"}, {false, nil}, {false, [1]}, {true, ["abc"]}])
  end

  test "integer kind rejects floats (int constraint) and the map kind rejects arrays" do
    check(ZodType.fragment(%{"type" => %{"kind" => "integer"}}), [{true, 3}, {false, 3.5}])
    check(ZodType.fragment(%{"type" => %{"kind" => "map"}}), [{true, %{}}, {false, [1]}])
  end

  test "zod_mapping_overrides keyed by a builtin kind take precedence over the base table" do
    expr =
      ZodType.fragment(%{"type" => %{"kind" => "string"}},
        overrides: %{"string" => "z.string().min(9)"}
      )

    assert expr == "z.string().min(9)"
    check(expr, [{true, "123456789"}, {false, "12345678"}])
  end

  test "term, file and function kinds map to z.any() and accept anything under zod" do
    for kind <- ~w(term file function) do
      expr = ZodType.fragment(%{"type" => %{"kind" => kind}})
      assert expr == "z.any()"
      check(expr, [{true, 1}, {true, "s"}, {true, %{a: 1}}])
    end
  end
end
