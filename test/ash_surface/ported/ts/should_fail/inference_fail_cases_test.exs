defmodule AshSurface.Ported.TS.ShouldFail.Fixture do
  @moduledoc "Private T16 Inference fixture (real `Inference.emit/1` + `action_types/1`; no doubles)."
  alias AshSurface.Projectors.JS.Inference

  defp f(name, ts, prim?), do: %{name: name, ts: ts, primitive?: prim?}
  defp p(name, ts), do: f(name, ts, true)
  defp rel(name, ts), do: f(name, ts, false)

  @fi "{ rating?: { greaterThan?: number; eq?: number }; id?: { eq?: string } }"

  defp comments(extra),
    do: ~s[{ __type: "Relationship"; __resource: CommentSchema; __array: true#{extra} }]

  def resources do
    [
      {"Todo",
       [
         p("id", "string"),
         p("title", "string"),
         p("status", "string"),
         p("description", "string | null"),
         p("completed", "boolean | null"),
         rel("user", ~S[{ __type: "Relationship"; __resource: UserSchema }]),
         rel(
           "comments",
           comments(
             ~s[; __pagination: "mixed"; __filterInput: #{@fi}; __sortField: "rating" | "id"]
           )
         ),
         rel(
           "unfilterableComments",
           comments(~s[; __pagination: "mixed"; __sortField: "rating" | "id"])
         ),
         rel("unsortableComments", comments(~s[; __pagination: "mixed"; __filterInput: #{@fi}])),
         rel("unpaginatedComments", comments("")),
         rel("offsetComments", comments(~s[; __pagination: "offset"])),
         rel("keysetComments", comments(~s[; __pagination: "keyset"])),
         rel("meta", "MetaSchema"),
         rel("firstCommentMetadata", "CommentMetadataSchema | null"),
         rel(
           "self",
           ~S[{ __type: "ComplexCalculation"; __returnType: TodoSchema; __args: { prefix?: string | null } }]
         )
       ]},
      {"User", [p("id", "string"), p("name", "string"), p("email", "string")]},
      {"Comment", [p("id", "string"), p("content", "string"), p("rating", "number | null")]}
    ]
  end

  @extra ~S"""

  export type MetaSchema = { __type: "TypedMap"; __primitiveFields: "k" | "n"; k: string; n: number };
  export type CommentMetadataSchema = {
    __type: "TypedMap";
    __primitiveFields: "category" | "priorityScore";
    category: string;
    priorityScore: number | null;
  };
  """

  def actions do
    prio = ~S["low" | "medium" | "high" | "urgent"]
    status = ~S["pending" | "ongoing" | "finished" | "cancelled"]

    [
      %{name: "ListTodos", schema: "TodoSchema"},
      %{name: "GetSingleTodo", schema: "TodoSchema", kind: :get},
      %{
        name: "CreateTodo",
        schema: "TodoSchema",
        kind: :create,
        args_ts:
          "{ title: string; completed?: boolean; priority?: #{prio}; status?: #{status}; userId: string }"
      },
      %{name: "DestroyTodo", schema: "TodoSchema", kind: :destroy},
      %{name: "SearchTodos", schema: "TodoSchema", args_ts: "{ query: string }"}
    ]
  end

  def source do
    Inference.emit(resources()) <>
      @extra <> Enum.map_join(actions(), "\n", &Inference.action_types/1)
  end
end

defmodule AshSurface.Ported.TS.ShouldFail.InferenceFailCasesTest do
  @moduledoc """
  Ports of ash_typescript `test/ts/shouldFail/*.ts` whose subject is TS type-level refusal.
  ash_surface generates no `.ts` (README), so each reference case is adapted to a `tsc --strict`
  case over the declarations `Inference.emit/1` + `Inference.action_types/1` really emit.
  Each refused line carries `// @ts-expect-error`: tsc fails an unused directive, so a case that
  stops failing is itself an error. The mutation control strips every directive from a real tmp
  copy and requires tsc to then report at least one error per stripped directive, proving the
  directives guard real refusals and are not vacuous.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.ShouldFail.Fixture
  alias AshSurface.ZodFixtures.Harness

  @flags ~w(--strict --noEmit --skipLibCheck --module esnext --moduleResolution bundler --target es2022)
  @cases ~w(firstAggregates invalidCalcArgs nestedQueryOpts nonFieldCalculations operations)

  setup_all do
    tsc = Harness.tool!("tsc")
    dir = Path.join(System.tmp_dir!(), "ash_surface_t16_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)

    File.cp_r!(
      Path.join(Harness.repo_root(), "test/ts/inference_t16/shouldFail"),
      Path.join(dir, "shouldFail")
    )

    File.write!(Path.join(dir, "schemas.ts"), Fixture.source())
    on_exit(fn -> File.rm_rf!(dir) end)
    %{tsc: tsc, dir: dir}
  end

  test "emitted fixture declarations compile alone", %{tsc: tsc, dir: dir} do
    {out, status} = Harness.run(tsc, @flags ++ ["schemas.ts"], dir)
    assert status == 0, out
  end

  for name <- @cases do
    test "#{name}.ts: every refusal is a live tsc error (no unused @ts-expect-error)",
         %{tsc: tsc, dir: dir} do
      file = "shouldFail/#{unquote(name)}.ts"
      {out, status} = Harness.run(tsc, @flags ++ [file], dir)
      assert status == 0, "#{file}:\n" <> out
    end

    test "#{name}.ts: stripping the directives makes tsc fail once per refusal (non-vacuity)",
         %{tsc: tsc, dir: dir} do
      src = File.read!(Path.join(dir, "shouldFail/#{unquote(name)}.ts"))
      lines = String.split(src, "\n")
      directives = Enum.count(lines, &(&1 =~ "@ts-expect-error"))
      assert directives >= 1

      stripped =
        lines |> Enum.reject(&(&1 =~ "@ts-expect-error")) |> Enum.join("\n")

      File.write!(Path.join(dir, "shouldFail/mut_#{unquote(name)}.ts"), stripped)
      {out, status} = Harness.run(tsc, @flags ++ ["shouldFail/mut_#{unquote(name)}.ts"], dir)
      assert status != 0, "stripped #{unquote(name)} still compiles"
      errors = out |> String.split("\n") |> Enum.count(&(&1 =~ "error TS"))
      assert errors >= directives, "#{errors} errors < #{directives} directives:\n" <> out
    end
  end
end
