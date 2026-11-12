defmodule AshSurface.Rpc.Rbc.ZodBranchesTest do
  @moduledoc "Wave3 RBC: kills ZodType/Fold survivors Z-e, Z-f, Z-g, Z-h."
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{RouteSchema, ZodType}

  defp zod(expr, payloads) do
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "rbc_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const S = #{expr};
    process.stdout.write(JSON.stringify(#{Jason.encode!(payloads)}.map((p) => S.safeParse(p).success)));
    """)

    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp frag(kind, c \\ %{}),
    do: ZodType.fragment(%{"type" => %{"kind" => kind}, "constraints" => c})

  test "Z-e: any kind emits exactly z.any() (not z.unknown())" do
    assert frag("any") == "z.any()"
    refute frag("any") =~ "unknown"
    assert zod(frag("any"), [1, "a", nil, %{"k" => 1}]) == [true, true, true, true]
  end

  test "Z-f: s flag is kept and dotAll is honoured under zod" do
    expr = frag("string", %{"match" => "^a.b$", "match_flags" => "s"})
    assert expr =~ ~r{/s\)}
    assert zod(expr, ["a\nb", "axb", "ab"]) == [true, true, false]

    both = frag("string", %{"match" => "^a.b$", "match_flags" => "si"})
    assert both =~ ~r{/is\)}
    assert zod(both, ["A\nB"]) == [true]
  end

  test "Z-g: ci_string base mapping is exactly z.string()" do
    assert frag("ci_string") == "z.string()"
    assert zod(frag("ci_string"), ["x", 1, nil]) == [true, false, false]
  end

  test "Z-h: fold refuses non-binary match_flags, accepts binary" do
    route = fn flags ->
      %{
        "name" => "a",
        "method" => "post",
        "path" => "/a",
        "arguments" => [
          %{
            "name" => "x",
            "type" => %{"kind" => "string"},
            "constraints" => %{"match" => "a", "match_flags" => flags}
          }
        ],
        "returns" => nil
      }
    end

    assert {:error, {:invalid_argument_constraints, "a", "x", "match_flags", _}} =
             RouteSchema.build([route.(5)])

    assert {:ok, [_]} = RouteSchema.build([route.("i")])
  end
end
