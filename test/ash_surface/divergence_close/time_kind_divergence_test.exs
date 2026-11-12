defmodule AshSurface.DivergenceClose.TimeKindDivergenceTest do
  @moduledoc """
  F1-kindiv court: `time`/`time_usec` render `z.iso.time()` where ash_typescript renders
  `z.string().time()`. Real node + real zod 4.6.5: both accept/reject the same payloads, and
  zod's own typings mark `ZodString.time()` `@deprecated Use z.iso.time() instead`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType

  @root Path.expand("../../..", __DIR__)
  @payloads ["12:30:00", "12:30", "12:30:00.123456", "25:00:00", "12:30:00Z", "nope", ""]

  test "time and time_usec render z.iso.time()" do
    for kind <- ["time", "time_usec"],
        do: assert(ZodType.fragment(%{"type" => %{"kind" => kind}}) == "z.iso.time()")
  end

  test "z.iso.time() and z.string().time() agree on every payload (real zod)" do
    script = """
    import { z } from "zod";
    const ps = #{Jason.encode!(@payloads)};
    const a = ps.map((p) => z.iso.time().safeParse(p).success);
    const b = ps.map((p) => z.string().time().safeParse(p).success);
    console.log(JSON.stringify({ a, b }));
    """

    {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: @root)
    %{"a" => a, "b" => b} = Jason.decode!(out)
    assert a == b
    assert true in a and false in a
  end

  test "zod typings deprecate ZodString.time() in favor of z.iso.time()" do
    dts = File.read!(Path.join(@root, "node_modules/zod/v4/classic/schemas.d.ts"))
    assert dts =~ "@deprecated Use `z.iso.time()` instead."
  end
end
