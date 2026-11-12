defmodule AshSurface.Compiler.FilterSchemaExecutedTest do
  @moduledoc """
  Chicago court for `FilterSchema`: emitted strings run under real node with
  real zod (no doubles). Pins behaviors (accept/reject), never ZodType bytes.
  Includes the wave2-fl finding: a repeated-`op` discriminatedUnion throws.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Harness

  @inputs [
    %{"name" => "name", "type" => %{"kind" => "string"}, "allow_nil?" => true},
    %{"name" => "count", "type" => %{"kind" => "integer"}},
    %{"name" => "active", "type" => %{"kind" => "boolean"}},
    %{"name" => "due", "type" => %{"kind" => "date"}},
    %{"name" => "seen", "type" => %{"kind" => "utc_datetime"}},
    %{"name" => "status", "type" => %{"kind" => "atom"}},
    %{"name" => "nick", "type" => %{"kind" => "ci_string"}},
    %{"name" => "tags", "type" => %{"kind" => "array"}, "items" => %{"kind" => "integer"}},
    %{"name" => "any_tags", "type" => %{"kind" => "array"}},
    %{
      "name" => "author",
      "type" => %{"kind" => "map"},
      "relationship" => %{
        "filter_inputs" => [%{"name" => "email", "type" => %{"kind" => "string"}}]
      }
    }
  ]

  # Runs `expr` under node+zod against payloads; returns {:ok, [bool]} per
  # payload, or {:throw, message} when construction/parse throws.
  defp node_eval(expr, payloads) do
    dir = Path.join(System.tmp_dir!(), "fl_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()

    File.write!(Path.join(dir, "s.mjs"), """
    import { z } from "zod";
    const payloads = #{Jason.encode!(payloads)};
    try {
      const s = #{expr};
      console.log(JSON.stringify({ok: payloads.map((p) => s.safeParse(p).success)}));
    } catch (e) { console.log(JSON.stringify({throw: String(e.message)})); }
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["s.mjs"], dir)
    File.rm_rf!(dir)

    case Jason.decode!(out |> String.split("\n", trim: true) |> List.last()) do
      %{"ok" => oks} -> {:ok, oks}
      %{"throw" => msg} -> {:throw, msg}
    end
  end

  test "FINDING: discriminatedUnion on repeated op throws under real zod; z.union does not" do
    dd =
      ~s'z.discriminatedUnion("op", [z.object({field: z.enum(["a"]), op: z.literal("eq"), value: z.string()}), ' <>
        ~s'z.object({field: z.enum(["b"]), op: z.literal("eq"), value: z.number()})])'

    assert {:throw, msg} = node_eval(dd, [%{"field" => "a", "op" => "eq", "value" => "x"}])
    assert msg =~ "Duplicate discriminator"

    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)
    refute zod =~ "discriminatedUnion"
    assert {:ok, [true]} = node_eval(zod, [%{"field" => "count", "op" => "eq", "value" => 1}])
  end

  test "node-executed valid and invalid payloads across kinds, nesting and relationships" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs)
    assert {:ok, :expression, ^zod} = ZodGuard.admit(zod)

    valid = [
      %{"field" => "name", "op" => "contains", "value" => "a"},
      %{"field" => "name", "op" => "is_nil", "value" => true},
      %{"field" => "count", "op" => "gte", "value" => 3},
      %{"field" => "count", "op" => "in", "value" => [1, 2]},
      %{"field" => "active", "op" => "in", "value" => [true]},
      %{"field" => "due", "op" => "lt", "value" => "2026-01-02"},
      %{"field" => "seen", "op" => "gt", "value" => "2026-01-02T00:00:00Z"},
      %{"field" => "status", "op" => "eq", "value" => "open"},
      %{"field" => "nick", "op" => "lte", "value" => "zed"},
      %{"field" => "tags", "op" => "has", "value" => 4},
      %{"field" => "any_tags", "op" => "has_any", "value" => ["x", 1]},
      %{"op" => "and", "value" => [%{"field" => "count", "op" => "eq", "value" => 1}]},
      %{"op" => "not", "value" => [%{"field" => "count", "op" => "eq", "value" => 1}]},
      %{
        "op" => "not",
        "value" => %{"op" => "or", "value" => [%{"field" => "count", "op" => "lt", "value" => 9}]}
      },
      %{
        "field" => "author",
        "op" => "related",
        "value" => %{"field" => "email", "op" => "eq", "value" => "e"}
      }
    ]

    invalid = [
      %{"field" => "count", "op" => "eq", "value" => "x"},
      %{"field" => "count", "op" => "contains", "value" => 1},
      %{"field" => "active", "op" => "gt", "value" => true},
      %{"field" => "tags", "op" => "has", "value" => "str"},
      %{"field" => "nope", "op" => "eq", "value" => 1},
      %{"field" => "due", "op" => "eq", "value" => "not-a-date"},
      %{"op" => "and", "value" => %{"field" => "count", "op" => "eq", "value" => 1}},
      %{
        "field" => "author",
        "op" => "related",
        "value" => %{"field" => "count", "op" => "eq", "value" => 1}
      },
      %{"field" => "count", "op" => "is_nil", "value" => true}
    ]

    assert {:ok, oks} = node_eval(zod, valid ++ invalid)
    {v, i} = Enum.split(oks, length(valid))
    assert Enum.all?(v), "valid rejected: #{inspect(Enum.zip(valid, v))}"
    refute Enum.any?(i), "invalid accepted: #{inspect(Enum.zip(invalid, i))}"
  end

  test "depth cap: payload one level beyond max_depth is rejected, within is accepted" do
    leaf = %{"field" => "count", "op" => "eq", "value" => 1}

    wrap = fn payload, n ->
      Enum.reduce(1..n, payload, fn _, acc -> %{"op" => "and", "value" => [acc]} end)
    end

    {:ok, z1} = FilterSchema.render_filter_schema(@inputs, max_depth: 1)
    assert {:ok, [true, false]} = node_eval(z1, [wrap.(leaf, 1), wrap.(leaf, 2)])

    {:ok, z0} = FilterSchema.render_filter_schema(@inputs, max_depth: 0)
    assert {:ok, [true, false]} = node_eval(z0, [leaf, wrap.(leaf, 1)])
  end

  test "connectives option restricts logical wrappers" do
    {:ok, zod} = FilterSchema.render_filter_schema(@inputs, connectives: ["and"])
    leaf = %{"field" => "count", "op" => "eq", "value" => 1}

    assert {:ok, [true, false, false]} =
             node_eval(zod, [
               %{"op" => "and", "value" => [leaf]},
               %{"op" => "or", "value" => [leaf]},
               %{"op" => "not", "value" => leaf}
             ])

    {:ok, none} = FilterSchema.render_filter_schema(@inputs, connectives: [])
    refute none =~ ~s'z.literal("and")'
    {:ok, atoms} = FilterSchema.render_filter_schema(@inputs, connectives: [:or])
    assert atoms =~ ~s'z.literal("or")'
    refute atoms =~ ~s'z.literal("and")'
  end

  test "output size stays bounded and grows geometrically (<8.5x) per depth level" do
    sizes =
      for d <- 0..3 do
        {:ok, z} = FilterSchema.render_filter_schema(@inputs, max_depth: d)
        assert :ok = ZodGuard.expression(z)
        byte_size(z)
      end

    assert List.last(sizes) < 2_000_000
    ratios = sizes |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b / a end)
    assert Enum.all?(ratios, &(&1 > 1.5 and &1 < 8.5)), inspect({sizes, ratios})
  end

  test "deterministic across calls and input order of unions is stable" do
    assert FilterSchema.render_filter_schema(@inputs) ==
             FilterSchema.render_filter_schema(@inputs)
  end
end
