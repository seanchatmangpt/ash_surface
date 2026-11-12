defmodule AshSurface.TS.ZodRuntimeFeaturesTest do
  @moduledoc """
  One case file per feature (`test/ts/cases/<feature>.json`), executed under real
  node + real zod. Expressions come from the real Phase-A renderers (Query, Filter,
  Relationship, Calculation, Identity, Union, Error schemas); `constraints` runs the
  real emitted artifact for the Constraints fixture domain. No doubles.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{
    CalculationSchema,
    ErrorSchema,
    FilterSchema,
    IdentitySchema,
    QuerySchema,
    RelationshipSchema,
    UnionSchema
  }

  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.{Constraints, Harness, HarnessExt}

  @cases Path.expand("../../ts/cases", __DIR__)

  defp cases(feature),
    do: Path.join(@cases, feature <> ".json") |> File.read!() |> Jason.decode!()

  setup_all do
    ts_dir = Harness.workspace!("export const SCHEMAS = {};\n")
    on_exit(fn -> Harness.cleanup!(ts_dir) end)
    %{ts_dir: ts_dir, node: Harness.tool!("node")}
  end

  # Runs `expression` over `cases`; asserts each outcome and that both outcomes occur.
  defp check!(ctx, expression, cases, name) do
    assert {:ok, _, _} = admit(expression)
    input = Path.join(ctx.ts_dir, "in_#{name}_#{AshSurface.TestTmp.suffix()}.json")
    File.write!(input, Jason.encode!(%{expression: expression, cases: cases}))
    {out, status} = Harness.run(ctx.node, ["fragment_runner.mjs", input], ctx.ts_dir)
    assert status == 0, out
    results = Jason.decode!(out |> String.split("\n", trim: true) |> List.last())
    assert length(results) == length(cases)

    for r <- results do
      assert r["success"] == r["expect"],
             "#{name}/#{r["label"]}: expected #{r["expect"]} issues=#{inspect(r["issues"])}"
    end

    assert Enum.any?(results, & &1["success"]) and Enum.any?(results, &(!&1["success"])),
           "#{name}: cases must exercise both accept and reject"
  end

  defp admit(expr), do: ZodGuard.admit(expr)

  defp by_target(cases, t), do: Enum.filter(cases, &(&1["target"] == t))

  test "constraints: real emitted artifact (match \\d, allow_empty, items, enum, struct)" do
    ts_dir = Harness.workspace!(HarnessExt.artifact!(Constraints.Domain))

    try do
      {out, status} =
        Harness.run(
          Harness.tool!("node"),
          [
            "zod_runtime_runner.mjs",
            "generated/ash_surface_client.mjs",
            "cases/constraints.json"
          ],
          ts_dir
        )

      assert status == 0, out
      results = Jason.decode!(out)
      assert length(results) == length(cases("constraints"))

      for r <- results do
        assert r["success"] == (r["expect"] == "pass"),
               "#{r["label"]}: expected #{r["expect"]} issues=#{inspect(r["issues"])}"
      end
    after
      Harness.cleanup!(ts_dir)
    end
  end

  test "filters", ctx do
    {:ok, expr} =
      FilterSchema.render_filter_schema([
        %{"name" => "count", "type" => %{"kind" => "integer"}},
        %{"name" => "name", "type" => %{"kind" => "string"}}
      ])

    check!(ctx, expr, cases("filters"), "filters")
  end

  test "sort / page", ctx do
    cs = cases("sort_page")
    {:ok, sort} = QuerySchema.render_sort_schema(["a", "b"])

    {:ok, page} =
      QuerySchema.render_pagination_schema(%{offset?: true, keyset?: true, countable?: true})

    check!(ctx, sort, by_target(cs, "sort"), "sort")
    check!(ctx, page, by_target(cs, "page"), "page")
  end

  test "relationships load", ctx do
    {:ok, expr, _} =
      RelationshipSchema.render_load_schema([
        %{
          "name" => "comments",
          "destination" => "Comment",
          "cardinality" => "many",
          "primitive_fields" => ["body", "id"]
        }
      ])

    check!(ctx, expr, cases("relationships_load"), "relationships_load")
  end

  test "calculations", ctx do
    {:ok, expr} =
      CalculationSchema.render_calculation_schema([
        %{
          name: "full",
          arguments: [%{name: "sep", kind: :string, constraints: %{}}],
          return_kind: :string,
          fields: ["a", "b"]
        }
      ])

    check!(ctx, expr, cases("calculations"), "calculations")
  end

  test "identities", ctx do
    key = fn n, k -> %{"name" => n, "type" => %{"kind" => k}} end

    {:ok, map} =
      IdentitySchema.render_get_schema(
        [
          %{"name" => "email", "keys" => [key.("email", "string")]},
          %{"name" => "by_id", "keys" => [key.("id", "uuid")]}
        ],
        ["id"]
      )

    cs = cases("identities")

    for {name, expr} <- map do
      check!(ctx, expr, by_target(cs, name), "identity_" <> name)
    end

    # by_id (the primary key) is aliased to primary_key by IdentitySchema
    assert Enum.sort(Map.keys(map)) == ["email", "primary_key"]
  end

  test "errors union", ctx do
    check!(ctx, ErrorSchema.union(), cases("errors_union"), "errors_union")
  end

  test "unions", ctx do
    {:ok, expr} =
      UnionSchema.render_union_schema_admitted([
        %{tag: "s", kind: :string, constraints: %{}},
        %{tag: "i", kind: :integer, constraints: %{}}
      ])

    check!(ctx, expr, cases("unions"), "unions")
  end
end
