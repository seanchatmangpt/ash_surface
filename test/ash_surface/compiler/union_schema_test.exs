defmodule AshSurface.Compiler.UnionSchemaTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.UnionSchema
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Harness

  defp ok!(members, opts \\ []) do
    assert {:ok, expr} = UnionSchema.render_members_admitted(members, opts)
    assert {:ok, :expression, ^expr} = ZodGuard.admit(expr)
    expr
  end

  # Executes `expr` under real zod in node; cases: [{payload, expect_success}].
  defp run_node(expr, cases) do
    dir = Path.join(System.tmp_dir!(), "un_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    Harness.zod!()
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(
      Path.join(dir, "run.mjs"),
      """
      import { z } from "zod";
      const schema = #{expr};
      const cases = #{Jason.encode!(Enum.map(cases, &elem(&1, 0)))};
      process.stdout.write(JSON.stringify(cases.map((c) => schema.safeParse(c).success)));
      """
    )

    {out, status} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
    File.rm_rf!(dir)
    assert status == 0, out
    assert Jason.decode!(out) == Enum.map(cases, &elem(&1, 1))
  end

  test "empty members -> z.any()" do
    assert ok!([]) == "z.any()"
  end

  test "untagged: single-key strict objects, execute under zod" do
    expr = ok!([%{"name" => "s", "type" => "string"}, %{"name" => "n", "type" => "integer"}])
    assert expr =~ "z.union(["
    assert expr =~ "z.object({s: "

    run_node(expr, [
      {%{"s" => "a"}, true},
      {%{"n" => 3}, true},
      {%{"n" => "x"}, false},
      {%{"s" => "a", "n" => 3}, false},
      {%{}, false},
      {"a", false}
    ])
  end

  test "tagged map_with_tag" do
    expr =
      ok!([
        %{"name" => "a", "type" => "string", "tag" => "kind", "tag_value" => "A"},
        %{"name" => "b", "type" => "integer", "tag" => "kind", "tag_value" => "B"}
      ])

    assert expr =~ ~s|kind: z.literal("A")|

    run_node(expr, [
      {%{"a" => "x", "kind" => "A"}, true},
      {%{"b" => 1, "kind" => "B"}, true},
      {%{"a" => "x", "kind" => "B"}, false},
      {%{"a" => "x"}, false}
    ])
  end

  test "tagged type_and_value storage with custom discriminator" do
    expr =
      ok!([%{"name" => "a", "type" => "string", "tag" => "t", "tag_value" => "A"}],
        storage: :type_and_value
      )

    assert expr =~ ~s|t: z.literal("A"), value: |

    expr2 =
      ok!([%{"name" => "a", "type" => "string"}], storage: :type_and_value, discriminator: "k")

    assert expr2 =~ ~s|k: z.literal("a")|
    run_node(expr, [{%{"t" => "A", "value" => "x"}, true}, {%{"t" => "A", "value" => 1}, false}])
  end

  test "mixed tagged and untagged" do
    expr =
      ok!([
        %{"name" => "a", "type" => "string", "tag" => "kind", "tag_value" => "A"},
        %{"name" => "b", "type" => "boolean"}
      ])

    run_node(expr, [
      {%{"a" => "x", "kind" => "A"}, true},
      {%{"b" => true}, true},
      {%{"a" => "x"}, false}
    ])
  end

  test "atom-keyed members and atom kinds" do
    assert ok!([%{name: "a", type: :string}]) == ok!([%{"name" => "a", "type" => "string"}])
  end

  test "non-identifier names are quoted" do
    expr = ok!([%{"name" => "my-name", "type" => "string"}])
    assert expr =~ ~s|"my-name": |
    run_node(expr, [{%{"my-name" => "x"}, true}])
  end

  test "nested definitions: arrays and nested unions" do
    members = [
      %{"name" => "list", "type" => %{"kind" => "array", "item_type" => "integer"}},
      %{
        "name" => "inner",
        "type" => %{
          "kind" => "union",
          "members" => [
            %{"name" => "x", "type" => "string"},
            %{"name" => "y", "type" => "integer"}
          ]
        }
      },
      %{"name" => "opt", "type" => %{"type" => %{"kind" => "string"}, "allow_nil?" => true}}
    ]

    expr = ok!(members)

    run_node(expr, [
      {%{"list" => [1, 2]}, true},
      {%{"list" => ["a"]}, false},
      {%{"inner" => %{"x" => "s"}}, true},
      {%{"inner" => %{"z" => 1}}, false},
      {%{"opt" => nil}, true},
      {%{"opt" => "v"}, true}
    ])
  end

  test "container kinds do not crash (delegate or degrade)" do
    assert {:ok, expr} =
             UnionSchema.render_members_admitted([%{"name" => "m", "type" => "map"}])

    assert expr =~ "z.object({m: "
  end

  test "depth guard returns error" do
    deep =
      Enum.reduce(1..12, %{"name" => "leaf", "type" => "string"}, fn _, acc ->
        %{"name" => "n", "type" => %{"kind" => "union", "members" => [acc]}}
      end)

    assert {:error, {:union_depth_exceeded, _}} = UnionSchema.render_members([deep])
    assert {:ok, _} = UnionSchema.render_members([deep], max_depth: 20)
  end

  test "invalid facts" do
    assert {:error, {:union_members_not_a_list, :x}} = UnionSchema.render_members(:x)
    assert {:error, {:invalid_union_member, 5, 0}} = UnionSchema.render_members([5])

    assert {:error, {:invalid_union_member, _, 1}} =
             UnionSchema.render_members([
               %{"name" => "a", "type" => "string"},
               %{"type" => "string"}
             ])

    assert {:error, {:invalid_union_member, _, 0}} =
             UnionSchema.render_members([%{"name" => "a", "tag" => 5}])

    # F1-refs: refused earlier and typed (was a guard refusal downstream).
    assert {:error, {:denied_field_name, "__proto__"}} =
             UnionSchema.render_members_admitted([%{"name" => "__proto__", "type" => "string"}])
  end

  test "determinism" do
    m = [%{"name" => "a", "type" => "string"}, %{"name" => "b", "type" => "integer"}]
    assert UnionSchema.render_members(m) == UnionSchema.render_members(m)
  end

  test "legacy tagged {type,value} API still works" do
    facts = [
      %{tag: "s", kind: :string, constraints: %{}},
      %{tag: "i", kind: :integer, constraints: %{}}
    ]

    assert {:ok, expr} = UnionSchema.render_union_schema_admitted(facts)
    assert expr =~ ~s|z.discriminatedUnion("type", [|
    assert {:ok, expr2} = UnionSchema.render_union_schema_admitted(facts, discriminator: "k")
    assert expr2 =~ ~s|z.discriminatedUnion("k", [|

    run_node(expr, [
      {%{"type" => "s", "value" => "a"}, true},
      {%{"type" => "s", "value" => 1}, false}
    ])

    assert {:ok, "z.union([" <> _} =
             UnionSchema.render_union_schema([%{kind: :string}, %{kind: :integer}])

    assert {:error, :union_facts_empty} = UnionSchema.render_union_schema([])
    assert {:error, {:invalid_union_fact, _, 0}} = UnionSchema.render_union_schema([%{kind: "s"}])
  end
end
