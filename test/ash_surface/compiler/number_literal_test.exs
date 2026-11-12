defmodule AshSurface.Compiler.NumberLiteralTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.NumberLiteral

  @edge [
    0.1,
    1.0e21,
    1.0e-7,
    5.0e-324,
    1.7976931348623157e308,
    -0.0,
    9_007_199_254_740_993,
    1.0,
    1.0e20,
    100.0,
    2.5,
    -1.5e-10,
    123_456_789.125,
    1.0e-6,
    0.000001234
  ]

  defp seeded(n) do
    :rand.seed(:exsss, {11, 22, 33})

    for _ <- 1..n do
      case :rand.uniform(3) do
        1 ->
          :rand.uniform() * :math.pow(10, :rand.uniform(40) - 20)

        2 ->
          # random finite double from random bits (exponent field kept below 0x7FF)
          <<hi::12, rest::52>> = <<:rand.uniform(0x10000000000000000) - 1::64>>
          <<f::float>> = <<rem(hi, 0x7FF)::12, rest::52>>
          f

        3 ->
          -:rand.uniform() * 1000
      end
    end
  end

  test "spelling matches ECMAScript for known cases" do
    assert NumberLiteral.render!(1.0) == "1"
    assert NumberLiteral.render!(1.0e20) == "100000000000000000000"
    assert NumberLiteral.render!(1.0e21) == "1e+21"
    assert NumberLiteral.render!(1.0e-7) == "1e-7"
    assert NumberLiteral.render!(-0.0) == "0"
    assert NumberLiteral.render!(0.1) == "0.1"
    assert NumberLiteral.render!(5.0e-324) == "5e-324"
    assert NumberLiteral.render!(1.7976931348623157e308) == "1.7976931348623157e+308"
    assert NumberLiteral.render!(7) == "7"
    assert_raise ArgumentError, fn -> NumberLiteral.render!(Integer.pow(10, 400)) end
  end

  test "node: rendered literal parses to the identical double, and zod accepts old and new spellings" do
    floats = Enum.uniq(@edge ++ seeded(500))

    cases =
      for f <- floats do
        <<bits::64>> = <<f::float>>

        %{
          "literal" => NumberLiteral.render!(f),
          "old" => legacy(f),
          "bits" => Integer.to_string(bits, 16)
        }
      end

    dir = Path.join(System.tmp_dir!(), "numlit-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    File.write!(Path.join(dir, "cases.json"), Jason.encode!(cases))
    runner = Path.join(dir, "run.mjs")
    root = File.cwd!()

    File.write!(runner, """
    import { createRequire } from "node:module";
    import { readFileSync } from "node:fs";
    const require = createRequire("#{root}/package.json");
    const { z } = require("zod");
    const cases = JSON.parse(readFileSync("#{dir}/cases.json", "utf8"));
    const buf = new DataView(new ArrayBuffer(8));
    let bad = [];
    for (const c of cases) {
      const v = Number(c.literal);
      buf.setFloat64(0, v);
      const got = buf.getBigUint64(0).toString(16).toUpperCase();
      const want = BigInt("0x" + c.bits).toString(16).toUpperCase();
      // -0.0 renders "0" by contract; every other value must be bit-identical.
      const ok = got === want || (c.literal === "0" && Number(c.old) === 0);
      const old = Number(c.old);
      const zodOk = z.number().min(old).safeParse(old).success && z.number().min(v).safeParse(v).success
        && z.number().max(v).safeParse(v).success;
      if (!ok || !zodOk || !/^-?[0-9.e+-]+$/.test(c.literal)) bad.push(c);
    }
    console.log(JSON.stringify({ n: cases.length, bad }));
    """)

    {out, 0} = System.cmd("node", [runner], stderr_to_stdout: true)
    result = out |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()
    assert result["n"] >= 500
    assert result["bad"] == []
  end

  # The pre-change Elixir spelling (interpolation); old output must remain valid JS.
  defp legacy(f), do: "#{f}"

  test "float bounds render the single ECMAScript spelling; real zod agrees with the reference's 0.0" do
    assert NumberLiteral.render!(0.0) == "0"
    assert NumberLiteral.render!(1.0) == "1"

    script = """
    import { z } from "zod";
    const ps = [-1, 0, 0.5, 1, 2];
    const a = ps.map((p) => z.number().min(0).max(1).safeParse(p).success);
    const b = ps.map((p) => z.number().min(0.0).max(1.0).safeParse(p).success);
    console.log(JSON.stringify({ a, b }));
    """

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", script],
        cd: Path.expand("../../..", __DIR__)
      )

    %{"a" => a, "b" => b} = Jason.decode!(out)
    assert a == b
  end
end
