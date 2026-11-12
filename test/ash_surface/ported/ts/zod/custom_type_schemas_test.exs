Code.ensure_loaded?(AshSurface.Ported.TS.Zod.Cases) ||
  Code.require_file("support/zod_cases.exs", __DIR__)

defmodule AshSurface.Ported.TS.Zod.CustomTypeSchemasTest do
  @moduledoc """
  Adaptation of ash_typescript `test/ts/zod/shouldPass/customTypeSchemas.ts` and
  `shouldFail/customTypeSchemas.ts`. The references import `createTodoZodSchema` /
  `createTaskZodSchema` from generated `ash_zod.ts`; here the emitted artifact schemas
  (`Todo.create`, `Task.create`) run under real node + real zod. The reference overrides name
  TypeScript-authored schemas (`CustomZodSchemas.objectId`, `NestedZodSchemas.geoPoint`);
  ash_surface takes inline Zod expressions in `zod_mapping_overrides` (scoped by `Cases`), so
  the same constraints (`min(3)`, `lat -90..90`, `lng -180..180`) are written inline. PriorityScore
  needs an explicit `z.number()` override here (see the loud gap in
  `constraint_validation_gap_test.exs`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.Zod.Cases
  alias AshSurface.ZodFixtures.Harness

  @uuid Cases.uuid()
  @todo %{"title" => "Custom type test", "user_id" => @uuid}

  @pass [
    {"testColorPaletteObjectAccepted", "Todo.create",
     Map.put(@todo, "color_palette", %{
       "primary" => "#fff",
       "secondary" => "#000",
       "accent" => "#f00"
     })},
    {"testPriorityScoreNumberAccepted", "Todo.create", Map.put(@todo, "priority_score", 42)},
    {"testOverriddenCustomIdAccepted", "Task.create", %{"title" => "T", "custom_id" => "abc123"}},
    {"testOverriddenGeoPointAccepted", "Task.create",
     %{"title" => "Oslo", "geo_point" => %{"lat" => 59.91, "lng" => 10.75}}}
  ]

  @fail [
    {"testPriorityScoreStringRejected", "Todo.create", Map.put(@todo, "priority_score", "42"),
     "priority_score: invalid_type"},
    {"testOverriddenCustomIdTooShort", "Task.create", %{"title" => "T", "custom_id" => "ab"},
     "custom_id: too_small"},
    {"testOverriddenGeoPointOutOfRange", "Task.create",
     %{"title" => "Nowhere", "geo_point" => %{"lat" => 999, "lng" => 10.75}},
     "geo_point.lat: too_big"},
    {"testOverriddenGeoPointMissingField", "Task.create",
     %{"title" => "Partial", "geo_point" => %{"lat" => 59.91}}, "geo_point.lng: invalid_type"}
  ]

  setup_all do
    ts_dir = Cases.workspace!()
    on_exit(fn -> Harness.cleanup!(ts_dir) end)

    cases =
      for({n, id, p} <- @pass, do: %{label: n, id: id, payload: p}) ++
        for {n, id, p, _} <- @fail, do: %{label: n, id: id, payload: p}

    round_trip = %{
      label: "round-trip",
      js:
        ~S'const t = S["Todo.create"].parse({title:"t", user_id:"' <>
          @uuid <>
          ~S'", color_palette:{primary:"#fff"}, priority_score: 42}); const k = S["Task.create"].parse({title:"T", custom_id:"abc123", geo_point:{lat:59.91,lng:10.75}}); return [t.color_palette.primary, t.priority_score, k.custom_id, k.geo_point.lat, k.geo_point.lng];'
    }

    results = Cases.run!(ts_dir, cases ++ [round_trip]) |> Map.new(&{&1["label"], &1})
    %{results: results}
  end

  for {name, _, _} <- @pass do
    test "pass #{name}", %{results: results} do
      r = Map.fetch!(results, unquote(name))
      assert r["success"] == true, inspect(r["issues"])
    end
  end

  test "pass: parsed values round-trip through validation (palette, score, custom id, geo point)",
       %{results: results} do
    assert results["round-trip"]["value"] == ["#fff", 42, "abc123", 59.91, 10.75]
  end

  for {name, _, _, issue} <- @fail do
    test "fail #{name}", %{results: results} do
      r = Map.fetch!(results, unquote(name))
      assert r["success"] == false
      assert unquote(issue) in r["issues"], inspect(r["issues"])
    end
  end
end
