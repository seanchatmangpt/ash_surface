Code.ensure_loaded?(AshSurface.Ported.TS.Zod.Cases) ||
  Code.require_file("support/zod_cases.exs", __DIR__)

defmodule AshSurface.Ported.TS.Zod.ZodUsageTest do
  @moduledoc """
  Adaptations of ash_typescript `test/ts/zod/shouldPass/{basicZodUsage,complexSchemaValidation}.ts`
  and `test/ts/zod/shouldFail/{invalidZodUsage,complexInvalidSchemas}.ts`.

  The references compile TS against generated `ash_zod.ts` (`z.infer` assignments, `.parse`
  calls, schema-method misuse). ash_surface emits no `.ts` (README), so each case runs against
  the emitted artifact schema under real node + real zod:

    * compile-time type errors in the reference (`z.infer` wrong value) become the runtime
      rejection of the same value with typed issues (`path: code`);
    * zod-API usage (`refine`, `transform`, `extend`, `omit`, absent methods) runs for real on the
      emitted schema via `js` cases;
    * reference checks that exist only as TS type assertions (`z.infer` aliases, `Partial`/
      `Required`, return-type annotations) have no runtime counterpart and are listed in the
      row's `changes` text.

  Wire names are snake_case and schemas `.passthrough()`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.Zod.Cases
  alias AshSurface.ZodFixtures.Harness

  @create "Todo.create"
  @uuid Cases.uuid()

  @valid %{"title" => "Valid title", "user_id" => @uuid}

  # Each entry: {name, spec}. spec is one of
  #   {:ok, id, payload}              accepted
  #   {:reject, id, payload, issues}  refused, issues all present (path: code)
  #   {:js, body, expected}           body returns a JSON value equal to expected
  #   {:js_throws, body, error_name}  body throws an error with that name
  @table [
    # ---- shouldPass/basicZodUsage.ts
    {"basic testCreateTodoValidation",
     {:ok, @create,
      %{
        "title" => "Complete project",
        "description" => "Finish the TypeScript generation feature",
        "status" => "pending",
        "user_id" => @uuid
      }}},
    {"basic testListTodosValidation / validateListInput",
     {:ok, "Todo.read", %{"filter_completed" => true, "priority_filter" => "high"}}},
    {"basic testMinimalValidation",
     {:ok, @create, %{"title" => "Minimal todo", "user_id" => @uuid}}},
    {"basic testGetTodoValidation (get_by_id takes its id key)",
     {:ok, "Todo.get_by_id", %{"id" => @uuid}}},
    {"basic testFullValidation",
     {:ok, @create,
      %{
        "title" => "Complete todo",
        "description" => "A fully specified todo item",
        "status" => "pending",
        "priority" => "high",
        "completed" => false,
        "auto_complete" => true,
        "user_id" => @uuid,
        "due_date" => "2024-12-31"
      }}},
    {"basic validateCreateInput",
     {:ok, @create, %{"title" => "Via validateCreateInput", "user_id" => @uuid}}},
    {"basic testSafeParsing",
     {:js,
      ~S'const r = S["Todo.create"].safeParse({title:"Test todo", user_id:"__UUID__"}); return [r.success, r.success && r.data.title];',
      [true, "Test todo"]}},
    {"basic testSchemaRefinement",
     {:js,
      ~S'const s = S["Todo.create"].refine((d) => d.title.length > 0, {message:"Title cannot be empty"}); return s.parse({title:"Valid title", user_id:"__UUID__"}).title;',
      "Valid title"}},
    {"basic testSchemaRefinement (refinement failure carries its message)",
     {:js,
      ~S'const s = S["Todo.create"].refine((d) => d.title !== "bad", {message:"Title cannot be empty"}); const r = s.safeParse({title:"bad", user_id:"__UUID__"}); return [r.success, r.error.issues[0].code, r.error.issues[0].message];',
      [false, "custom", "Title cannot be empty"]}},
    {"basic testSchemaTransformation",
     {:js,
      ~S'const s = S["Todo.create"].transform((d) => ({...d, title: d.title.trim(), priority: d.priority || "medium"})); const o = s.parse({title:"  Trimmed title  ", user_id:"__UUID__"}); return [o.title, o.priority];',
      ["Trimmed title", "medium"]}},
    # ---- shouldPass/complexSchemaValidation.ts
    {"complex testEmbeddedResourceValidation (metadata embedded)",
     {:ok, @create,
      Map.put(@valid, "metadata", %{
        "category" => "work",
        "priority_score" => 8,
        "labels" => ["urgent", "project"],
        "creator_id" => @uuid
      })}},
    {"complex testComplexTodoCreation",
     {:ok, @create,
      Map.merge(@valid, %{
        "title" => "Complex Todo Item",
        "description" => "A todo with all possible fields filled",
        "status" => "ongoing",
        "priority" => "high",
        "auto_complete" => true,
        "due_date" => "2024-12-31",
        "tags" => ["important", "deadline", "project-x"],
        "metadata" => %{"category" => "work", "priority_score" => 9, "labels" => ["critical"]},
        "content" => %{
          "content_type" => "text",
          "text" => %{"text" => "Detailed description of the todo item"}
        }
      })}},
    {"complex testSchemaWithTransforms",
     {:js,
      ~S'const s = S["Todo.create"].omit({user_id:true}).extend({user_id: z.string().default("default-user")}).transform((d) => ({...d, title: d.title.trim(), priority: d.priority || "medium", tags: d.tags || []})); const o = s.parse({title:"  Todo with transforms  ", description:"Testing schema transforms"}); return [o.title, o.user_id, o.priority, o.tags];',
      ["Todo with transforms", "default-user", "medium", []]}},
    {"complex testNestedObjectValidation",
     {:ok, @create,
      Map.put(@valid, "metadata", %{
        "category" => "personal",
        "priority_score" => 5,
        "labels" => ["leisure", "optional"],
        "custom_fields" => %{"difficulty" => "easy", "dependencies" => ["task-1", "task-2"]}
      })}},
    {"complex testArrayFieldValidation",
     {:ok, @create,
      Map.merge(@valid, %{
        "tags" => ["tag1", "tag2", "tag3"],
        "attachments" => [
          %{
            "attachment_type" => "file",
            "file" => %{"filename" => "document.pdf", "size" => 1024}
          },
          %{"attachment_type" => "image", "image" => %{"filename" => "image.png", "width" => 20}}
        ]
      })}},
    {"complex testDateTimeValidation",
     {:ok, @create,
      Map.merge(@valid, %{
        "due_date" => "2024-12-31",
        "metadata" => %{"category" => "c", "created_at" => "2024-12-31T23:59:59.999Z"}
      })}},
    {"complex testConditionalValidation (urgent needs due date)",
     {:js,
      ~S'const s = S["Todo.create"].refine((d) => d.priority === "urgent" ? d.due_date !== undefined : true, {message:"Urgent todos must have a due date", path:["due_date"]}); const ok = s.safeParse({title:"Urgent todo", user_id:"__UUID__", priority:"urgent", due_date:"2024-12-31"}); const bad = s.safeParse({title:"Urgent todo", user_id:"__UUID__", priority:"urgent"}); return [ok.success, bad.success, bad.error.issues[0].path.join("."), bad.error.issues[0].message];',
      [true, false, "due_date", "Urgent todos must have a due date"]}},
    {"complex testSchemaComposition",
     {:js,
      ~S'const base = z.object({title: z.string(), description: z.string().optional()}); const ext = base.extend({user_id: z.string(), priority: z.enum(["low","medium","high","urgent"]).optional()}); const merged = ext.extend({tags: z.array(z.string()).optional(), completed: z.boolean().optional()}); return merged.parse({title:"Composed schema test", user_id:"u", priority:"high", tags:["a"], completed:false}).priority;',
      "high"}},
    # ---- shouldFail/invalidZodUsage.ts
    {"invalid testInvalidTypeUsage (title number)",
     {:reject, @create, %{"title" => 123, "user_id" => @uuid}, ["title: invalid_type"]}},
    {"invalid testInvalidTypeUsage (title object)",
     {:reject, @create, %{"title" => %{"nested" => "object"}, "user_id" => @uuid},
      ["title: invalid_type"]}},
    {"invalid testInvalidTypeUsage (user_id array)",
     {:reject, @create, %{"title" => "Valid title", "user_id" => ["array", "of", "string"]},
      ["user_id: invalid_type"]}},
    {"invalid testMissingRequiredFields (title missing)",
     {:reject, @create, %{"user_id" => @uuid, "description" => "Missing title field"},
      ["title: invalid_type"]}},
    {"invalid testMissingRequiredFields (user_id missing)",
     {:reject, @create, %{"title" => "Valid title", "description" => "Missing user_id"},
      ["user_id: invalid_type"]}},
    {"invalid testMissingRequiredFields (empty object)",
     {:reject, @create, %{}, ["title: invalid_type", "user_id: invalid_type"]}},
    {"invalid testInvalidEnumValues (priority)",
     {:reject, @create, Map.put(@valid, "priority", "invalid_priority"),
      ["priority: invalid_value"]}},
    {"invalid testInvalidEnumValues (status)",
     {:reject, @create, Map.put(@valid, "status", "invalid_status"), ["status: invalid_value"]}},
    {"invalid testInvalidEnumValues (numeric priority)",
     {:reject, @create, Map.put(@valid, "priority", 1), ["priority: invalid_value"]}},
    {"invalid testInvalidSchemaMethodUsage (parseSync is not a zod method; zod 4 does define validate, unlike the reference zod 3 era assumption)",
     {:js, ~S'const s = S["Todo.create"]; return [typeof s.parseSync, typeof s.validate];',
      ["undefined", "function"]}},
    {"invalid testInvalidSchemaComposition (pick of an unknown key throws)",
     {:js_throws, ~S'S["Todo.create"].pick({nonExistentField: true});', "Error"}},
    {"invalid testWrongReturnTypes (a schema is not callable)",
     {:js_throws, ~S'S["Todo.create"]({title: "Valid title"});', "TypeError"}},
    {"invalid testWrongReturnTypes (parse returns an object, safeParse a result)",
     {:js,
      ~S'const s = S["Todo.create"]; const v = {title:"Valid title", user_id:"__UUID__"}; return [typeof s.parse(v), typeof s.safeParse(v).success];',
      ["object", "boolean"]}},
    {"invalid testInvalidOptionalUsage (title undefined)",
     {:reject, @create, %{"title" => :undefined_marker, "user_id" => @uuid},
      ["title: invalid_type"]}},
    {"invalid testInvalidOptionalUsage (user_id null)",
     {:reject, @create, %{"title" => "Valid title", "user_id" => nil}, ["user_id: invalid_type"]}},
    {"invalid testInvalidTransformUsage / testInvalidSchemaComposition (zod allows extend at runtime; only the TS inference differed)",
     {:js,
      ~S'const e = S["Todo.create"].extend({title: z.number()}); return [e.safeParse({title: 5, user_id:"__UUID__"}).success, e.safeParse({title: "x", user_id:"__UUID__"}).success];',
      [true, false]}},
    # ---- shouldFail/complexInvalidSchemas.ts
    {"complexInvalid testInvalidEmbeddedFields (priority_score string)",
     {:reject, @create,
      Map.put(@valid, "metadata", %{"category" => "work", "priority_score" => "high"}),
      ["metadata.priority_score: invalid_type"]}},
    {"complexInvalid testInvalidEmbeddedFields (labels string)",
     {:reject, @create,
      Map.put(@valid, "metadata", %{"category" => "work", "labels" => "urgent"}),
      ["metadata.labels: invalid_type"]}},
    {"complexInvalid testInvalidNestedStructures (metadata array)",
     {:reject, @create, Map.put(@valid, "metadata", ["should", "be", "object"]),
      ["metadata: invalid_type"]}},
    {"complexInvalid testInvalidNestedStructures (content with no union member)",
     {:reject, @create,
      Map.put(@valid, "content", %{"invalid_field" => "not part of any union member"}),
      ["content: invalid_union"]}},
    {"complexInvalid testInvalidArrayTypes (numeric tags)",
     {:reject, @create, Map.put(@valid, "tags", [1, 2, 3]),
      ["tags.0: invalid_type", "tags.1: invalid_type", "tags.2: invalid_type"]}},
    {"complexInvalid testInvalidArrayTypes (single string)",
     {:reject, @create, Map.put(@valid, "tags", "single-tag"), ["tags: invalid_type"]}},
    {"complexInvalid testInvalidArrayTypes (mixed)",
     {:reject, @create, Map.put(@valid, "tags", ["string", 123, true]),
      ["tags.1: invalid_type", "tags.2: invalid_type"]}},
    {"complexInvalid testInvalidDateFormats (Date object)",
     {:js,
      ~S'const r = S["Todo.create"].safeParse({title:"t", user_id:"__UUID__", due_date: new Date()}); return [r.success, r.error.issues.map((i) => i.path.join(".") + ": " + i.code)];',
      [false, ["due_date: invalid_type"]]}},
    {"complexInvalid testInvalidDateFormats (invalid string)",
     {:reject, @create, Map.put(@valid, "due_date", "not-a-date"), ["due_date: invalid_format"]}},
    {"complexInvalid testInvalidDateFormats (timestamp number)",
     {:reject, @create, Map.put(@valid, "due_date", 1_640_995_200_000),
      ["due_date: invalid_type"]}},
    {"complexInvalid testInvalidSchemaChaining (a transform pipe has no extend)",
     {:js_throws, ~S'S["Todo.create"].transform((d) => d.title).extend({new_field: z.string()});',
      "TypeError"}},
    {"complexInvalid testInvalidConditionalRefinements (string error is a custom message at runtime)",
     {:js,
      ~S'const s = S["Todo.create"].refine(() => false, "should be object with message property"); const r = s.safeParse({title:"t", user_id:"__UUID__"}); return [r.success, r.error.issues[0].message];',
      [false, "should be object with message property"]}},
    {"complexInvalid testInvalidSchemaComposition (conflicting extend narrows to the new type)",
     {:js,
      ~S'const e = S["Todo.create"].extend({title: z.number(), user_id: z.boolean()}); return [e.safeParse({title: 1, user_id: true}).success, e.safeParse({title: "x", user_id: "u"}).success];',
      [true, false]}},
    {"complexInvalid testInvalidOptionalRequiredMismatches (partial() makes every key optional, required keys stay required here)",
     {:js,
      ~S'const s = S["Todo.create"]; return [s.partial().safeParse({}).success, s.safeParse({}).success];',
      [true, false]}}
  ]

  setup_all do
    ts_dir = Cases.workspace!()
    on_exit(fn -> Harness.cleanup!(ts_dir) end)

    cases =
      for {name, spec} <- @table do
        case spec do
          {:ok, id, p} -> %{label: name, id: id, payload: p}
          {:reject, id, p, _} -> %{label: name, id: id, payload: fix(p)}
          {:js, body, _} -> %{label: name, js: String.replace(body, "__UUID__", @uuid)}
          {:js_throws, body, _} -> %{label: name, js: String.replace(body, "__UUID__", @uuid)}
        end
      end

    %{results: Cases.run!(ts_dir, cases) |> Map.new(&{&1["label"], &1})}
  end

  # JSON has no `undefined`: the marker is dropped so the key is absent (what `title: undefined`
  # means to zod's object parser for a required key).
  defp fix(p) when is_map(p),
    do: p |> Enum.reject(fn {_k, v} -> v == :undefined_marker end) |> Map.new()

  for {name, spec} <- @table do
    test name, %{results: results} do
      r = Map.fetch!(results, unquote(name))

      case unquote(Macro.escape(spec)) do
        {:ok, _, _} ->
          assert r["success"] == true, "rejected: #{inspect(r["issues"])}"

        {:reject, _, _, issues} ->
          assert r["success"] == false, "accepted"

          for i <- issues,
              do: assert(i in r["issues"], "#{i} not in #{inspect(r["issues"])}")

        {:js, _, expected} ->
          refute Map.has_key?(r, "thrown"), "threw: #{inspect(r)}"
          assert r["value"] == expected

        {:js_throws, _, error_name} ->
          assert r["thrown"], "did not throw: #{inspect(r)}"
          assert r["name"] == error_name, inspect(r)
      end
    end
  end
end
