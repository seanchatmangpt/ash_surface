defmodule AshSurface.Compiler.RelationshipSchemaS1aTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RelationshipSchema
  alias AshSurface.ZodFixtures.Harness

  defp run_node(zod, cases) do
    Harness.zod!()
    dir = Path.join(System.tmp_dir!(), "rs1_node_#{AshSurface.TestTmp.suffix()}")
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

  defp rel(extra \\ %{}) do
    Map.merge(
      %{
        "name" => "c",
        "destination" => "C",
        "cardinality" => "many",
        "primitive_fields" => ["id", "body"]
      },
      extra
    )
  end

  test "descriptors and jsdoc exclude exposed:false" do
    rels = [rel(), rel(%{"name" => "secret", "exposed" => false})]
    assert Map.keys(RelationshipSchema.descriptors(rels)) == ["c"]
    refute RelationshipSchema.jsdoc(rels) =~ "secret"
  end

  test "non-integer max_depth is a typed error" do
    for bad <- [1.5, "x", -1, nil] do
      assert {:error, {:invalid_max_depth, ^bad}} =
               RelationshipSchema.render_load_schema([rel()], max_depth: bad)
    end
  end

  test "nesting does not blow up: size grows linearly-ish with depth" do
    mk = fn n, kids -> %{"name" => n, "cardinality" => "many", "relationships" => kids} end

    rels = [
      mk.("a", [mk.("b", [mk.("c", [mk.("d", [%{"name" => "e", "cardinality" => "many"}])])])])
    ]

    {:ok, d1, _} = RelationshipSchema.render_load_schema(rels, max_depth: 1)
    {:ok, d4, _} = RelationshipSchema.render_load_schema(rels, max_depth: 4)
    assert byte_size(d4) < byte_size(d1) * 8
  end

  test "exclusivity and known-field filter hold under real zod" do
    {:ok, zod, _} = RelationshipSchema.render_load_schema([rel(%{"pagination" => "mixed"})])
    w = fn c -> %{"c" => c} end

    assert run_node(zod, [
             w.(%{"fields" => ["id"], "limit" => 2, "offset" => 1}),
             w.(%{"fields" => ["id"], "page" => %{"limit" => 2}}),
             w.(%{"fields" => ["id"], "limit" => 2, "page" => %{"limit" => 1}}),
             w.(%{"fields" => ["id"], "filter" => %{"body" => "x"}}),
             w.(%{"fields" => ["id"], "filter" => %{"nope" => "x"}}),
             w.(%{"fields" => ["id"], "bogus" => 1})
           ]) == [true, true, false, true, false, false]
  end

  test "L7: hostile relationship name cannot break out of the comment" do
    out =
      RelationshipSchema.jsdoc([
        rel(%{"name" => "x */ import('//e') /*"}),
        rel(%{"name" => "y\nimport('//e')"})
      ])

    refute out =~ "*/"
    assert length(String.split(out, "\n")) == 2
  end
end
