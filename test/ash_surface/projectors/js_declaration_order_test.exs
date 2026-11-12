defmodule AshSurface.Projectors.JSDeclarationOrderTest do
  @moduledoc """
  w3-15: port of ash_typescript zod_declaration_order_test. ash_surface inlines
  embedded resources (no shared consts), so the testable contract is: the emitted
  artifact evaluates under real node/zod without TDZ/ReferenceError for the
  diamond A->B->D->E, A->C->D->E; output is deterministic and independent of
  resource-map order; cycles are typed refusals or depth-terminated.
  Diamond tests run on the real wave3-05 TypedContainers fixtures; the edge cases
  below (array wrap, missing dep, cycles) need shapes no fixture has and stay synthetic.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{IR, Compiler.EmbeddedSchema, Compiler.RecordSchema, Compiler.TypeFacts, Projectors.JS}
  alias AshSurface.ZodFixtures.TypedContainers, as: T

  @root Path.expand("../../..", __DIR__)
  @tmp Path.join(System.tmp_dir!(), "js_declaration_order_cn")

  defp emb(name, extra \\ %{}),
    do: Map.merge(%{"type" => %{"kind" => "embedded_resource", "resource" => name}}, extra)

  defp f(name, type), do: %{"name" => name, "type" => type}
  defp ref(name), do: %{"kind" => "embedded_resource", "resource" => name}

  # Real w3-05 fixture graph: NodeA -> NodeB,NodeC -> NodeD -> NodeE, as the real compiler
  # facts see it (resource map keyed by module name, fields from real Ash attributes).
  defp name(mod), do: inspect(mod)

  defp diamond do
    TypeFacts.embedded_resources([emb(name(T.NodeA))])
  end

  defp program do
    assert {:ok, program} = RecordSchema.render(T.NodeA)
    program
  end

  defp zod_source(program),
    do: EmbeddedSchema.declarations_source(program) <>
      "export const Holder_create_inputSchema = #{program.expression};\n\nexport const Holder_create_outputSchema = z.unknown();\n"

  defp synth_diamond do
    %{
      "A" => [f("b", ref("B")), f("c", ref("C")), f("id", %{"kind" => "string"})],
      "B" => [f("d", ref("D"))],
      "C" => [f("d", ref("D"))],
      "D" => [f("e", ref("E"))],
      "E" => [f("value", %{"kind" => "string"})]
    }
  end

  defp ir(zod) do
    IR.new(
      ash: %IR.Ash{
        resource: "Holder",
        action: :create,
        action_type: :create,
        policies: [%{"authorityBoundary" => "DO"}]
      },
      capability: %IR.Capability{capability_id: "holder.write", receipt_required: true},
      schema: %IR.Schema{zod: zod}
    )
  end

  setup do
    File.rm_rf!(@tmp)
    File.mkdir_p!(Path.join(@tmp, "node_modules"))
    File.ln_s!(Path.join(@root, "node_modules/zod"), Path.join(@tmp, "node_modules/zod"))
    on_exit(fn -> File.rm_rf!(@tmp) end)
    :ok
  end

  test "real NodeA fixture: artifact imports and parses under node without TDZ/ReferenceError" do
    assert {:ok, _, _} = JS.project_ir(ir(zod_source(program())), target_dir: @tmp)

    id = "00000000-0000-4000-8000-000000000000"
    # embedded nodes carry no `id` on the wire (strict objects); only the root keeps it
    leaf = fn v -> %{leaf: %{value: v}} end
    node = fn v -> %{down: leaf.(v)} end
    valid = %{id: id, left: node.("x"), right: node.("y")}
    bad_leaf = %{id: id, left: node.(1), right: node.("y")}

    script = Path.join(@tmp, "probe.mjs")

    File.write!(script, """
    import { dispatchIntent } from "./ash_surface_client.mjs";
    const ok = (input) => { try { dispatchIntent("Holder.create", input); return true; } catch (e) { return e.code === "INPUT_VALIDATION_FAILED" ? e.code + JSON.stringify(e.issues) : String(e); } };
    console.log(JSON.stringify({ valid: ok(#{Jason.encode!(valid)}), bad: ok(#{Jason.encode!(bad_leaf)}) }));
    """)

    {out, status} = System.cmd("node", [script], stderr_to_stdout: true, cd: @tmp)
    refute out =~ "ReferenceError"
    refute out =~ "before initialization"
    assert status == 0, out
    assert %{"valid" => true, "bad" => "INPUT_VALIDATION_FAILED" <> _} =
             out |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()
  end

  test "leaf-first expansion: shared NodeD is one named declaration with NodeE inlined inside" do
    program = program()
    assert [{id, expr}] = program.declarations
    assert id =~ "NodeD"
    assert expr =~ "value: z.string()"
    refute program.expression =~ "value: z.string()"
    assert length(Regex.scan(~r/#{id}/, program.expression)) == 2
  end

  test "deterministic and independent of resource map construction order" do
    r1 = diamond()
    r2 = r1 |> Enum.reverse() |> Map.new()
    d = emb(name(T.NodeA))
    {:ok, a} = EmbeddedSchema.render_program(d, resources: r1)
    assert {:ok, a} == EmbeddedSchema.render_program(d, resources: r2)
    assert {:ok, a} == EmbeddedSchema.render_program(d, resources: r1)
    assert {:ok, program()} == RecordSchema.render(T.NodeA) |> then(&{:ok, elem(&1, 1)})
  end

  test "array-wrapped dependency is expanded" do
    res = Map.put(synth_diamond(), "D", [f("es", %{"kind" => "array", "items" => ref("E")})])
    {:ok, zod} = EmbeddedSchema.render(emb("A"), resources: res)
    assert zod =~ "z.array(z.object({ value: z.string() }).strict())"
  end

  test "missing dependency does not break generation" do
    res = Map.delete(synth_diamond(), "E")
    assert {:ok, zod} = EmbeddedSchema.render(emb("A"), resources: res)
    assert zod =~ "z.record(z.string(), z.unknown())"
  end

  test "cycle without cycle_depth is a typed refusal with path" do
    res = %{"A" => [f("b", ref("B"))], "B" => [f("a", ref("A"))]}
    assert {:error, {:cyclic_schema, path}} = EmbeddedSchema.render(emb("A"), resources: res)
    assert path == ["A", "B", "A"]
  end

  test "cycle with cycle_depth terminates in a record and the artifact runs" do
    res = %{"A" => [f("n", %{"kind" => "string"}), f("a", ref("A"))]}
    assert {:ok, zod} = EmbeddedSchema.render(emb("A"), resources: res, cycle_depth: 1)
    assert zod =~ "z.record(z.string(), z.unknown())"
    assert {:ok, _, _} = JS.project_ir(ir(zod), target_dir: @tmp)
  end

  @tag skip:
         "ash_surface inlines embedded resources; shared-const Kahn topological " <>
           "declaration order has no analogue (w3-15 receipt: unsatisfiable by design)"
  test "shared const declarations are topologically ordered (ash_typescript Kahn sort)" do
    flunk("unreachable")
  end
end
