defmodule AshSurface.DivergenceClose.FilterFunctionsTest do
  @moduledoc """
  F1-divmap court: ash_typescript whitelists the Ash predicate functions
  contains / string_starts_with / string_ends_with / has as filter operators
  (codegen/filter_types.ex). A capability entry's `"functions"` becomes
  operators here. Real node + real zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.ZodFixtures.Harness

  defp eval(expr, payloads) do
    dir = Path.join(System.tmp_dir!(), "dff_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()

    File.write!(Path.join(dir, "s.mjs"), """
    import { z } from "zod";
    const payloads = #{Jason.encode!(payloads)};
    const s = #{expr};
    console.log(JSON.stringify(payloads.map((p) => s.safeParse(p).success)));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["s.mjs"], dir)
    File.rm_rf!(dir)
    out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
  end

  test "split_capabilities maps whitelisted functions to operators, keeps metadata" do
    caps =
      FilterSchema.split_capabilities(%{
        "operators" => ["=="],
        "functions" => ["contains", "string_starts_with", "string_ends_with", "has", "other"]
      })

    assert caps.operators == ["contains", "ends_with", "eq", "has", "starts_with"]

    assert caps.functions == [
             "contains",
             "has",
             "other",
             "string_ends_with",
             "string_starts_with"
           ]
  end

  test "function-derived operators validate under node+zod; unlisted ones are rejected" do
    inputs = [
      %{
        "name" => "title",
        "type" => %{"kind" => "string"},
        "operators" => ["=="],
        "functions" => ["contains", "string_starts_with"]
      }
    ]

    {:ok, zod} = FilterSchema.render_filter_schema(inputs)
    f = fn op, v -> %{"field" => "title", "op" => op, "value" => v} end

    assert eval(zod, [
             f.("eq", "a"),
             f.("contains", "a"),
             f.("starts_with", "a"),
             f.("ends_with", "a")
           ]) ==
             [true, true, true, false]
  end
end
