defmodule AshSurface.ParityDeepen.TransportCodegenCourtsTest.Author do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:name, :string, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.ParityDeepen.TransportCodegenCourtsTest.Post do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:title, :string, public?: true)
  end

  relationships do
    belongs_to(:author, AshSurface.ParityDeepen.TransportCodegenCourtsTest.Author,
      public?: true,
      allow_nil?: true
    )
  end

  calculations do
    calculate(:shout, :string, expr(title <> "!"), public?: true)
  end

  actions do
    defaults([:read])
  end

  surface do
    projection(:read)

    typed_query :post_list, :read do
      description("Posts")
      result_type_name("PostListResult")
      fields_const_name("postListFields")
      fields([:id, :title, :shout, author: [:id, :name]])
    end
  end
end

defmodule AshSurface.ParityDeepen.TransportCodegenCourtsTest do
  @moduledoc """
  Wave-3 F1-deepen courts for the emitted transport wiring and codegen helper modules:
  HttpRenderer / ChannelRenderer / ConfigBuilder (hook ordering and option pass-through,
  executed under real node against the real `priv/static` transports and the manufactured
  Expo client), TypedQueries, PayloadBuilder, the `typed_channel` topic, and the config
  keys that have a renderer/runtime consumer (consumer-effect assertions).
  Hand-written real interface implementations (a recording `fetch`, a Phoenix-shaped
  channel) are used where node has no network peer; they are not mocks.
  """
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{Config, IR}
  alias AshSurface.Compiler.{ChannelDiscovery, IdentitySchema, QuerySchema}
  alias AshSurface.Compiler.Section.Channel
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo
  alias AshSurface.Projectors.JS
  alias AshSurface.Resource.Projections

  @root Path.expand("../../..", __DIR__)

  setup do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "ash_surface_f1d_#{System.unique_integer([:positive])}_#{:os.getpid()}"
      )

    File.rm_rf!(tmp)
    File.mkdir_p!(Path.join(tmp, "node_modules"))
    File.ln_s!(Path.join(@root, "node_modules/zod"), Path.join(tmp, "node_modules/zod"))
    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  defp copy_runtime!(tmp) do
    for f <-
          ~w(ash_surface_runtime.mjs ash_surface_http_transport.mjs ash_surface_channel_transport.mjs),
        do: File.cp!(Path.join(@root, "priv/static/#{f}"), Path.join(tmp, f))
  end

  # Runs an ES-module script in `tmp`; the last stdout line is a JSON receipt.
  defp run_node(tmp, script) do
    path = Path.join(tmp, "script_#{AshSurface.TestTmp.suffix()}.mjs")
    File.write!(path, script)
    {out, code} = System.cmd("node", [path], cd: tmp, stderr_to_stdout: true)
    assert code == 0, "node failed: #{out}"
    out |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()
  end

  describe "codegen.module.Rpc.Codegen.FunctionGenerators.HttpRenderer + Helpers.ConfigBuilder (runtime transport)" do
    test "beforeRequest runs after headers are built and before fetch; afterRequest runs after; options pass through",
         %{tmp: tmp} do
      copy_runtime!(tmp)

      r =
        run_node(tmp, """
        import { createHttpTransport } from "./ash_surface_http_transport.mjs";
        const order = [];
        let seen;
        const customFetch = async (url, init) => {
          order.push("fetch");
          seen = { url, method: init.method, headers: init.headers, body: init.body, cred: init.credentials };
          return new Response(JSON.stringify({ ok: 1 }), { status: 200, headers: { "content-type": "application/json" } });
        };
        const t = createHttpTransport({
          endpoint: "http://127.0.0.1:9/rpc/run",
          allowedOrigins: ["http://127.0.0.1:9"],
          csrf: false,
          headers: { "x-static": "s" },
          fetchOptions: { credentials: "include" },
          customFetch,
          beforeRequest: ({ url, init, context }) => {
            order.push("before");
            return { init: { ...init, headers: { ...init.headers, "x-hook": context.action.id } } };
          },
          afterRequest: ({ body }) => { order.push("after"); return { wrapped: body }; },
        });
        const out = await t.invoke({ action: { id: "T#read" }, input: { a: 1 }, commandId: "c1" });
        console.log(JSON.stringify({ order, out, seen }));
        """)

      assert r["order"] == ["before", "fetch", "after"]
      assert r["out"] == %{"wrapped" => %{"ok" => 1}}
      assert r["seen"]["url"] == "http://127.0.0.1:9/rpc/run"
      assert r["seen"]["method"] == "POST"
      assert r["seen"]["cred"] == "include"
      assert r["seen"]["headers"]["x-static"] == "s"
      assert r["seen"]["headers"]["x-hook"] == "T#read"

      assert Jason.decode!(r["seen"]["body"]) == %{
               "action" => "T#read",
               "input" => %{"a" => 1},
               "commandId" => "c1"
             }
    end

    test "a throwing beforeRequest never reaches fetch; a swapped url is origin re-checked", %{
      tmp: tmp
    } do
      copy_runtime!(tmp)

      r =
        run_node(tmp, """
        import { createHttpTransport } from "./ash_surface_http_transport.mjs";
        let fetched = 0;
        const customFetch = async () => { fetched += 1; return new Response("{}", { status: 200 }); };
        const base = { endpoint: "http://127.0.0.1:9/rpc/run", allowedOrigins: ["http://127.0.0.1:9"], csrf: false, customFetch };
        const ctx = { action: { id: "T#read" }, input: {}, commandId: "c" };
        const codes = {};
        try {
          await createHttpTransport({ ...base, beforeRequest: () => { throw new Error("boom"); } }).invoke(ctx);
        } catch (e) { codes.thrown = e.code; }
        try {
          await createHttpTransport({ ...base, beforeRequest: () => ({ url: "http://evil.example/x" }) }).invoke(ctx);
        } catch (e) { codes.swapped = e.code; }
        console.log(JSON.stringify({ codes, fetched }));
        """)

      assert r["codes"]["thrown"] == "HTTP_BEFORE_REQUEST_FAILED"
      assert is_binary(r["codes"]["swapped"])
      assert r["fetched"] == 0
    end
  end

  describe "emitted client wiring (Expo projector -> createHttpTransport options)" do
    test "createZoelaClient wires reconcileEndpoint/BaseUrl/AllowedOrigins/TimeoutMs into the http transport",
         %{tmp: tmp} do
      assert {:ok, manifest} =
               Manifest.generate(
                 otp_app: :ash_surface,
                 action_entrypoints: [{VolunteerMilestone, :record}, {VolunteerMilestone, :read}]
               )

      assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{})

      assert {:ok, artifacts, _} =
               AshSurface.project(surface, Expo, prefix: "zs", target_dir: tmp)

      client = artifacts["zs.mjs"]

      # emission: the generated source calls createHttpTransport with the pass-through options
      assert client =~ ~s(import { createHttpTransport } from "./ash_surface_http_transport.mjs";)
      assert client =~ "createHttpTransport({"

      for opt <- ~w(endpoint: customFetch: csrf: baseUrl: allowedOrigins:),
          do: assert(client =~ opt, "emitted wiring lacks #{opt}")

      # behavior: executed under node with a recording fetch (a real interface implementation)
      copy_runtime!(tmp)
      File.write!(Path.join(tmp, "contract.json"), Jason.encode!(surface.contract))

      r =
        run_node(tmp, """
        import { readFileSync } from "node:fs";
        const calls = [];
        globalThis.fetch = async (url, init) => {
          calls.push({ url: String(url), method: init?.method ?? "GET", hasSignal: !!init?.signal, headers: init?.headers ?? {} });
          return new Response(JSON.stringify({ status: "COMPLETED", commandId: "c 1" }), { status: 200, headers: { "content-type": "application/json" } });
        };
        const { createZoelaClient } = await import("./zs.mjs");
        const contract = JSON.parse(readFileSync("./contract.json", "utf8"));
        const abs = createZoelaClient({ contract, reconcileEndpoint: "http://127.0.0.1:9/rec" });
        const a = await abs.reconcile("c 1");
        const rel = createZoelaClient({ contract, reconcileEndpoint: "/rec", reconcileBaseUrl: "http://127.0.0.1:9" });
        const b = await rel.reconcile("c 1");
        let refused = null;
        try {
          await createZoelaClient({ contract, reconcileEndpoint: "/rec" }).reconcile("c 1");
        } catch (e) { refused = e.code ?? e.name; }
        console.log(JSON.stringify({ calls, a: a.status, b: b.status, refused }));
        """)

      assert r["a"] == "COMPLETED" and r["b"] == "COMPLETED"
      [c1, c2] = Enum.take(r["calls"], 2)
      assert c1["url"] == "http://127.0.0.1:9/rec?commandId=c%201"
      assert c2["url"] == "http://127.0.0.1:9/rec?commandId=c%201"
      assert c1["method"] == "GET" and c1["hasSignal"] == true
      refute Map.has_key?(c1["headers"], "x-csrf-token")
      assert is_binary(r["refused"])
    end
  end

  describe "codegen.module.Rpc.Codegen.FunctionGenerators.ChannelRenderer (runtime transport option pass-through)" do
    test "event, timeout, beforePush and afterResponse reach a Phoenix-shaped channel", %{
      tmp: tmp
    } do
      copy_runtime!(tmp)

      r =
        run_node(tmp, """
        import { createChannelTransport, ChannelTransportError } from "./ash_surface_channel_transport.mjs";
        const pushes = [];
        const reply = (kind, body) => ({
          receive(k, cb) { if (k === kind) queueMicrotask(() => cb(body)); return this; },
        });
        const channel = {
          push(event, payload, timeout) {
            pushes.push({ event, payload, timeout });
            return payload.input?.fail ? reply("error", { reason: "no" }) : reply("ok", { echoed: payload.input });
          },
        };
        const order = [];
        const t = createChannelTransport({
          channel, event: "surface_run", timeout: 1234,
          beforePush: (p) => { order.push("before"); return { ...p, input: { ...p.input, hooked: true } }; },
          afterResponse: (resp) => { order.push("after"); return { wrapped: resp }; },
        });
        const ok = await t.invoke({ action: { id: "T#read" }, input: { x: 1 }, commandId: "c1", idempotency: { key: "k" } });
        let code = null;
        try { await t.invoke({ action: { id: "T#read" }, input: { fail: true }, commandId: "c2" }); } catch (e) { code = e.code; }
        const rec = await t.reconcile("c9").catch(() => "x");
        let invalid = null;
        try { createChannelTransport({}); } catch (e) { invalid = e instanceof ChannelTransportError && e.code; }
        console.log(JSON.stringify({ pushes, ok, code, order, invalid }));
        """)

      [p1, p2 | _] = r["pushes"]
      assert p1["event"] == "surface_run" and p1["timeout"] == 1234
      assert p1["payload"]["action"] == "T#read"
      assert p1["payload"]["commandId"] == "c1"
      assert p1["payload"]["idempotency"] == %{"key" => "k"}
      assert p1["payload"]["input"] == %{"x" => 1, "hooked" => true}
      assert r["ok"] == %{"wrapped" => %{"echoed" => %{"x" => 1, "hooked" => true}}}
      assert r["code"] == "CHANNEL_ERROR_REPLY"
      assert r["order"] |> Enum.take(2) == ["before", "after"]
      assert p2["event"] == "surface_run"
      assert r["invalid"] == "INVALID_CHANNEL"
      assert Enum.any?(r["pushes"], &(&1["event"] == "reconcile"))
    end
  end

  describe "codegen.module.Rpc.Codegen.FunctionGenerators.TypedQueries (emitted output)" do
    alias AshSurface.ParityDeepen.TransportCodegenCourtsTest.Post

    test "the typed query is serialized into the manifest DSL as JSON data" do
      assert [q] = AshSurface.Manifest.Dsl.serialize(Post)["typed_queries"]
      assert q["name"] == "post_list" and q["action"] == "read"
      assert q["description"] == "Posts"
      assert q["result_type_name"] == "PostListResult"
      assert q["fields_const_name"] == "postListFields"

      assert q["fields"] == [
               "id",
               "title",
               "shout",
               %{"author" => ["id", "name"]}
             ]

      assert Jason.decode!(Jason.encode!(q)) == q
      assert Projections.typed_query(Post, :post_list).name == :post_list
    end

    test "the typed-query input envelope renders strict, optional parts, admitted by ZodGuard" do
      {:ok, sort} = QuerySchema.render_sort_schema(["title"])
      {:ok, page} = QuerySchema.render_pagination_schema()
      parts = %{input: "z.object({q: z.string()}).strict()", page: page, sort: sort, filter: nil}

      assert {:ok, zod} = QuerySchema.render_typed_query_input_schema(parts, required: [:input])
      assert {:ok, _, _} = AshSurface.Projectors.JS.ZodGuard.admit(zod)
      assert zod =~ "input: z.object({q: z.string()}).strict()"
      refute zod =~ "input: z.object({q: z.string()}).strict().optional()"
      assert zod =~ "page:" and zod =~ "sort:"
      refute zod =~ "filter:"
      assert zod =~ ".optional()"
    end
  end

  describe "codegen.module.Rpc.Codegen.Helpers.PayloadBuilder (emitted query slots)" do
    defp schema_ir(schema) do
      IR.new(
        ash: %IR.Ash{resource: "Todo", action: :list, action_type: :read, policies: []},
        schema: struct!(IR.Schema, schema)
      )
    end

    test "filter/sort/page/response slots are emitted by name; absent slots are null", %{tmp: tmp} do
      {:ok, sort} = QuerySchema.render_sort_schema(["title"])
      {:ok, page} = QuerySchema.render_pagination_schema()

      full =
        schema_ir(
          zod: "z.object({a: z.string()})",
          filter: "z.object({title: z.string().optional()}).strict()",
          sort: sort,
          page: page,
          response_zod: "z.object({id: z.string()})"
        )

      assert {:ok, %{"ash_surface_client.mjs" => code}, _} = JS.project_ir(full)

      assert code =~
               "Object.freeze({filter: Todo_list_filter_schema, sort: Todo_list_sort_schema, page: Todo_list_page_schema, response: Todo_list_response_schema})"

      partial =
        schema_ir(zod: "z.object({a: z.string()})", filter: "z.object({t: z.string()}).strict()")

      assert {:ok, %{"ash_surface_client.mjs" => pcode}, _} = JS.project_ir(partial)
      assert pcode =~ "filter: Todo_list_filter_schema"
      assert pcode =~ ~r/sort: null/
      assert pcode =~ ~r/page: null/
      assert pcode =~ ~r/response: null/

      # executes: the frozen record's slots validate under real zod
      assert {:ok, _, _} = JS.project_ir(full, target_dir: tmp)

      r =
        run_node(tmp, """
        const m = await import("./ash_surface_client.mjs");
        const q = m.QUERY_SCHEMAS["Todo.list"];
        console.log(JSON.stringify({
          frozen: Object.isFrozen(q),
          keys: Object.keys(q).sort(),
          filterOk: q.filter.safeParse({ title: "x" }).success,
          filterBad: q.filter.safeParse({ nope: 1 }).success,
          responseOk: q.response.safeParse({ id: "1" }).success,
          responseBad: q.response.safeParse({ id: 1 }).success,
        }));
        """)

      assert r["frozen"] == true
      assert r["keys"] == ["filter", "page", "response", "sort"]
      assert r["filterOk"] == true and r["filterBad"] == false
      assert r["responseOk"] == true and r["responseBad"] == false
    end
  end

  describe "dsl.typed_channel.dsl.section.typed_channel.option.topic" do
    alias AshSurface.ChannelFixtures.Item

    test "topic is carried from the channel spec through discovery into the built channel" do
      assert {:ok, %{"channels" => [c]} = d} =
               ChannelDiscovery.discover([%{name: "Org", topic: "org:*", resources: [Item]}])

      assert c["topic"] == "org:*"
      assert {:ok, [ch]} = Channel.build(d)
      assert ch.topic == "org:*"
    end

    test "an absent topic stays nil end to end, and different topics stay distinct" do
      assert {:ok, %{"channels" => [c]} = d} =
               ChannelDiscovery.discover([%{name: "Org", resources: [Item]}])

      assert c["topic"] == nil
      assert {:ok, [%{topic: nil}]} = Channel.build(d)

      two = [
        %{name: "A", topic: "a:*", resources: [Item]},
        %{name: "B", topic: "b:*", resources: [AshSurface.ChannelFixtures.Dup]}
      ]

      assert {:ok, d2} = ChannelDiscovery.discover(two)
      assert {:ok, chans} = Channel.build(d2)
      assert Enum.map(chans, &{&1.name, &1.topic}) == [{"A", "a:*"}, {"B", "b:*"}]
    end
  end

  describe "config keys with a consumer (consumer-effect assertions)" do
    setup do
      keys = [:require_tenant_parameters, :zod_import_path, :warn_on_missing_rpc_config]
      saved = for k <- keys, do: {k, Application.fetch_env(:ash_surface, k)}

      on_exit(fn ->
        for {k, v} <- saved do
          case v do
            {:ok, val} -> Application.put_env(:ash_surface, k, val)
            :error -> Application.delete_env(:ash_surface, k)
          end
        end
      end)
    end

    test "config.key.require_tenant_parameters decides whether the tenant parameter is required" do
      mt = %{"strategy" => "attribute", "global?" => false}
      Application.put_env(:ash_surface, :require_tenant_parameters, false)
      assert {:ok, "z.string().min(1).optional()"} = IdentitySchema.render_tenant_schema(mt)
      Application.put_env(:ash_surface, :require_tenant_parameters, true)
      assert {:ok, "z.string().min(1)"} = IdentitySchema.render_tenant_schema(mt)
      # a fact in the multitenancy map wins over config
      assert {:ok, "z.string().min(1).optional()"} =
               IdentitySchema.render_tenant_schema(
                 Map.put(mt, "require_tenant_parameters", false)
               )

      assert {:ok, nil} = IdentitySchema.render_tenant_schema(%{"strategy" => "none"})
    end

    test "config.key.zod_import_path is the single zod import in the emitted artifact" do
      ir = schema_ir(zod: "z.object({a: z.string()})")
      Application.put_env(:ash_surface, :zod_import_path, "zod/mini-custom")
      assert Config.zod_import_path() == "zod/mini-custom"
      assert {:ok, %{"ash_surface_client.mjs" => code}, _} = JS.project_ir(ir)
      assert code =~ ~s(import { z } from "zod/mini-custom";)
      refute code =~ ~s(from "zod";)
      Application.delete_env(:ash_surface, :zod_import_path)
      assert {:ok, %{"ash_surface_client.mjs" => code}, _} = JS.project_ir(ir)
      assert code =~ ~s(import { z } from "zod";)
    end

    test "config.key.warn_on_missing_rpc_config gates the domain warning for surface resources without projections" do
      src = fn n ->
        """
        defmodule AshSurface.ParityDeepen.TcWarn#{n}.Res do
          use Ash.Resource, domain: AshSurface.ParityDeepen.TcWarn#{n}.Dom, data_layer: Ash.DataLayer.Simple,
            extensions: [AshSurface.Resource]
          attributes do
            uuid_primary_key :id, public?: true
          end
          actions do
            defaults [:read]
          end
        end
        defmodule AshSurface.ParityDeepen.TcWarn#{n}.Dom do
          use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]
          resources do
            resource AshSurface.ParityDeepen.TcWarn#{n}.Res
          end
        end
        """
      end

      Application.put_env(:ash_surface, :warn_on_missing_rpc_config, true)

      on =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(src.(System.unique_integer([:positive])))
        end)

      assert on =~ "declares no surface projection"

      Application.put_env(:ash_surface, :warn_on_missing_rpc_config, false)

      off =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string(src.(System.unique_integer([:positive])))
        end)

      refute off =~ "declares no surface projection"
    end
  end
end
