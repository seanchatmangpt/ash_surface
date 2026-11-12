defmodule AshSurface.Compiler.CalculationSchemaShorthandTest do
  @moduledoc """
  F1-shorthand: bare-array calculation selection (`self: ["id"]`, ash_typescript parity),
  executed under real node + zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.CalculationSchema
  alias AshSurface.ZodFixtures.Harness

  defp run_node(zod, cases) do
    Harness.zod!()
    dir = Path.join(System.tmp_dir!(), "cs_sh_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "t.mjs"), """
    import { z } from "zod";
    const schema = #{zod};
    const cases = #{Jason.encode!(cases)};
    process.stdout.write(JSON.stringify(cases.map(c => schema.safeParse(c).success)));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["t.mjs"], dir)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp calcs do
    [
      %{name: "self", arguments: [], return_kind: :map, fields: ["id", "title"]},
      %{
        name: "needs",
        arguments: [%{name: "prefix", kind: :string, constraints: %{}, allow_nil?: false}],
        return_kind: :map,
        fields: ["id", "title"]
      }
    ]
  end

  test "shorthand accepted without required args; rejected with them; strictness preserved" do
    {:ok, zod} = CalculationSchema.render_calculation_schema(calcs())

    assert run_node(zod, [
             %{"self" => ["id", "title"]},
             %{"self" => ["nope"]},
             %{"self" => %{"args" => %{}, "fields" => ["id"]}},
             %{"self" => %{"args" => %{}, "extra" => 1}},
             %{"needs" => ["id"]},
             %{"needs" => %{"args" => %{"prefix" => "x"}, "fields" => ["id"]}},
             %{"zzz" => ["id"]}
           ]) == [true, false, true, false, false, true, false]
  end
end
