defmodule AshSurface.Ported.TS.Root.StructFieldSelectionFixture do
  @moduledoc "Private Inference fixture for T17 (real `Inference.emit/1`; no doubles)."
  alias AshSurface.Projectors.JS.Inference

  defp p(name, ts), do: %{name: name, ts: ts, primitive?: true}
  defp rel(name, ts), do: %{name: name, ts: ts, primitive?: false}

  def source do
    Inference.emit([
      {"Todo",
       [
         p("id", "string"),
         p("title", "string"),
         p("description", "string | null"),
         p("completed", "boolean | null"),
         rel("user", ~S[{ __type: "Relationship"; __resource: UserSchema }]),
         rel(
           "self",
           ~S[{ __type: "ComplexCalculation"; __returnType: TodoSchema; __args: { prefix?: string } }]
         )
       ]},
      {"User",
       [
         p("id", "string"),
         p("name", "string"),
         rel("todos", ~S[{ __type: "Relationship"; __resource: TodoSchema; __array: true }]),
         rel(
           "self",
           ~S[{ __type: "ComplexCalculation"; __returnType: UserSchema; __args: { prefix?: string } }]
         )
       ]}
    ])
  end
end

defmodule AshSurface.Ported.TS.Root.StructFieldSelectionTest do
  @moduledoc """
  Adapts ash_typescript `test/ts/structFieldSelection.ts` (4 tests) and
  `testStructFieldSelection.ts` (2 tests): struct-typed calculation field selection. Real
  `tsc --strict` over declarations `Inference.emit/1` emits; `@ts-expect-error` lines are the
  negative controls (an unused directive fails tsc).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.Root.StructFieldSelectionFixture, as: Fixture
  alias AshSurface.ZodFixtures.Harness

  @flags ~w(--strict --noEmit --skipLibCheck --module esnext --moduleResolution bundler --target es2022)

  setup_all do
    tsc = Harness.tool!("tsc")
    dir = Path.join(System.tmp_dir!(), "ash_surface_t17_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)

    File.cp_r!(
      Path.join(Harness.repo_root(), "test/ts/inference_t17/shouldPass"),
      Path.join(dir, "shouldPass")
    )

    File.write!(Path.join(dir, "schemas.ts"), Fixture.source())
    on_exit(fn -> File.rm_rf!(dir) end)
    %{tsc: tsc, dir: dir}
  end

  test "emitted fixture declarations compile alone", %{tsc: tsc, dir: dir} do
    {out, status} = Harness.run(tsc, @flags ++ ["schemas.ts"], dir)
    assert status == 0, out
  end

  for name <- ~w(structFieldSelection testStructFieldSelection) do
    test "#{name}.ts adapts to a clean tsc --strict case with live negative controls",
         %{tsc: tsc, dir: dir} do
      {out, status} = Harness.run(tsc, @flags ++ ["shouldPass/#{unquote(name)}.ts"], dir)
      assert status == 0, out
    end
  end

  test "shorthand is rejected when args are required, unknown fields and strict objects hold",
       %{tsc: tsc, dir: dir} do
    File.write!(
      Path.join(dir, "schemas_req.ts"),
      AshSurface.Projectors.JS.Inference.emit([
        {"Todo",
         [
           %{name: "id", ts: "string", primitive?: true},
           %{name: "title", ts: "string", primitive?: true},
           %{
             name: "self",
             ts:
               ~S[{ __type: "ComplexCalculation"; __returnType: TodoSchema; __args: { prefix: string } }],
             primitive?: false
           },
           %{
             name: "other",
             ts:
               ~S[{ __type: "ComplexCalculation"; __returnType: TodoSchema; __args: { prefix?: string } }],
             primitive?: false
           }
         ]}
      ])
    )

    File.write!(Path.join(dir, "control_req.ts"), """
    import type { UnifiedFieldSelection, TodoSchema } from "./schemas_req";
    // @ts-expect-error shorthand rejected: self requires args
    export const a = [{ self: ["id"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
    // @ts-expect-error unknown field in shorthand
    export const b = [{ other: ["nope"] }] satisfies UnifiedFieldSelection<TodoSchema>[];
    // @ts-expect-error strict object: extra key rejected
    export const c = [{ other: { args: {}, fields: ["id"], extra: 1 } }] satisfies UnifiedFieldSelection<TodoSchema>[];
    export const ok = [{ other: ["id"] }, { self: { args: { prefix: "x" }, fields: ["id"] } }] satisfies UnifiedFieldSelection<TodoSchema>[];
    """)

    {out, status} = Harness.run(tsc, @flags ++ ["control_req.ts"], dir)
    assert status == 0, out
  end

  test "a wrong expectation is rejected (tsc is not vacuous here)", %{tsc: tsc, dir: dir} do
    File.write!(Path.join(dir, "control.ts"), """
    import type { InferResult, TodoSchema } from "./schemas";
    declare const r: InferResult<TodoSchema, [{ self: ["id"] }]>;
    export const wrong: number = r.self.id;
    """)

    {out, status} = Harness.run(tsc, @flags ++ ["control.ts"], dir)
    assert status != 0
    assert out =~ "error TS"
  end
end
