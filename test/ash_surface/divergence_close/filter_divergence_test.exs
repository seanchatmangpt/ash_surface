defmodule AshSurface.DivergenceClose.FilterDivergenceTest do
  @moduledoc """
  F1-divclose court (register row Filters): `not` accepts the ash_typescript
  array shape AND the single-filter shape (strictly larger valid set; empty
  array still rejected), and related destinations accept nested and/or/not.
  Real node + real zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.ZodFixtures.Harness

  @inputs [
    %{"name" => "count", "type" => %{"kind" => "integer"}},
    %{
      "name" => "author",
      "type" => %{"kind" => "map"},
      "relationship" => %{
        "filter_inputs" => [
          %{"name" => "email", "type" => %{"kind" => "string"}},
          %{"name" => "age", "type" => %{"kind" => "integer"}}
        ]
      }
    }
  ]

  defp eval(expr, payloads) do
    dir = Path.join(System.tmp_dir!(), "dcf_#{AshSurface.TestTmp.suffix()}")
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

  defp eq(v), do: %{"field" => "count", "op" => "eq", "value" => v}

  test "not accepts single filter and non-empty array; rejects empty array and bad members" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)

    payloads = [
      %{"op" => "not", "value" => eq(1)},
      %{"op" => "not", "value" => [eq(1), eq(2)]},
      %{"op" => "not", "value" => []},
      %{"op" => "not", "value" => [%{"field" => "nope", "op" => "eq", "value" => 1}]},
      %{"op" => "not", "value" => "x"}
    ]

    assert eval(zod, payloads) == [true, true, false, false, false]
  end

  test "related destination accepts nested and/or/not, rejects unknown field inside" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)
    rel = fn v -> %{"field" => "author", "op" => "related", "value" => v} end
    email = %{"field" => "email", "op" => "eq", "value" => "a"}

    payloads = [
      rel.(email),
      rel.(%{"op" => "and", "value" => [email, %{"field" => "age", "op" => "gt", "value" => 3}]}),
      rel.(%{"op" => "or", "value" => [email]}),
      rel.(%{"op" => "not", "value" => email}),
      rel.(%{"op" => "not", "value" => [email]}),
      rel.(%{"op" => "and", "value" => [%{"field" => "nope", "op" => "eq", "value" => "a"}]}),
      rel.(%{"op" => "not", "value" => %{"field" => "nope", "op" => "eq", "value" => "a"}})
    ]

    assert eval(zod, payloads) == [true, true, true, true, true, false, false]
  end
end
