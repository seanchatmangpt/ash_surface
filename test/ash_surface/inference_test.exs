defmodule AshSurface.InferenceTest do
  use ExUnit.Case, async: true
  alias AshSurface.Projectors.JS.Inference

  @res [
    {"Post",
     [
       %{name: "title", ts: "string", primitive?: true},
       %{name: "id", ts: "string", primitive?: true}
     ]}
  ]

  test "deterministic and contains core types" do
    out = Inference.emit(@res)
    assert out == Inference.emit(@res)

    for t <- ["UnionToIntersection", "InferResult", "UnifiedFieldSelection"],
        do: assert(out =~ "export type #{t}")

    assert out =~ ~s(__primitiveFields: "id" | "title";)
  end

  test "rejects bad resource identifier" do
    assert_raise ArgumentError, fn -> Inference.resource_meta("a b", []) end
  end

  @tag :tsc
  test "type-checks under real tsc" do
    tsc = System.find_executable("tsc")

    if tsc do
      dir = Path.join(System.tmp_dir!(), "inf_#{AshSurface.TestTmp.suffix()}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(
        Path.join(dir, "a.ts"),
        Inference.emit(@res) <>
          """

          const sel = ["title"] as const;
          type R = InferResult<PostSchema, ["title"]>;
          const r: R = { title: "x" };
          // @ts-expect-error
          const bad: R = { title: 1 };
          export { r, bad, sel };
          """
      )

      {out, code} =
        System.cmd(tsc, ["--noEmit", "--strict", "--target", "es2020", Path.join(dir, "a.ts")],
          stderr_to_stdout: true
        )

      assert {code, out} == {0, ""}
    end
  end
end
