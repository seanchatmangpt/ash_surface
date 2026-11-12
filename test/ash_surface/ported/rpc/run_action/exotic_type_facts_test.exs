defmodule AshSurface.Ported.Rpc.RunAction.ExoticTypeFactsTest do
  @moduledoc """
  T7 type-facts coverage for the exotic kinds the run_action reference files exercise
  (vector, tuple, union, untyped map). Real TypeFacts + ZodType, no doubles.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.TypeFacts

  defp kind(type, constraints \\ []),
    do: TypeFacts.analyze(type, constraints).definition["type"]["kind"]

  test "vector and ltree render their dedicated zod fragments" do
    vec = AshSurface.Compiler.TypeFacts.analyze(Ash.Type.Vector, dimensions: 3).definition
    assert AshSurface.Compiler.ZodType.fragment(vec) =~ "z.array(z.number())"

    ltree = AshSurface.Compiler.TypeFacts.analyze(AshPostgres.Ltree, []).definition
    assert AshSurface.Compiler.ZodType.fragment(ltree) =~ "z.string()"
  end

  test "vector, tuple, union and map resolve to their own kinds" do
    assert kind(Ash.Type.Vector, dimensions: 3) == "vector"
    assert kind(:vector, dimensions: 3) == "vector"
    assert kind(AshPostgres.Ltree) == "ltree"
    assert kind(Ash.Type.Map) == "map"

    assert kind(Ash.Type.Tuple, fields: [a: [type: :string], b: [type: :integer]]) == "tuple"

    assert kind(Ash.Type.Union, types: [s: [type: :string], i: [type: :integer]]) == "union"
  end

  alias AshSurface.Compiler.ZodType

  @root Path.expand("../../../../..", __DIR__)

  defp frag(type, constraints),
    do: ZodType.fragment(TypeFacts.analyze(type, constraints).definition)

  # Runs `fragment` under real node + zod; returns {accepted?, rejected?} per sample list.
  defp zod_verdicts(fragment, samples) do
    script = """
    import { z } from "zod";
    const s = #{fragment};
    console.log(JSON.stringify(#{Jason.encode!(samples)}.map((v) => s.safeParse(v).success)));
    """

    {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: @root)
    Jason.decode!(out)
  end

  test "vector fragment under zod: number arrays accepted, strings and mixed arrays rejected" do
    f = frag(Ash.Type.Vector, dimensions: 3)
    assert f == "z.array(z.number())"
    assert zod_verdicts(f, [[1, 2, 3], [], [0.5], "abc", [1, "2"], nil, %{}, 7]) ==
             [true, true, true, false, false, false, false, false]
  end

  test "ltree fragment under zod: dotted string or label array accepted, numbers rejected" do
    f = frag(AshPostgres.Ltree, [])
    assert zod_verdicts(f, ["a.b.c", ["a", "b"], 1, [1], nil, %{}]) ==
             [true, true, false, false, false, false]
  end

  test "map and tuple fragments under zod: records accepted, arrays and scalars rejected" do
    for type <- [
          {Ash.Type.Map, []},
          {Ash.Type.Tuple, fields: [a: [type: :string], b: [type: :integer]]}
        ] do
      {t, c} = type
      assert zod_verdicts(frag(t, c), [%{"a" => 1}, %{}, "x", 3, nil]) ==
               [true, true, false, false, false]
    end
  end

  test "array items constraint chain survives into the fragment and rejects out-of-range items" do
    a = TypeFacts.analyze({:array, Ash.Type.Integer}, items: [min: 1, max: 5])
    assert a.kind == "array"
    assert a.declared_constraints == %{items: %{min: 1, max: 5}}
    assert a.definition["type"]["items"]["constraints"] == %{"min" => 1, "max" => 5}
    assert a.definition["type"]["items"]["type"]["kind"] == "integer"

    f = ZodType.fragment(a.definition)
    assert f == "z.array(z.number().int().min(1).max(5))"
    assert zod_verdicts(f, [[1, 5], [], [0], [6], [1.5], ["1"]]) ==
             [true, true, false, false, false, false]
  end

  test "array of strings has unconstrained string items" do
    f = frag({:array, Ash.Type.String}, [])
    assert f == "z.array(z.string())"
    assert zod_verdicts(f, [["a"], [1], "a"]) == [true, false, false]
  end

  test "tuple definition preserves declared field order, names, kinds and nullability" do
    d =
      TypeFacts.analyze(Ash.Type.Tuple,
        fields: [x: [type: :float, allow_nil?: false], y: [type: :integer], z: [type: :boolean]]
      ).definition

    fields = d["type"]["fields"]
    assert Enum.map(fields, & &1["name"]) == ["x", "y", "z"]
    assert Enum.map(fields, & &1["type"]["kind"]) == ["float", "integer", "boolean"]
    assert Enum.map(fields, & &1["allow_nil?"]) == [false, true, true]
  end

  test "tuple newtype is analyzed as its base tuple kind with subtype_of recorded" do
    a = TypeFacts.analyze(AshSurface.Ported.InputParsing.LocationTuple, [])
    assert a.kind == "tuple"
    assert a.subtype_of == "tuple"

    assert Enum.map(a.definition["type"]["fields"], &{&1["name"], &1["type"]["kind"]}) ==
             [{"lat_1", "float"}, {"lng_1", "float"}, {"is_verified?", "boolean"}]
  end

  test "map with fields keeps field list; fieldless map has none" do
    with_f = TypeFacts.analyze(Ash.Type.Map, fields: [a: [type: :string, allow_nil?: false]])
    assert [%{"name" => "a", "allow_nil?" => false}] = with_f.definition["type"]["fields"]
    refute Map.has_key?(TypeFacts.analyze(Ash.Type.Map, []).definition["type"], "fields")
  end
end
