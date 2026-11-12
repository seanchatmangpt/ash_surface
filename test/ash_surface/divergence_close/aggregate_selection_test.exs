defmodule AshSurface.DivergenceClose.AggregateSelectionTest do
  @moduledoc """
  F1-divclose court (register row Aggregates, option a): ash_typescript selects
  aggregates as plain `fields` entries. ash_surface additionally keeps the
  `aggregates` name array. Real node + real zod, accept/reject agreement.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.SelectionSchema
  alias AshSurface.ZodFixtures.Harness

  defp eval(expr, payloads) do
    dir = Path.join(System.tmp_dir!(), "dc_#{AshSurface.TestTmp.suffix()}")
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

  test "aggregate names are selectable via fields (reference shape) and via aggregates" do
    aggs = [%{"name" => "comment_count", "kind" => :count}]
    {:ok, zod} = SelectionSchema.render_selection_schema(["title"], [], aggregates: aggs)

    payloads = [
      %{"fields" => ["title", "comment_count"]},
      %{"fields" => ["title"], "aggregates" => ["comment_count"]},
      %{"fields" => ["nope"]},
      %{"fields" => ["title"], "aggregates" => ["nope"]}
    ]

    assert eval(zod, payloads) == [true, true, false, false]
  end

  test "denied aggregate name is not selectable via fields" do
    aggs = [%{"name" => "comment_count", "kind" => :count}]

    {:ok, zod} =
      SelectionSchema.render_selection_schema(["title"], ["comment_count"], aggregates: aggs)

    assert eval(zod, [%{"fields" => ["comment_count"]}]) == [false]
  end
end
