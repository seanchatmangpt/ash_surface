defmodule AshSurface.DivergenceClose.RecordValueDivergenceTest do
  @moduledoc """
  F1-kindiv court: `map`/`keyword`/`tuple`/`struct` render `z.record(z.string(), z.unknown())`
  where ash_typescript renders `z.any()` values. Real node + real zod 4.6.5 accept/reject the
  same payloads at runtime; real `tsc` shows the inferred value type differs: `unknown` forces
  narrowing (property access is a compile error) where `any` silently permits it.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType

  @root Path.expand("../../..", __DIR__)
  @payloads [~s({}), ~s({"a":1}), ~s({"a":null}), ~s([1]), ~s("x"), ~s(null)]

  test "kinds render unknown record values" do
    for kind <- ["map", "keyword", "tuple", "struct"] do
      assert ZodType.fragment(%{"type" => %{"kind" => kind}}) ==
               "z.record(z.string(), z.unknown())"
    end
  end

  test "runtime accept/reject is identical to the reference's z.any() form (real zod)" do
    script = """
    import { z } from "zod";
    const ps = #{Jason.encode!(@payloads)}.map((s) => JSON.parse(s));
    const a = ps.map((p) => z.record(z.string(), z.unknown()).safeParse(p).success);
    const b = ps.map((p) => z.record(z.string(), z.any()).safeParse(p).success);
    console.log(JSON.stringify({ a, b }));
    """

    {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: @root)
    %{"a" => a, "b" => b} = Jason.decode!(out)
    assert a == b
    assert true in a and false in a
  end

  defp tsc(body) do
    dir = Path.join(System.tmp_dir!(), "rvd_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(@root, "node_modules"), Path.join(dir, "node_modules"))
    File.write!(Path.join(dir, "t.ts"), body)

    System.cmd(
      Path.join(@root, "node_modules/.bin/tsc"),
      [
        "--noEmit",
        "--strict",
        "--skipLibCheck",
        "--module",
        "esnext",
        "--moduleResolution",
        "bundler",
        "--target",
        "es2022",
        "t.ts"
      ],
      cd: dir,
      stderr_to_stdout: true
    )
  end

  test "real tsc: unknown values reject unchecked property access, any permits it" do
    unknown = ~s|import { z } from "zod";
    const s = z.record(z.string(), z.unknown());
    const v: z.infer<typeof s> = {};
    const x = v.a.b;
    export { x };|

    any = String.replace(unknown, "z.unknown()", "z.any()")

    {_out, unknown_rc} = tsc(unknown)
    {_out, any_rc} = tsc(any)
    assert unknown_rc != 0
    assert any_rc == 0
  end
end
