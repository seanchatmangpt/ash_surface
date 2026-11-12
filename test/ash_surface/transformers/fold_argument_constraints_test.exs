defmodule AshSurface.Transformers.FoldArgumentConstraintsTest do
  @moduledoc """
  Courts for ash_typescript `FoldArgumentConstraints`: route argument kinds and
  constraints are validated and folded (Ash string defaults made explicit) before the
  Zod schema is rendered; `returns` is restricted to plain data.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.ZodFixtures.Harness

  defp route(args, returns \\ nil) do
    %{
      "name" => "a",
      "method" => "post",
      "path" => "/a",
      "arguments" => args,
      "returns" => returns
    }
  end

  defp arg(name, type, extra \\ %{}),
    do: Map.merge(%{"name" => name, "type" => %{"kind" => type}}, extra)

  test "unknown argument kind is refused, never z.unknown()" do
    assert {:error, {:invalid_argument_type, "a", "x", "nope"}} =
             RouteSchema.build([route([arg("x", "nope")])])
  end

  test "ill-typed or inapplicable constraints are refused with the offending key" do
    assert {:error,
            {:invalid_argument_constraints, "a", "x", "max_length", :not_a_non_negative_integer}} =
             RouteSchema.build([
               route([arg("x", "string", %{"constraints" => %{"max_length" => "a"}})])
             ])

    assert {:error, {:invalid_argument_constraints, "a", "x", "min", :not_applicable}} =
             RouteSchema.build([route([arg("x", "string", %{"constraints" => %{"min" => 1}})])])

    assert {:error, {:invalid_argument_constraints, "a", "x", "min", :not_a_number}} =
             RouteSchema.build([
               route([arg("x", "integer", %{"constraints" => %{"min" => "1"}})])
             ])

    assert {:error, {:invalid_argument_constraints, "a", "x", "constraints", {:not_a_map, [1]}}} =
             RouteSchema.build([route([arg("x", "string", %{"constraints" => [1]})])])
  end

  test "string default allow_empty?: false is folded explicitly; explicit true is kept" do
    {:ok, [r]} =
      RouteSchema.build([
        route([
          arg("s", "string", %{"allow_nil?" => false}),
          arg("e", "string", %{"allow_nil?" => false, "constraints" => %{"allow_empty?" => true}}),
          arg("n", "integer", %{"allow_nil?" => false})
        ])
      ])

    assert r["body"] =~ "s: z.string().min(1)"
    assert r["body"] =~ "e: z.string()"
    refute r["body"] =~ "e: z.string().min"
    assert r["body"] =~ "n: z.number().int()"
  end

  test "route returns of resource / union kind are refused, plain data admitted" do
    for kind <- ~w(resource embedded_resource union) do
      assert {:error, {:unsupported_return, "a", ^kind}} =
               RouteSchema.build([route([], %{"type" => %{"kind" => kind}})])
    end

    assert {:error, {:unsupported_return, "a", "union"}} =
             RouteSchema.build([
               route([], %{"type" => %{"kind" => "array", "items" => %{"kind" => "union"}}})
             ])

    assert {:ok, [_]} = RouteSchema.build([route([], %{"type" => %{"kind" => "string"}})])
  end

  test "folded default is enforced under zod (node-executed)" do
    {:ok, [r]} = RouteSchema.build([route([arg("s", "string", %{"allow_nil?" => false})])])

    dir = Path.join(System.tmp_dir!(), "fold_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const s = #{r["body"]};
    const cases = [{s: "ok"}, {s: ""}, {}];
    process.stdout.write(JSON.stringify(cases.map((c) => s.safeParse(c).success)));
    """)

    {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
    File.rm_rf!(dir)
    assert Jason.decode!(out) == [true, false, false]
  end
end
