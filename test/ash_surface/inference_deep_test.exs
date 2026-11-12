defmodule AshSurface.InferenceDeepTest do
  use ExUnit.Case, async: true
  alias AshSurface.Projectors.JS.Inference

  @tsc Path.expand("node_modules/.bin/tsc")

  @post [
    {"Post",
     [
       %{name: "id", ts: "string", primitive?: true},
       %{name: "title", ts: "string", primitive?: true},
       %{name: "views", ts: "number", primitive?: true},
       %{
         name: "comments",
         ts:
           ~s({ __type: "Relationship"; __resource: CommentSchema; __array: true; __pagination: "offset" }),
         primitive?: false
       }
     ]},
    {"Comment",
     [
       %{name: "id", ts: "string", primitive?: true},
       %{name: "body", ts: "string", primitive?: true}
     ]}
  ]

  defp tsc!(body) do
    assert File.exists?(@tsc), "tsc missing at #{@tsc}: run npm install"
    dir = Path.join(System.tmp_dir!(), "infd_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    file = Path.join(dir, "a.ts")
    File.write!(file, body)

    System.cmd(@tsc, ["--noEmit", "--strict", "--target", "es2020", file], stderr_to_stdout: true)
  end

  defp doc(action_blocks, tail) do
    Inference.emit(@post) <>
      "\n" <> Enum.join(action_blocks, "\n") <> "\n" <> tail <> "\nexport {};\n"
  end

  defp assert_compiles(blocks, tail), do: assert({"", 0} == tsc!(doc(blocks, tail)))

  defp assert_rejected(blocks, tail) do
    {out, code} = tsc!(doc(blocks, tail))
    assert code != 0, "expected tsc to reject, got: #{out}"
    out
  end

  defp read_spec(extra \\ %{}), do: Map.merge(%{name: "ListPosts", schema: "PostSchema"}, extra)

  describe "emitted shape" do
    test "read action emits Fields, Config, Result" do
      out = Inference.action_types(read_spec())
      assert out =~ "export type ListPostsFields = UnifiedFieldSelection<PostSchema>[];"
      assert out =~ "export type ListPostsConfig = {\n  fields: ListPostsFields;\n};"
      assert out =~ "InferListPostsResult"
      assert out =~ "Array<InferResult<PostSchema, Fields>>"
      refute out =~ "Metadata"
    end

    test "deterministic" do
      s = read_spec(%{pagination: :mixed, pagination_optional?: true})
      assert Inference.action_types(s) == Inference.action_types(s)
    end

    test "invalid identifiers and kinds are refused" do
      assert_raise ArgumentError, fn -> Inference.action_types(read_spec(%{name: "a b"})) end

      assert_raise ArgumentError, fn ->
        Inference.action_types(read_spec(%{schema: "X; evil"}))
      end

      assert_raise ArgumentError, fn -> Inference.action_types(read_spec(%{kind: :bogus})) end
      assert_raise ArgumentError, fn -> Inference.action_types(read_spec(%{pagination: :x})) end
      assert_raise ArgumentError, fn -> Inference.action_types(read_spec(), page: "a-b") end
    end

    test "default names are exposed and overridable" do
      assert %{limit: "limit", has_more: "hasMore", fields: "fields"} = Inference.default_names()

      out =
        Inference.action_types(read_spec(%{pagination: :offset}),
          fields: "select",
          limit: "pageSize",
          page: "paging"
        )

      assert out =~ "select: ListPostsFields;"
      assert out =~ "paging?: ListPostsPageInput;"
      assert out =~ "pageSize?: number"
      assert out =~ "pageSize: number;"
    end
  end

  describe "tsc --strict" do
    test "plain read: array of selected fields" do
      assert_compiles(
        [Inference.action_types(read_spec())],
        """
        type R = InferListPostsResult<["id", "title"]>;
        const ok: R = [{ id: "1", title: "t" }];
        // @ts-expect-error views not selected
        const bad: R = [{ id: "1", title: "t", views: 1 }];
        export { ok, bad };
        """
      )
    end

    test "get: not_found_error? true is non-null, false adds | null" do
      get_t = Inference.action_types(%{name: "GetPost", schema: "PostSchema", kind: :get})

      get_n =
        Inference.action_types(%{
          name: "FindPost",
          schema: "PostSchema",
          kind: :get,
          not_found_error?: false
        })

      assert get_n =~ "| null"
      refute get_t =~ "| null"

      assert_compiles(
        [get_t, get_n],
        """
        const a: InferGetPostResult<["id"]> = { id: "1" };
        // @ts-expect-error null not allowed when not_found_error? is true
        const b: InferGetPostResult<["id"]> = null;
        const c: InferFindPostResult<["id"]> = null;
        const d: InferFindPostResult<["id"]> = { id: "1" };
        export { a, b, c, d };
        """
      )
    end

    test "destroy result is {}" do
      d = Inference.action_types(%{name: "DropPost", schema: "PostSchema", kind: :destroy})
      assert d =~ "export type InferDropPostResult = {};"

      assert_compiles(
        [d],
        """
        const r: InferDropPostResult = {};
        export { r };
        """
      )
    end

    test "metadata types and Pick narrowing" do
      spec =
        read_spec(%{
          metadata: [%{name: "someString", ts: "string"}, %{name: "someNumber", ts: "number"}]
        })

      out = Inference.action_types(spec)
      assert out =~ ~s("someNumber": number;)
      assert out =~ "MetadataFields extends ReadonlyArray<keyof ListPostsMetadata> = []"

      assert_compiles(
        [out],
        """
        type R = InferListPostsResult<["id"], ["someString"]>;
        const ok: R = [{ id: "1", someString: "s" }];
        // @ts-expect-error someNumber not requested
        const bad: R = [{ id: "1", someString: "s", someNumber: 1 }];
        type None = InferListPostsResult<["id"]>;
        const none: None = [{ id: "1" }];
        export { ok, bad, none };
        """
      )
    end

    test "mutation kinds return a single selected record" do
      c = Inference.action_types(%{name: "MakePost", schema: "PostSchema", kind: :create})
      u = Inference.action_types(%{name: "EditPost", schema: "PostSchema", kind: :update})

      assert_compiles(
        [c, u],
        """
        const a: InferMakePostResult<["id"]> = { id: "1" };
        const b: InferEditPostResult<["title"]> = { title: "t" };
        // @ts-expect-error array not a record
        const x: InferMakePostResult<["id"]> = [{ id: "1" }];
        export { a, b, x };
        """
      )
    end

    test "optional offset pagination narrows by Page generic" do
      out =
        Inference.action_types(read_spec(%{pagination: :offset, pagination_optional?: true}))

      assert_compiles(
        [out],
        """
        type NoPage = InferListPostsResult<["id"]>;
        const arr: NoPage = [{ id: "1" }];
        type Paged = InferListPostsResult<["id"], { limit: 5; offset: 0 }>;
        const pg: Paged = { results: [{ id: "1" }], hasMore: false, limit: 5, offset: 0, type: "offset" };
        // @ts-expect-error paged result is not an array
        const wrong: Paged = [{ id: "1" }];
        // @ts-expect-error unpaged result is not a page object
        const wrong2: NoPage = pg;
        export { arr, pg, wrong, wrong2 };
        """
      )
    end

    test "optional keyset pagination" do
      out =
        Inference.action_types(read_spec(%{pagination: :keyset, pagination_optional?: true}))

      assert_compiles(
        [out],
        """
        type Paged = InferListPostsResult<["id"], { limit: 5; after: "c" }>;
        const pg: Paged = {
          results: [{ id: "1" }], hasMore: true, limit: 5, after: null, before: null,
          previousPage: null, nextPage: "n", count: 3, type: "keyset",
        };
        export { pg };
        """
      )
    end

    test "optional mixed pagination narrows per strategy" do
      out =
        Inference.action_types(read_spec(%{pagination: :mixed, pagination_optional?: true}))

      assert_compiles(
        [out],
        """
        type Off = InferListPostsResult<["id"], { offset: 0; limit: 1 }>;
        const o: Off = { results: [], hasMore: false, limit: 1, offset: 0, type: "offset" };
        type Key = InferListPostsResult<["id"], { after: "x" }>;
        const k: Key = { results: [], hasMore: false, limit: 1, after: null, before: null,
          previousPage: null, nextPage: null, type: "keyset" };
        // @ts-expect-error offset page lacks keyset fields
        const bad: Key = o;
        export { o, k, bad };
        """
      )
    end

    test "required mixed pagination without Page yields the union, with Page narrows" do
      out = Inference.action_types(read_spec(%{pagination: :mixed}))

      assert_compiles(
        [out],
        """
        type U = InferListPostsResult<["id"]>;
        const o: U = { results: [], hasMore: false, limit: 1, offset: 0, type: "offset" };
        type K = InferListPostsResult<["id"], never>;
        type Off = InferListPostsResult<["id"], { offset: 1 }>;
        const f: Off = { results: [], hasMore: false, limit: 1, offset: 0, type: "offset" };
        export { o, f };
        export type { K };
        """
      )
    end

    test "metadata inside paginated results" do
      out =
        Inference.action_types(
          read_spec(%{
            pagination: :offset,
            pagination_optional?: true,
            metadata: [%{name: "score", ts: "number"}]
          })
        )

      assert_compiles(
        [out],
        """
        type P = InferListPostsResult<["id"], ["score"], { limit: 1; offset: 0 }>;
        const p: P = { results: [{ id: "1", score: 2 }], hasMore: false, limit: 1, offset: 0, type: "offset" };
        export { p };
        """
      )
    end

    test "Config accepts args, filter, sort, page and rejects unknown keys" do
      out =
        Inference.action_types(
          read_spec(%{
            pagination: :offset,
            args_ts: "{ q: string }",
            filter_ts: "{ title?: { eq?: string } }",
            sort_fields: ["title", "views"]
          })
        )

      assert_compiles(
        [out],
        """
        const cfg: ListPostsConfig = {
          fields: ["id"], args: { q: "x" }, filter: { title: { eq: "a" } },
          sort: ["-views", "+title"], page: { limit: 1, offset: 0, count: true },
        };
        // @ts-expect-error unknown sort field
        const bad: ListPostsConfig = { fields: ["id"], args: { q: "x" }, sort: "nope" };
        export { cfg, bad };
        """
      )
    end

    test "filter, sort and metadata types are not loosened to any" do
      cfg =
        Inference.action_types(
          read_spec(%{
            args_ts: "{ q: string }",
            filter_ts: "{ title?: { eq?: string } }",
            sort_fields: ["title", "views"]
          })
        )

      meta =
        Inference.action_types(
          read_spec(%{
            name: "ScoredPosts",
            metadata: [%{name: "score", ts: "number"}, %{name: "label", ts: "string"}]
          })
        )

      assert_compiles(
        [cfg, meta],
        """
        const okCfg: ListPostsConfig = {
          fields: ["id"], args: { q: "x" }, filter: { title: { eq: "a" } }, sort: ["title", "-views"],
        };
        // @ts-expect-error filter leaf has the wrong type
        const badFilter: ListPostsConfig = { fields: ["id"], args: { q: "x" }, filter: { title: { eq: 5 } } };
        // @ts-expect-error filter key is not part of the filter input
        const badFilterKey: ListPostsConfig = { fields: ["id"], args: { q: "x" }, filter: { nope: { eq: "a" } } };
        // @ts-expect-error sort array element is not a SortString of a sortable field
        const badSortElem: ListPostsConfig = { fields: ["id"], args: { q: "x" }, sort: ["title", 7] };
        // @ts-expect-error sort field is not in the sortable set (array form)
        const badSortField: ListPostsConfig = { fields: ["id"], args: { q: "x" }, sort: ["+nope"] };
        type R = InferScoredPostsResult<["id"], ["score"]>;
        const okMeta: R = [{ id: "1", score: 2 }];
        // @ts-expect-error metadata value has the wrong type
        const badMeta: R = [{ id: "1", score: "high" }];
        // @ts-expect-error a key that is not a declared metadata field cannot be requested
        type BadReq = InferScoredPostsResult<["id"], ["nope"]>;
        export { okCfg, badFilter, badFilterKey, badSortElem, badSortField, okMeta, badMeta };
        export type { BadReq };
        """
      )
    end

    test "nested relationship selection and nested page result via utility types" do
      assert_compiles(
        [],
        """
        const sel = ["id", { comments: { fields: ["body"], page: { limit: 1, offset: 0 } } }] as const;
        type R = InferResult<PostSchema, ["id", { comments: { fields: ["body"]; page: { limit: 1; offset: 0 } } }]>;
        const r: R = { id: "1", comments: { results: [{ body: "b" }], hasMore: false, limit: 1, offset: 0, type: "offset" } };
        type Flat = InferResult<PostSchema, ["id", { comments: ["body"] }]>;
        const f: Flat = { id: "1", comments: [{ body: "b" }] };
        // @ts-expect-error keyset keys are never on an offset relationship
        const k: UnifiedFieldSelection<PostSchema>[] = [{ comments: { fields: ["id"], page: { after: "x" } } }];
        export { sel, r, f, k };
        """
      )
    end

    test "tsc rejects a misspelled selection (non-vacuity)" do
      out =
        assert_rejected(
          [Inference.action_types(read_spec())],
          """
          const s: ListPostsFields = ["nonexistent"];
          export { s };
          """
        )

      assert out =~ "nonexistent"
    end
  end

  # Reference modules with no ash_surface analog: ash_surface's only TypeScript emitter is
  # the Inference declaration block (no Ash type aliases, no type discovery, no multi-file
  # import graph). Loud skips, never silent passes.
  for {mod, why} <- [
        {"codegen/type_discovery_test",
         "no TypeDiscovery module: ash_surface does not walk resources for Ash types"},
        {"codegen/type_aliases_test",
         "no TypeAliases module: Zod schemas are emitted instead of Ash type aliases"},
        {"codegen/nested_type_aliases_test",
         "no nested alias generation; nested relationship inference covered above"},
        {"codegen/import_resolver_test",
         "no ImportResolver: js.ex emits single-file artifacts, no cross-file imports"}
      ] do
    @tag skip: "[SKIP] #{mod}: #{why}"
    test "port #{mod}" do
      flunk("unreachable")
    end
  end
end
