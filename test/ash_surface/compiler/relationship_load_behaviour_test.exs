defmodule AshSurface.Compiler.RelationshipLoadBehaviourTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{RelationshipSchema, SelectionSchema}
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Harness

  defp many(extra \\ %{}) do
    Map.merge(
      %{
        "name" => "comments",
        "destination" => "Comment",
        "cardinality" => "many",
        "primitive_fields" => ["body", "id"],
        "relationships" => [
          %{"name" => "likes", "destination" => "Like", "cardinality" => "many"},
          %{"name" => "secret", "destination" => "S", "cardinality" => "one", "exposed" => false}
        ]
      },
      extra
    )
  end

  defp render!(rels, opts \\ []) do
    {:ok, zod, _} = RelationshipSchema.render_load_schema(rels, opts)
    assert {:ok, _, _} = ZodGuard.admit(zod)
    zod
  end

  defp run_node(zod, cases) do
    Harness.zod!()
    dir = Path.join(System.tmp_dir!(), "rs_node_#{AshSurface.TestTmp.suffix()}")
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

  test "keyset/offset exclusivity under real zod" do
    zod = render!([many(%{"pagination" => "mixed"})])
    wrap = fn c -> %{"comments" => c} end

    cases = [
      wrap.(%{"fields" => ["id"], "limit" => 5, "offset" => 0}),
      wrap.(%{"fields" => ["id"], "page" => %{"limit" => 5, "after" => "x", "count" => true}}),
      wrap.(%{"fields" => ["id"], "page" => %{"limit" => 5, "offset" => 2}}),
      # exclusive: top-level limit plus page
      wrap.(%{"fields" => ["id"], "limit" => 5, "page" => %{"limit" => 1}}),
      # exclusive: offset + after in one page object
      wrap.(%{"fields" => ["id"], "page" => %{"offset" => 1, "after" => "x"}}),
      wrap.(%{"fields" => []}),
      wrap.(%{"fields" => ["nope"]}),
      wrap.(true),
      %{"unknown" => true}
    ]

    assert run_node(zod, cases) == [true, true, true, false, false, false, false, true, false]
  end

  test "keyset-only rejects offset page; offset-only rejects keyset page; none omits page" do
    wrap = fn c -> %{"comments" => c} end
    ks = render!([many(%{"pagination" => "keyset"})])
    os = render!([many(%{"pagination" => "offset"})])
    none = render!([many(%{"pagination" => "none", "relationships" => nil})])
    p = fn page -> wrap.(%{"fields" => ["id"], "page" => page}) end

    assert run_node(ks, [p.(%{"after" => "a"}), p.(%{"offset" => 1})]) == [true, false]
    assert run_node(os, [p.(%{"offset" => 1}), p.(%{"after" => "a"})]) == [true, false]

    assert run_node(none, [
             wrap.(%{"fields" => ["id"]}),
             p.(%{"limit" => 1}),
             wrap.(%{"fields" => ["id"], "limit" => 1})
           ]) ==
             [true, false, false]

    refute none =~ "page:"
    refute none =~ "limit:"
  end

  test "count, sort string|array, filterable=false" do
    zod = render!([many(%{"filterable" => false, "relationships" => nil})])
    w = fn c -> %{"comments" => Map.put(c, "fields", ["id"])} end

    cases = [
      w.(%{"count" => true}),
      w.(%{"count" => "yes"}),
      w.(%{"sort" => "body"}),
      w.(%{"sort" => ["body", "-id"]}),
      w.(%{"sort" => 3}),
      w.(%{"filter" => %{"a" => 1}})
    ]

    assert run_node(zod, cases) == [true, false, true, true, false, false]
    refute zod =~ "filter:"
    sortless = render!([many(%{"sortable" => false, "relationships" => nil})])
    refute sortless =~ "sort:"
    assert sortless =~ "filter:"
  end

  test "fields min 1 and exposed=false omission, nested" do
    zod = render!([many()])
    assert zod =~ ".min(1)"
    refute zod =~ "secret"
    assert zod =~ "likes"

    assert run_node(zod, [
             %{"comments" => %{"fields" => ["id"], "load" => %{"likes" => true}}},
             %{"comments" => %{"fields" => []}}
           ]) == [true, false]
  end

  test "invalid facts are typed errors" do
    assert {:error, {:invalid_pagination, "comments"}} =
             RelationshipSchema.render_load_schema([many(%{"pagination" => "weird"})])

    assert {:error, {:invalid_flag, "comments"}} =
             RelationshipSchema.render_load_schema([many(%{"filterable" => "no"})])
  end

  test "denied_loads / allowed_loads over names and nested paths" do
    rels = [many(), %{"name" => "author", "destination" => "U", "cardinality" => "one"}]
    {:ok, base} = SelectionSchema.render_selection_schema(["a"], [], relationships: rels)
    assert base =~ "comments" and base =~ "author"

    {:ok, denied} =
      SelectionSchema.render_selection_schema(["a"], [],
        relationships: rels,
        denied_loads: ["comments"]
      )

    refute denied =~ "comments"
    assert denied =~ "author"

    {:ok, nested} =
      SelectionSchema.render_selection_schema(["a"], [],
        relationships: rels,
        denied_loads: ["comments.likes"]
      )

    assert nested =~ "comments"
    refute nested =~ "likes"

    {:ok, allowed} =
      SelectionSchema.render_selection_schema(["a"], [],
        relationships: rels,
        allowed_loads: ["comments.likes"]
      )

    assert allowed =~ "likes"
    refute allowed =~ "author"

    {:ok, empty} =
      SelectionSchema.render_selection_schema(["a"], [], relationships: rels, allowed_loads: [])

    assert empty =~ "load: z.object({}).strict()"
    assert {:ok, _, _} = ZodGuard.admit(empty)
  end

  test "selection nests calculations and aggregates" do
    calcs = [%{"name" => "shout", "arguments" => []}]
    aggs = [%{"name" => "comment_count", "kind" => :count}]

    {:ok, zod} =
      SelectionSchema.render_selection_schema(["a"], [], calculations: calcs, aggregates: aggs)

    assert zod =~ "calculations:" and zod =~ ~s|"shout"|
    assert zod =~ ~s|aggregates: z.array(z.enum(["comment_count"]))|
    assert {:ok, _, _} = ZodGuard.admit(zod)

    assert run_node(zod, [
             %{
               "fields" => ["a"],
               "calculations" => %{"shout" => %{}},
               "aggregates" => ["comment_count"]
             },
             %{"fields" => ["a"], "aggregates" => ["zzz"]}
           ]) == [true, false]
  end

  test "determinism and size/depth sanity (max_depth 2 union duplication)" do
    leaf = fn n -> %{"name" => n, "cardinality" => "many"} end
    mid = fn n, kids -> %{"name" => n, "cardinality" => "many", "relationships" => kids} end
    rels = [mid.("a", [mid.("b", [leaf.("c")])])]
    assert render!(rels) == render!(rels)
    d0 = render!(rels, max_depth: 0) |> byte_size()
    d1 = render!(rels, max_depth: 1) |> byte_size()
    d2 = render!(rels, max_depth: 2) |> byte_size()
    assert d0 < d1 and d1 < d2
    # each many level doubles its base across two arms; 3 levels stay bounded
    assert d2 < 40_000
    assert d2 < d0 * 40
  end
end
