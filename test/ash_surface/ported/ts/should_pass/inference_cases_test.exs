defmodule AshSurface.Ported.TS.ShouldPass.Fixture do
  @moduledoc "Private Inference fixture (real `Inference.emit/1` + `action_types/1`; no doubles)."
  alias AshSurface.Projectors.JS.Inference

  defp f(name, ts, prim?), do: %{name: name, ts: ts, primitive?: prim?}
  defp p(name, ts), do: f(name, ts, true)
  defp rel(name, ts), do: f(name, ts, false)

  @palette "{ primary: string; secondary: string; accent: string }"

  def resources do
    [
      {"Todo",
       [
         p("id", "string"),
         p("title", "string"),
         p("status", "string"),
         p("description", "string | null"),
         p("completed", "boolean | null"),
         p("priority", "string | null"),
         p("priorityScore", "number | null"),
         p("isOverdue", "boolean | null"),
         p("commentCount", "number"),
         p("helpfulCommentCount", "number"),
         p("hasComments", "boolean"),
         p("averageRating", "number | null"),
         p("createdAt", "string"),
         p("tags", "string[] | null"),
         p("colorPalette", @palette <> " | null"),
         p("customData", "Record<string, any> | null"),
         rel("user", ~S[{ __type: "Relationship"; __resource: UserSchema }]),
         rel(
           "comments",
           ~S[{ __type: "Relationship"; __resource: CommentSchema; __array: true }]
         ),
         rel("meta", "TodoMetaSchema"),
         rel("options", "OptionsSchema | null"),
         rel("statistics", "StatisticsSchema | null"),
         rel("summary", "SummarySchema | null"),
         rel("content", "ContentSchema | null"),
         rel("firstCommentMetadata", "CommentMetadataSchema | null"),
         rel(
           "self",
           ~S[{ __type: "ComplexCalculation"; __returnType: TodoSchema; __args: { prefix?: string } }]
         )
       ]},
      {"User",
       [
         p("id", "string"),
         p("name", "string"),
         p("email", "string"),
         p("active", "boolean | null"),
         p("isSuperAdmin", "boolean | null"),
         rel("todos", ~S[{ __type: "Relationship"; __resource: TodoSchema; __array: true }])
       ]},
      {"Comment",
       [
         p("id", "string"),
         p("content", "string"),
         p("authorName", "string"),
         p("rating", "number | null"),
         p("isHelpful", "boolean | null"),
         rel("user", ~S[{ __type: "Relationship"; __resource: UserSchema }])
       ]},
      {"TaskStats",
       [
         p("totalCount", "number | null"),
         p("completed", "boolean | null"),
         p("isUrgent", "boolean | null"),
         p("averageDuration", "number | null")
       ]},
      {"ContentRecord",
       [
         p("id", "string"),
         p("title", "string"),
         p("type", "string | null"),
         p("category", ~S["fitness" | "mindset" | "nutrition" | "progress"]),
         p("thumbnailUrl", "string"),
         p("thumbnailAlt", "string"),
         p("publishedAt", "string | null"),
         p("authorId", "string | null"),
         rel("item", "ItemUnionSchema"),
         rel("author", ~S[{ __type: "Relationship"; __resource: UserSchema | null }])
       ]},
      {"Assignment",
       [
         p("assigneeId", "string"),
         p("assigneeName", "string"),
         p("reason", "string | null")
       ]}
    ]
  end

  @extra ~S"""

  export type TodoMetaSchema = { __type: "TypedMap"; __primitiveFields: "category" | "isUrgent"; category: string; isUrgent: boolean | null };
  export type OptionsSchema = { __type: "TypedMap"; __primitiveFields: "priority"; priority: number };
  export type StatisticsSchema = { __type: "TypedMap"; __primitiveFields: "viewCount"; viewCount: number | null };
  export type PerformanceMetricsSchema = {
    __type: "TypedMap";
    __primitiveFields: "focusTimeSeconds" | "interruptionCount" | "efficiencyScore" | "taskComplexity";
    focusTimeSeconds: number;
    interruptionCount: number;
    efficiencyScore: number;
    taskComplexity: string | null;
  };
  export type SummarySchema = {
    __type: "TypedMap";
    __primitiveFields: "viewCount" | "editCount" | "completionTimeSeconds" | "difficultyRating" | "allCompleted";
    viewCount: number | null;
    editCount: number | null;
    completionTimeSeconds: number | null;
    difficultyRating: number | null;
    allCompleted: boolean | null;
    performanceMetrics: PerformanceMetricsSchema | null;
  };
  export type SettingsSchema = {
    __type: "TypedMap";
    __primitiveFields: "notifications" | "autoArchive" | "reminderFrequency";
    notifications: boolean | null;
    autoArchive: boolean | null;
    reminderFrequency: number | null;
  };
  export type CommentMetadataSchema = {
    __type: "TypedMap";
    __primitiveFields: "id" | "category" | "isUrgent" | "priorityScore" | "deadline" | "tags" | "creatorId" | "createdAt" | "estimatedHours";
    id: string;
    category: string;
    isUrgent: boolean | null;
    priorityScore: number | null;
    deadline: string | null;
    tags: string[] | null;
    creatorId: string | null;
    createdAt: string | null;
    estimatedHours: number | null;
    settings: SettingsSchema | null;
  };
  export type TextContentSchema = { __type: "TypedMap"; __primitiveFields: "text" | "wordCount"; text: string; wordCount: number | null };
  export type ChecklistContentSchema = { __type: "TypedMap"; __primitiveFields: "title"; title: string };
  export type ContentSchema = {
    __type: "Union";
    __primitiveFields: "note";
    note: string;
    text: TextContentSchema;
    checklist: ChecklistContentSchema;
  };
  export type ArticleItemSchema = { __type: "TypedMap"; __primitiveFields: "id" | "heroImageAlt"; id: string; heroImageAlt: string };
  export type ItemUnionSchema = { __type: "Union"; __primitiveFields: never; article: ArticleItemSchema };
  """

  def actions do
    [
      %{name: "ListTodos", schema: "TodoSchema", pagination: :mixed, pagination_optional?: true},
      %{
        name: "ListTodoCommentsKeyset",
        schema: "CommentSchema",
        pagination: :keyset,
        pagination_optional?: true
      },
      %{
        name: "GetSingleTodo",
        schema: "TodoSchema",
        kind: :get,
        args_ts: "{ filterCompleted?: boolean; priorityFilter?: string }"
      },
      %{name: "GetSingleTodoNullable", schema: "TodoSchema", kind: :get, not_found_error?: false},
      %{name: "GetUserByEmail", schema: "UserSchema", kind: :get, args_ts: "{ email: string }"},
      %{
        name: "GetUserByEmailNullable",
        schema: "UserSchema",
        kind: :get,
        not_found_error?: false
      },
      %{
        name: "GetTodoByUserAndStatus",
        schema: "TodoSchema",
        kind: :get,
        args_ts: "{ userId: string; status: string }"
      },
      %{
        name: "CreateTodo",
        schema: "TodoSchema",
        kind: :create,
        args_ts: "{ title: string; status: string; userId: string; colorPalette?: #{@palette} }"
      },
      %{
        name: "CreateContent",
        schema: "ContentRecordSchema",
        kind: :create,
        args_ts:
          "{ type?: string; title: string; thumbnailUrl: string; thumbnailAlt: string; publishedAt?: string; category?: \"fitness\" | \"mindset\" | \"nutrition\" | \"progress\"; authorId?: string; userId: string; item: { heroImageUrl: string; heroImageAlt: string; summary: string; body: string } }"
      },
      %{
        name: "AssignToUserTodo",
        schema: "AssignmentSchema",
        kind: :action,
        args_ts: "{ assignee: { id: string; name: string; email: string }; reason?: string }"
      },
      %{
        name: "AssignToUsersTodo",
        schema: "AssignmentSchema",
        kind: :action,
        args_ts: "{ assignees: Array<{ id: string; name: string; email: string }> }"
      },
      %{
        name: "UpdateTodoWithUntypedData",
        schema: "TodoSchema",
        kind: :update,
        args_ts: "{ additionalData?: Record<string, any>; metadataUpdate?: Record<string, any> }"
      },
      %{name: "CreateUser", schema: "UserSchema", kind: :create},
      %{name: "UpdateUser", schema: "UserSchema", kind: :update},
      %{
        name: "ReadTasksWithMetadata",
        schema: "TaskSchema",
        metadata: [
          %{name: "someString", ts: "string"},
          %{name: "someNumber", ts: "number"},
          %{name: "someBoolean", ts: "boolean | null"}
        ]
      }
    ]
  end

  @task "export type TaskSchema = { __type: \"Resource\"; __primitiveFields: \"id\" | \"title\" | \"completed\"; \"id\": string; \"title\": string; \"completed\": boolean };\n"

  def source do
    Inference.emit(resources()) <>
      @extra <>
      @task <> Enum.map_join(actions(), "\n", &Inference.action_types/1)
  end
end

defmodule AshSurface.Ported.TS.ShouldPass.InferenceCasesTest do
  @moduledoc """
  Ports of ash_typescript `test/ts/shouldPass/*.ts` whose subject is result/selection/pagination
  type inference. ash_surface generates no `.ts` (README), so each reference case is adapted to a
  `tsc --strict` case over the declarations `Inference.emit/1` + `Inference.action_types/1`
  really emit (tsc is a test tool only). `// @ts-expect-error` lines are the negative
  controls: tsc reports an unused expect-error as an error, so a vacuous case fails.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.ShouldPass.Fixture
  alias AshSurface.ZodFixtures.Harness

  @flags ~w(--strict --noEmit --skipLibCheck --module esnext --moduleResolution bundler --target es2022)
  @cases ~w(complexScenarios customTypes firstAggregates genericActionTypedStruct get getBy
            hoistedSatisfiesFields metadata structArguments untypedMaps argsWithFieldConstraints noArgCalculations noFieldsTypeInference
            precisePaginationTypes unionCalculationSyntax)

  setup_all do
    tsc = Harness.tool!("tsc")
    dir = Path.join(System.tmp_dir!(), "ash_surface_t15_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)

    File.cp_r!(
      Path.join(Harness.repo_root(), "test/ts/inference_t15/shouldPass"),
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

  for name <- @cases do
    test "#{name}.ts adapts to a clean tsc --strict case with live negative controls",
         %{tsc: tsc, dir: dir} do
      file = "shouldPass/#{unquote(name)}.ts"
      assert File.exists?(Path.join(dir, file))
      {out, status} = Harness.run(tsc, @flags ++ [file], dir)
      assert status == 0, "#{file}:\n" <> out
    end
  end

  test "a wrong expectation is rejected (control: tsc is not vacuous here)", %{tsc: tsc, dir: dir} do
    File.write!(Path.join(dir, "control.ts"), """
    import type { InferResult, UnifiedFieldSelection, TodoSchema } from "./schemas";
    const sel = ["id"] satisfies UnifiedFieldSelection<TodoSchema>[];
    declare const r: InferResult<TodoSchema, typeof sel>;
    export const wrong: number = r.id;
    """)

    {out, status} = Harness.run(tsc, @flags ++ ["control.ts"], dir)
    assert status != 0
    assert out =~ "error TS"
  end
end
