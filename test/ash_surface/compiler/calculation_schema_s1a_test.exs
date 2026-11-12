defmodule AshSurface.Compiler.CalculationSchemaS1aTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.CalculationSchema
  alias AshSurface.ZodFixtures.Harness

  defp run_node(zod, cases) do
    Harness.zod!()
    dir = Path.join(System.tmp_dir!(), "cs_node_#{AshSurface.TestTmp.suffix()}")
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
      %{
        name: "a",
        arguments: [%{name: "sep", kind: :string, constraints: %{}, allow_nil?: true}],
        return_kind: :string
      },
      %{
        name: "b",
        arguments: [%{name: "n", kind: :integer, constraints: %{}, allow_nil?: true}],
        return_kind: :integer
      }
    ]
  end

  test "H1: a single calculation of several loads; unknown key fails (real zod)" do
    {:ok, zod} = CalculationSchema.render_calculation_schema(calcs())

    assert run_node(zod, [
             %{"a" => %{}},
             %{"b" => %{"args" => %{"n" => 1}}},
             %{},
             %{"a" => %{}, "b" => %{}},
             %{"zzz" => %{}}
           ]) == [true, true, true, true, false]
  end

  test "M5: calc A cannot accept calc B's args (real zod)" do
    {:ok, zod} = CalculationSchema.render_calculation_schema(calcs())

    assert run_node(zod, [
             %{"a" => %{"args" => %{"sep" => "x"}}},
             %{"a" => %{"args" => %{"n" => 1}}},
             %{"b" => %{"args" => %{"sep" => "x"}}}
           ]) == [true, false, false]
  end

  test "L7: hostile names cannot break out of JSDoc" do
    evil = "x */ import('//e') /*"

    {:ok, [line]} = CalculationSchema.render_aggregate_metadata([%{name: evil, kind: :count}])
    refute line =~ "*/"

    {:ok, [line2]} =
      CalculationSchema.render_aggregate_metadata([%{name: "n\nimport('//e')", kind: :count}])

    refute line2 =~ "\n"
  end
end
