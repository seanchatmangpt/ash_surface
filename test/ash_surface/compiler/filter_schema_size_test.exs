defmodule AshSurface.Compiler.FilterSchemaSizeTest do
  @moduledoc "Size bound, ZodGuard admission, real zod behavior, and L5 input hygiene."
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Harness

  # Real node+zod subprocess and 600-relationship render: default 60s is exceeded under load.
  @moduletag timeout: 180_000

  @cap 1_000_000

  defp scalar(i), do: %{"name" => "f#{i}", "type" => %{"kind" => "string"}}

  defp dest, do: for(i <- 1..10, do: %{"name" => "d#{i}", "type" => %{"kind" => "string"}})

  defp fixture do
    scalars = for i <- 1..10, do: scalar(i)

    rels =
      for r <- 1..5 do
        %{
          "name" => "rel#{r}",
          "type" => %{"kind" => "map"},
          "relationship" => %{"filter_inputs" => dest()}
        }
      end

    scalars ++ rels
  end

  defp await_task(task), do: Task.await(task, 10_000)

  test "5-relationship fixture stays under 1MB and the guard admits it in bounded time" do
    {:ok, zod} = FilterSchema.render_filter_schema(fixture())
    assert byte_size(zod) <= @cap

    task = Task.async(fn -> ZodGuard.admit(zod) end)
    assert {:ok, :expression, _} = await_task(task)
  end

  test "oversize output is a typed error" do
    big =
      for r <- 1..600 do
        %{
          "name" => "rel#{r}",
          "type" => %{"kind" => "map"},
          "relationship" => %{"filter_inputs" => dest()}
        }
      end

    result = FilterSchema.render_filter_schema(big, max_depth: 3)
    assert match?({:error, {:filter_too_large, _, @cap}}, result)
    {:error, {:filter_too_large, bytes, _}} = result
    assert bytes > @cap
  end

  test "real zod accepts legal nested filter and rejects unknown field" do
    {:ok, zod} = FilterSchema.render_filter_schema(fixture())
    dir = Path.join(System.tmp_dir!(), "fls_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()

    File.write!(Path.join(dir, "s.mjs"), """
    import { z } from "zod";
    const s = #{zod};
    const ps = [
      {op: "and", value: [{field: "f1", op: "eq", value: "x"}, {op: "not", value: {field: "rel1", op: "related", value: {field: "d1", op: "eq", value: "y"}}}]},
      {field: "nope", op: "eq", value: "x"}
    ];
    const rs = ps.map((p) => s.safeParse(p));
    console.log(JSON.stringify(rs.map((r) => r.success)));
    console.error(JSON.stringify(rs.map((r) => (r.success ? null : r.error.issues))));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["s.mjs"], dir)
    File.rm_rf!(dir)
    lines = String.split(out, "\n", trim: true)

    verdicts =
      Enum.find(lines, &String.starts_with?(&1, "[true")) ||
        Enum.find(lines, &String.starts_with?(&1, "[false"))

    assert [true, false] == Jason.decode!(verdicts || "null"),
           "zod verdicts for [legal nested, unknown field] unexpected; node output (zod issues): #{out}"
  end

  describe "input hygiene" do
    test "atom kind accepted" do
      assert {:ok, _} = FilterSchema.render_filter_schema([%{name: "a", type: %{kind: :string}}])
    end

    test "array items read from type.items" do
      {:ok, z} =
        FilterSchema.render_filter_schema(
          [%{"name" => "t", "type" => %{"kind" => "array", "items" => %{"kind" => "integer"}}}],
          max_depth: 0
        )

      assert z =~ "z.number()"
    end

    test "unmapped operators are a typed error" do
      assert {:error, {:filter_input_unmapped_operators, "a", ["bogus"]}} =
               FilterSchema.render_filter_schema([
                 %{"name" => "a", "type" => %{"kind" => "string"}, "operators" => ["eq", "bogus"]}
               ])
    end

    test "related injected via operators is refused" do
      assert {:error, {:filter_input_related_operator, "a"}} =
               FilterSchema.render_filter_schema([
                 %{"name" => "a", "type" => %{"kind" => "string"}, "operators" => ["related"]}
               ])
    end

    test "non-map destination entries are a typed error" do
      assert {:error, {:filter_input_malformed, _}} =
               FilterSchema.render_filter_schema([
                 %{
                   "name" => "r",
                   "type" => %{"kind" => "map"},
                   "relationship" => %{"filter_inputs" => ["x"]}
                 }
               ])
    end
  end
end
