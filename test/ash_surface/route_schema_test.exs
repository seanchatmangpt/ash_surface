defmodule AshSurface.Compiler.RouteSchemaTest do
  use ExUnit.Case, async: true
  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Projectors.JS.ZodGuard

  defp arg(n, extra \\ %{}),
    do: Map.merge(%{"name" => n, "type" => %{"kind" => "string"}, "allow_nil?" => false}, extra)

  defp route(m, path, args, extra \\ %{}),
    do: Map.merge(%{"name" => "r", "method" => m, "path" => path, "arguments" => args}, extra)

  defp zods(r), do: for(k <- ~w(params query body response), do: r[k])

  test "path params split out; GET args go to query" do
    {:ok, [r]} = RouteSchema.build([route("get", "/u/:id", [arg("id"), arg("q")])])
    assert r["path_params"] == ["id"]
    assert r["params"] =~ "id:"
    refute r["params"] =~ "q:"
    assert r["query"] =~ "q:"
    assert r["body"] == "z.object({}).strict()"
    for z <- zods(r), do: assert({:ok, _, _} = ZodGuard.admit(z))
  end

  test "POST args go to body" do
    {:ok, [r]} = RouteSchema.build([route("post", "/u/:id", [arg("id"), arg("n")])])
    assert r["body"] =~ "n:"
    refute r["body"] =~ "id:"
    assert r["query"] == "z.object({}).strict()"
  end

  test "missing allow_nil? is nullable: refused on a path param, nullable+optional on input" do
    bare = %{"name" => "id", "type" => %{"kind" => "string"}}

    assert {:error, {:path_param_nullable, "r", "id"}} =
             RouteSchema.build([route("get", "/a/:id", [bare])])

    {:ok, [r]} =
      RouteSchema.build([route("get", "/a/:id", [arg("id"), Map.delete(arg("q"), "allow_nil?")])])

    assert r["query"] =~ ".nullable().optional()"
    refute r["params"] =~ "nullable"
  end

  test "admission errors" do
    assert {:error, {:duplicate_route, "get", "/a"}} =
             RouteSchema.build([route("get", "/a", []), route("GET", "/a", [])])

    assert {:error, {:duplicate_route_name, "r", nil}} =
             RouteSchema.build([route("get", "/a", []), route("post", "/b", [])])

    assert {:error, {:path_param_missing_arg, "r", "id"}} =
             RouteSchema.build([route("get", "/a/:id", [])])

    assert {:error, {:path_param_nullable, "r", "id"}} =
             RouteSchema.build([route("get", "/a/:id", [arg("id", %{"allow_nil?" => true})])])
  end

  test "same name at distinct scope prefixes is admitted and carried in the descriptor" do
    rs = [
      route("get", "/v1/a", [], %{"scope_prefix" => "v1"}),
      route("get", "/v2/a", [], %{"scope_prefix" => "v2"})
    ]

    assert {:ok, [a, b]} = RouteSchema.build(rs)
    assert [a["scope_prefix"], b["scope_prefix"]] == ["v1", "v2"]
    assert a["name"] == "r"
  end

  test "params present at only some mounts must be nullable" do
    mounts = ["/a/:id", "/b"]

    assert {:error, {:path_param_sometimes_present, "r", "id"}} =
             RouteSchema.build([route("get", "/a/:id", [arg("id")], %{"mounts" => mounts})])

    assert {:ok, [r]} =
             RouteSchema.build([
               route("get", "/a/:id", [arg("id", %{"allow_nil?" => true})], %{"mounts" => mounts})
             ])

    assert r["params"] =~ ".nullable()"

    assert {:error, {:path_param_nullable, "r", "id"}} =
             RouteSchema.build([
               route("get", "/a/:id", [arg("id", %{"allow_nil?" => true})], %{
                 "mounts" => ["/a/:id", "/b/:id"]
               })
             ])
  end

  test "returns: definition, bare kind with constraints, absent" do
    {:ok, [a]} =
      RouteSchema.build([
        route("get", "/a", [], %{"returns" => %{"type" => %{"kind" => "integer"}}})
      ])

    assert a["response"] =~ "z.number().int()"

    {:ok, [b]} =
      RouteSchema.build([
        route("get", "/b", [], %{"returns" => "string", "constraints" => %{"min_length" => 2}})
      ])

    assert b["response"] =~ "z.string()" and b["response"] =~ "min(2)"
    {:ok, [c]} = RouteSchema.build([route("get", "/c", [])])
    assert c["response"] == "z.unknown()"
    for r <- [a, b, c], z <- zods(r), do: assert({:ok, _, _} = ZodGuard.admit(z))
  end

  test "introspector without router is typed error" do
    assert {:error, :phoenix_unavailable} = RouteSchema.introspect_router(NoSuchRouter)
  end

  describe "__proto__ path parameter (F1-refwire)" do
    test "a route whose path param is __proto__ is refused typed, never emitted" do
      for path <- ["/a/:__proto__", "/a/*__proto__"] do
        assert {:error, {:denied_path_param_name, "r", "__proto__"}} =
                 RouteSchema.build([
                   %{"name" => "r", "method" => "get", "path" => path, "arguments" => []}
                 ])
      end
    end
  end

  describe "node-executed parse" do
    alias AshSurface.ZodFixtures.Harness

    defp node_parse(schema, cases) do
      dir = Path.join(System.tmp_dir!(), "rc_route_#{AshSurface.TestTmp.suffix()}")
      File.mkdir_p!(dir)
      File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
      Harness.zod!()

      File.write!(Path.join(dir, "run.mjs"), """
      import { z } from "zod";
      const s = #{schema};
      const cases = #{Jason.encode!(cases)};
      process.stdout.write(JSON.stringify(cases.map((c) => s.safeParse(c).success)));
      """)

      {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
      File.rm_rf!(dir)
      Jason.decode!(out)
    end

    test "params / query / body schemas accept valid and reject invalid payloads" do
      {:ok, [r]} =
        RouteSchema.build([
          route("post", "/u/:id", [
            arg("id", %{"type" => %{"kind" => "uuid"}}),
            arg("n", %{"type" => %{"kind" => "integer"}}),
            arg("note", %{"allow_nil?" => true})
          ])
        ])

      uuid = "123e4567-e89b-42d3-a456-426614174000"

      assert [true, false, false] =
               node_parse(r["params"], [%{id: uuid}, %{id: "x"}, %{id: uuid, extra: 1}])

      assert [true, true, true, false, false] =
               node_parse(r["body"], [
                 %{n: 1},
                 %{n: 1, note: nil},
                 %{n: 1, note: "hi"},
                 %{n: "1"},
                 %{}
               ])

      {:ok, [g]} =
        RouteSchema.build([route("get", "/g", [arg("q", %{"type" => %{"kind" => "integer"}})])])

      assert [true, false] = node_parse(g["query"], [%{q: 3}, %{q: "a"}])
    end
  end
end
