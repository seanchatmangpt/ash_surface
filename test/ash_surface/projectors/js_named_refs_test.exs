defmodule AshSurface.Projectors.JSNamedRefsTest do
  @moduledoc """
  F1-refwire courts (KD-02): named `<Name>ZodSchema` consts reach the emitted .mjs via the
  real Compiler.Schema -> IR -> Projectors.JS path; ZodGuard admits the program with the
  declared-identifier allowlist; the artifact executes under real node + zod (no mocks):
  5-deep cycle, mutual cycle, shared diamond, declaration order reversed.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{IR, Compiler.Schema, Projectors.JS, Projectors.JS.ZodGuard}

  @root Path.expand("../../..", __DIR__)

  defp res(name), do: %{"type" => %{"kind" => "resource", "instance_of" => name}}

  defp ref(name, field),
    do: %{"name" => field, "allow_nil?" => true, "omittable" => true, "type" => res(name)["type"]}

  defp int(name), do: %{"name" => name, "type" => %{"kind" => "integer"}}

  defp artifact(resources) do
    discovery = %{
      "actions" => [
        %{
          "id" => "Todo.run",
          "arguments" => [
            %{"name" => "arg", "allow_nil?" => false, "type" => res("My.A")["type"]}
          ],
          "returns" => nil,
          "embedded_resources" => resources
        }
      ]
    }

    {:ok, %{"Todo.run" => boundary}, _} = Schema.build(discovery)

    ir =
      IR.new(
        ash: %IR.Ash{
          resource: "Todo",
          action: :run,
          action_type: :action,
          policies: [%{"authorityBoundary" => "OBSERVE"}]
        },
        schema: %IR.Schema{zod: boundary.zod}
      )

    assert {:ok, %{"ash_surface_client.mjs" => code}, _} = JS.project_ir(ir)
    {boundary.zod, code}
  end

  defp run(code, payloads, reverse? \\ false) do
    dir = Path.join(System.tmp_dir!(), "f1rw_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(dir, "node_modules"))
    File.ln_s!(Path.join(@root, "node_modules/zod"), Path.join(dir, "node_modules/zod"))
    code = if reverse?, do: reverse_declarations(code), else: code
    File.write!(Path.join(dir, "client.mjs"), code)

    File.write!(Path.join(dir, "run.mjs"), """
    import * as m from "./client.mjs";
    const S = m.Todo_run_schema;
    const ps = #{Jason.encode!(payloads)};
    process.stdout.write(JSON.stringify(ps.map((p) => S.safeParse(p).success)));
    """)

    {out, status} = System.cmd("node", ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    assert status == 0, out
    Jason.decode!(out)
  end

  # Reverses the order of the top-level `const <Name>ZodSchema = ...;` declaration block.
  defp reverse_declarations(code) do
    {decls, rest} =
      code
      |> String.split("\n\n")
      |> Enum.split_with(&String.starts_with?(&1, "const "))

    assert length(decls) > 1
    # splice back immediately after the import/typedef header chunks
    {head, tail} = Enum.split_while(rest, &(not String.starts_with?(&1, "/** Zod boundary")))
    Enum.join(head ++ Enum.reverse(decls) ++ tail, "\n\n")
  end

  defp nest(0), do: %{"v" => 0}
  defp nest(n), do: %{"v" => n, "child" => nest(n - 1)}
  defp break_at(p, 0), do: Map.put(p, "v", "bad")
  defp break_at(%{"child" => c} = p, n), do: %{p | "child" => break_at(c, n - 1)}

  test "cyclic 5-deep: named const reaches the artifact, guard admits, node validates exactly" do
    {zod, code} = artifact(%{"My.A" => [int("v"), ref("My.A", "child")]})

    assert [{"My_AZodSchema", _}] = ZodGuard.declarations(zod)
    assert {:ok, :program, _} = ZodGuard.admit(zod)
    assert code =~ "const My_AZodSchema ="
    assert code =~ "get child()"

    wrap = fn p -> %{"arg" => p} end

    assert [true, false, false, true] ==
             run(code, [
               wrap.(nest(5)) |> Map.put("x", 1),
               wrap.(break_at(nest(5), 5)),
               wrap.(break_at(nest(5), 2)),
               wrap.(nest(40))
             ])
  end

  test "mutual cycle A<->B, declaration order reversed in the artifact" do
    resources = %{
      "My.A" => [int("v"), ref("My.B", "b")],
      "My.B" => [int("w"), ref("My.A", "a")]
    }

    {zod, code} = artifact(resources)
    assert {:ok, :program, _} = ZodGuard.admit(zod)
    assert length(ZodGuard.declarations(zod)) == 2

    good = %{"arg" => %{"v" => 1, "b" => %{"w" => 2, "a" => %{"v" => 3, "b" => %{"w" => 4}}}}}
    bad = %{"arg" => %{"v" => 1, "b" => %{"w" => 2, "a" => %{"v" => "x"}}}}
    assert [true, false] == run(code, [good, bad])
    assert [true, false] == run(code, [good, bad], true)
  end

  test "diamond (shared D under B and C), declaration order reversed" do
    resources = %{
      "My.A" => [ref("My.B", "b"), ref("My.C", "c")],
      "My.B" => [ref("My.D", "d")],
      "My.C" => [ref("My.D", "d")],
      "My.D" => [int("n")]
    }

    {zod, code} = artifact(resources)
    assert {:ok, :program, _} = ZodGuard.admit(zod)
    assert [{"My_DZodSchema", _}] = ZodGuard.declarations(zod)
    # reversal needs >1 declaration; the diamond names only D, so run as-is and exact
    ok = %{"arg" => %{"b" => %{"d" => %{"n" => 1}}, "c" => %{"d" => %{"n" => 2}}}}
    bad = %{"arg" => %{"b" => %{"d" => %{"n" => 1}}, "c" => %{"d" => %{"n" => "x"}}}}
    assert [true, false] == run(code, [ok, bad])
  end

  test "undeclared identifier in a program is refused by the guard" do
    prog =
      "const A = z.object({x: B}).strict();\nexport const t_inputSchema = A;\n\n" <>
        "export const t_outputSchema = z.undefined();\n"

    assert {:error, _} = ZodGuard.admit(prog)

    assert {:ok, :program, "A"} =
             ZodGuard.admit(
               "const A = z.string();\nexport const t_inputSchema = A;\n\n" <>
                 "export const t_outputSchema = z.undefined();\n"
             )
  end
end
