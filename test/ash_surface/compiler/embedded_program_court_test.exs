defmodule AshSurface.Compiler.EmbeddedProgramCourtTest do
  # F1-refs courts: exact recursion + shared-node declarations for embedded resources,
  # executed under real node+zod; ZodGuard identifier allowlist; union __proto__ refusal.
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{EmbeddedSchema, UnionSchema}
  alias AshSurface.Projectors.JS.ZodGuard

  defp run_module(source, payloads) do
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "f1rf_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    let out;
    try {
    #{source}
      const ps = #{Jason.encode!(payloads)};
      out = ps.map((p) => S.safeParse(p).success);
    } catch (e) { out = {throws: String(e)}; }
    process.stdout.write(JSON.stringify(out));
    """)

    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp ids(%{declarations: d}), do: Enum.map(d, &elem(&1, 0))

  defp admit_all(%{declarations: d, expression: e} = prog) do
    for {_id, expr} <- d, do: assert(:ok = ZodGuard.expression(expr, identifiers: ids(prog)))
    assert :ok = ZodGuard.expression(e, identifiers: ids(prog))
  end

  defp source(prog, decls \\ nil) do
    decls = decls || prog.declarations
    text = EmbeddedSchema.declarations_source(%{declarations: decls})
    text <> "const S = #{prog.expression};\n"
  end

  defp node_def do
    %{
      "name" => "child",
      "allow_nil?" => true,
      "omittable" => true,
      "type" => %{"kind" => "resource", "instance_of" => "My.Node"}
    }
  end

  defp cyclic_resources,
    do: %{
      "My.Node" => [%{"name" => "v", "type" => %{"kind" => "integer"}}, node_def()]
    }

  defp root, do: %{"type" => %{"kind" => "resource", "instance_of" => "My.Node"}}

  defp nest(0), do: %{"v" => 0}
  defp nest(n), do: %{"v" => n, "child" => nest(n - 1)}

  defp break_at_depth(p, 0), do: Map.put(p, "v", "bad")
  defp break_at_depth(%{"child" => c} = p, n), do: %{p | "child" => break_at_depth(c, n - 1)}

  describe "cyclic embedded resource (exact recursion)" do
    test "5-deep self-reference: valid accepted, invalid at depth 5 rejected, guard admits" do
      assert {:ok, prog} = EmbeddedSchema.render_program(root(), resources: cyclic_resources())
      assert ids(prog) == ["My_NodeZodSchema"]
      admit_all(prog)
      assert prog.expression == "My_NodeZodSchema"

      valid = nest(5)
      deep_bad = break_at_depth(nest(5), 5)
      mid_bad = break_at_depth(nest(5), 2)
      deeper = nest(40)

      assert [true, false, false, true] ==
               run_module(source(prog), [valid, deep_bad, mid_bad, deeper])
    end

    test "cycle_depth truncation ACCEPTS invalid data (the defect exact recursion removes)" do
      assert {:ok, out} =
               EmbeddedSchema.render(root(), resources: cyclic_resources(), cycle_depth: 1)

      deep_bad = break_at_depth(nest(5), 5)
      assert [true] == run_module("const S = #{out};", [deep_bad])
    end

    test "mutual cycle A<->B, declaration order reversed: no TDZ/ReferenceError" do
      a = %{"name" => "b", "type" => %{"kind" => "resource", "instance_of" => "My.B"}}

      b = %{
        "name" => "a",
        "allow_nil?" => true,
        "type" => %{"kind" => "resource", "instance_of" => "My.A"}
      }

      res = %{"My.A" => [a], "My.B" => [b]}
      d = %{"type" => %{"kind" => "resource", "instance_of" => "My.A"}}
      assert {:ok, prog} = EmbeddedSchema.render_program(d, resources: res)
      admit_all(prog)
      payloads = [%{"b" => %{"a" => %{"b" => %{"a" => nil}}}}, %{"b" => %{"a" => %{"b" => 1}}}]
      assert [true, false] == run_module(source(prog), payloads)
      assert [true, false] == run_module(source(prog, Enum.reverse(prog.declarations)), payloads)
    end

    test "deterministic bytes" do
      {:ok, a} = EmbeddedSchema.render_program(root(), resources: cyclic_resources())
      {:ok, b} = EmbeddedSchema.render_program(root(), resources: cyclic_resources())
      assert a == b
    end
  end

  describe "diamond DAG: bytes and execution" do
    defp diamond(depth) do
      res =
        for k <- 1..depth, into: %{} do
          ref = fn n ->
            %{"name" => n, "type" => %{"kind" => "resource", "instance_of" => "D#{k + 1}"}}
          end

          fields =
            if k == depth,
              do: [%{"name" => "leaf", "type" => %{"kind" => "string"}}],
              else: [ref.("a"), ref.("b")]

          {"D#{k}", fields}
        end

      {res, %{"type" => %{"kind" => "resource", "instance_of" => "D1"}}}
    end

    defp payload(1), do: %{"leaf" => "x"}
    defp payload(k), do: %{"a" => payload(k - 1), "b" => payload(k - 1)}

    test "named shared nodes are linear; inline is exponential; both validate identically" do
      rows =
        for depth <- 2..4 do
          {res, d} = diamond(depth)
          {:ok, inline} = EmbeddedSchema.render(d, resources: res)
          {:ok, prog} = EmbeddedSchema.render_program(d, resources: res)
          admit_all(prog)

          named =
            byte_size(prog.expression) +
              Enum.sum(for {_, e} <- prog.declarations, do: byte_size(e))

          good = payload(depth)
          bad = put_in(good, ["a", "a"], %{"leaf" => 1}) |> then(& &1)
          p = [good, bad]
          expect = run_module("const S = #{inline};", p)
          assert expect == run_module(source(prog), p)
          assert expect == run_module(source(prog, Enum.reverse(prog.declarations)), p)
          {depth, byte_size(inline), named}
        end

      IO.puts("F1RF diamond bytes (depth, inline, named): #{inspect(rows)}")
      {_, inline4, named4} = List.last(rows)
      assert named4 < inline4
    end

    test "default render/2 inline path unchanged (byte-identical to named-free output)" do
      {res, d} = diamond(2)
      {:ok, out} = EmbeddedSchema.render(d, resources: res)
      assert :ok = ZodGuard.expression(out)
    end
  end

  describe "ZodGuard identifier allowlist" do
    test "undeclared identifier, bad allowlist entries and dunder getters stay refused" do
      assert {:error, _} = ZodGuard.expression("Node.nullable()")
      assert {:error, _} = ZodGuard.expression("z.array(Node)")
      assert :ok = ZodGuard.expression("z.array(Node)", identifiers: ["Node"])
      assert {:error, _} = ZodGuard.expression("z.array(Other)", identifiers: ["Node"])

      assert {:error, {:zod_bad_identifier, "z"}} =
               ZodGuard.expression("z.string()", identifiers: ["z"])

      assert {:error, _} = ZodGuard.expression("z.string()", identifiers: ["a b"])

      assert {:error, {:zod_denied_key, _}} =
               ZodGuard.expression("z.object({ get __proto__() { return Node } })",
                 identifiers: ["Node"]
               )

      assert {:error, _} =
               ZodGuard.expression("z.object({ get a() { return Evil } })", identifiers: ["Node"])

      assert {:error, _} =
               ZodGuard.expression("z.object({ get a() { return z.string(); alert } })",
                 identifiers: ["Node"]
               )

      assert :ok =
               ZodGuard.expression("z.object({ get a() { return Node.optional() } }).strict()",
                 identifiers: ["Node"]
               )
    end
  end

  describe "UnionSchema __proto__ (S2-01 follow-up)" do
    test "member name, tag and discriminator __proto__ are typed refusals" do
      str = %{"type" => %{"kind" => "string"}}

      assert {:error, {:denied_field_name, "__proto__"}} =
               UnionSchema.render_members([%{"name" => "__proto__", "type" => str}])

      assert {:error, {:denied_field_name, "__proto__"}} =
               UnionSchema.render_members([%{"name" => "a", "tag" => "__proto__", "type" => str}])

      assert {:error, {:denied_field_name, "__proto__"}} =
               UnionSchema.render_members([%{"name" => "a", "type" => str}],
                 discriminator: "__proto__"
               )

      assert {:ok, _} = UnionSchema.render_members([%{"name" => "proto", "type" => str}])
    end
  end
end
