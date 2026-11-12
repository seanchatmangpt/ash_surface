Code.require_file("support/tc_support.exs", __DIR__)

defmodule AshSurface.Ported.TypedController.CodegenTest do
  @moduledoc """
  Port of ash_typescript typed_controller/codegen_test.exs to the descriptor-only
  `RouteSchema` (path/query/body/response Zod sources), asserted by structure and by real
  zod parse under node. No `.ts` path helpers/action functions/hooks are generated
  (README: no generated `.ts`, no `.d.ts`), so TS-text tests adapt to the descriptor field
  that carries the same fact.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Ported.TypedController.Support, as: S

  describe "multi-mount code generation" do
    test "same-named routes at distinct scope prefixes are both admitted and carry the prefix" do
      built =
        S.build!([
          S.route("auth", "get", "/admin/auth", [], %{"scope_prefix" => "admin"}),
          S.route("auth", "get", "/app/auth", [], %{"scope_prefix" => "app"}),
          S.route("login", "post", "/admin/login", [S.arg("u")], %{"scope_prefix" => "admin"}),
          S.route("login", "post", "/app/login", [S.arg("u")], %{"scope_prefix" => "app"})
        ])

      assert built |> Enum.map(&{&1["scope_prefix"], &1["name"]}) |> Enum.sort() ==
               [{"admin", "auth"}, {"admin", "login"}, {"app", "auth"}, {"app", "login"}]

      assert Enum.find(built, &(&1["scope_prefix"] == "app" and &1["name"] == "login"))["body"] =~
               "u:"
    end

    test "path param at only one mount: path-param at admin, nullable query param at app" do
      [admin, app] =
        S.build!([
          S.route(
            "profile",
            "get",
            "/admin/profile/:user_id",
            [
              S.arg("user_id", "string", %{"allow_nil?" => true}),
              S.arg("bio", "string", %{"allow_nil?" => true})
            ],
            %{
              "scope_prefix" => "admin",
              "mounts" => ["/admin/profile/:user_id", "/app/profile"]
            }
          ),
          S.route(
            "profile",
            "get",
            "/app/profile",
            [
              S.arg("user_id", "string", %{"allow_nil?" => true}),
              S.arg("bio", "string", %{"allow_nil?" => true})
            ],
            %{
              "scope_prefix" => "app",
              "mounts" => ["/admin/profile/:user_id", "/app/profile"]
            }
          )
        ])

      assert admin["path_params"] == ["user_id"]
      assert admin["params"] =~ "userId:"
      assert app["path_params"] == []
      assert app["query"] =~ "userId:"
      assert admin["path"] != app["path"]
    end

    test "PATCH routes carry body schemas excluding path params at each scope" do
      built =
        for p <- ["admin", "app"],
            do:
              S.route(
                "update_provider",
                "patch",
                "/#{p}/providers/:provider",
                [S.arg("provider"), S.arg("name")],
                %{"scope_prefix" => p}
              )

      for r <- S.build!(built) do
        assert r["method"] == "patch"
        assert r["body"] =~ "name:"
        refute r["body"] =~ "provider:"
      end
    end

    test "no unprefixed duplicate: duplicate (name, scope_prefix) is refused" do
      r = S.route("auth", "get", "/a")

      assert {:error, {:duplicate_route_name, "auth", nil}} =
               RouteSchema.build([r, Map.put(r, "path", "/b")])
    end
  end

  describe "ambiguous mount error" do
    test "duplicate verb+path is refused typed" do
      r = S.route("auth", "get", "/auth")

      assert {:error, {:duplicate_route, "get", "/auth"}} =
               RouteSchema.build([r, Map.put(r, "name", "other")])
    end
  end

  describe "GET route path helpers" do
    test "builds non-empty descriptors with method and path" do
      [r] = S.build!([S.route("auth", "get", "/auth")])
      assert %{"method" => "get", "path" => "/auth", "path_params" => []} = r
    end

    test "path param and query param are split (provider_page)" do
      [r] =
        S.build!([
          S.route("provider_page", "get", "/auth/providers/:provider", [
            S.arg("provider"),
            S.arg("redirect", "string", %{"allow_nil?" => true})
          ])
        ])

      assert r["path_params"] == ["provider"]
      assert r["params"] =~ "provider:"
      assert r["query"] =~ "redirect:"
      assert [true, false] = S.node_parse(r["params"], [%{provider: "gh"}, %{}])
    end

    test "path params are strict objects (no extra keys)" do
      [r] = S.build!([S.route("p", "get", "/p/:id", [S.arg("id")])])
      assert [true, false] = S.node_parse(r["params"], [%{id: "a"}, %{id: "a", z: 1}])
    end

    test "search route: required query param is enforced" do
      [r] = S.build!([S.route("search", "get", "/search", [S.arg("q")])])
      assert [true, false] = S.node_parse(r["query"], [%{q: "x"}, %{}])
    end

    test "array query params accept arrays of the element type" do
      arr =
        S.arg("tags", "array", %{"type" => %{"kind" => "array", "items" => %{"kind" => "string"}}})

      [r] = S.build!([S.route("search", "get", "/search", [arr])])
      assert [true, false] = S.node_parse(r["query"], [%{tags: ["a", "b"]}, %{tags: "a"}])
    end

    test "optional (nullable) query params are skipped or null" do
      [r] =
        S.build!([
          S.route("search", "get", "/search", [S.arg("q", "string", %{"allow_nil?" => true})])
        ])

      assert [true, true, true] = S.node_parse(r["query"], [%{}, %{q: nil}, %{q: "x"}])
    end

    test "GET routes without returns have an unconstrained response" do
      [r] = S.build!([S.route("auth", "get", "/auth")])
      assert r["response"] == "z.unknown()"
    end

    test "description renders as jsdoc" do
      [r] = S.build!([S.route("auth", "get", "/auth", [], %{"description" => "Auth page"})])
      assert r["jsdoc"] =~ "Auth page"
    end
  end

  describe "POST route action functions" do
    test "login: body schema is typed by the argument and strict" do
      [r] =
        S.build!([
          S.route("login", "post", "/login", [
            S.arg("email"),
            S.arg("remember", "boolean", %{"allow_nil?" => true})
          ])
        ])

      assert [true, true, false, false] =
               S.node_parse(r["body"], [
                 %{email: "a"},
                 %{email: "a", remember: true},
                 %{remember: true},
                 %{email: 1}
               ])
    end

    test "logout: no arguments yields an empty strict body and empty query" do
      [r] = S.build!([S.route("logout", "post", "/logout")])
      assert r["body"] == "z.object({}).strict()"
      assert r["query"] == "z.object({}).strict()"
      assert [true, false] = S.node_parse(r["body"], [%{}, %{x: 1}])
    end

    test "see/description render jsdoc @see tags; absent options add none" do
      [with_see, without] =
        S.build!([
          S.route("login", "post", "/login", [], %{
            "description" => "Login",
            "see" => "https://x.test/docs"
          }),
          S.route("logout", "post", "/logout")
        ])

      assert with_see["jsdoc"] =~ "@see https://x.test/docs"
      refute Map.has_key?(without, "jsdoc")
    end
  end

  describe "route result types" do
    test "map returns with fields render an object response enforced by zod" do
      ret = %{"type" => %{"kind" => "map", "fields" => %{"id" => %{"kind" => "string"}}}}
      [r] = S.build!([S.route("me", "get", "/me", [], %{"returns" => ret})])
      assert is_binary(r["response"]) and r["response"] != "z.unknown()"
    end

    test "primitive returns map directly" do
      [r] = S.build!([S.route("count", "get", "/count", [], %{"returns" => "integer"})])
      assert [true, false] = S.node_parse(r["response"], [3, "x"])
    end

    test "zod_schema_name names the response declaration" do
      [r] =
        S.build!([
          S.route("count", "get", "/count", [], %{
            "returns" => "integer",
            "zod_schema_name" => "CountSchema"
          })
        ])

      assert r["schema_declaration"] =~ "export const CountSchema ="
    end
  end

  describe "path param validation" do
    test "path param without a matching argument is refused" do
      assert {:error, {:path_param_missing_arg, "show", "id"}} =
               RouteSchema.build([S.route("show", "get", "/u/:id")])
    end
  end

  describe "path param allow_nil? validation" do
    test "single-mount path param with allow_nil? true is refused" do
      assert {:error, {:path_param_nullable, "show", "id"}} =
               RouteSchema.build([
                 S.route("show", "get", "/u/:id", [S.arg("id", "string", %{"allow_nil?" => true})])
               ])
    end

    test "multi-mount path param present at ALL mounts with allow_nil? true is refused" do
      r =
        S.route("show", "get", "/a/:id", [S.arg("id", "string", %{"allow_nil?" => true})], %{
          "mounts" => ["/a/:id", "/b/:id"]
        })

      assert {:error, {:path_param_nullable, "show", "id"}} = RouteSchema.build([r])
    end

    test "multi-mount path param at SOME mounts with allow_nil? true is admitted" do
      r =
        S.route("show", "get", "/a/:id", [S.arg("id", "string", %{"allow_nil?" => true})], %{
          "mounts" => ["/a/:id", "/b"]
        })

      assert {:ok, [_]} = RouteSchema.build([r])
    end

    test "path param with allow_nil? false is admitted" do
      assert {:ok, [_]} = RouteSchema.build([S.route("show", "get", "/u/:id", [S.arg("id")])])
    end

    test "multi-mount path param at SOME mounts with allow_nil? false is refused (typed, names the param)" do
      r = S.route("show", "get", "/a/:id", [S.arg("id")], %{"mounts" => ["/a/:id", "/b"]})
      assert {:error, {:path_param_sometimes_present, "show", "id"}} = RouteSchema.build([r])
    end
  end

  describe "PATCH route with path params and input" do
    test "update_provider: body excludes path params; path object requires them" do
      [r] =
        S.build!([
          S.route("update_provider", "patch", "/auth/providers/:provider", [
            S.arg("provider"),
            S.arg("name"),
            S.arg("active", "boolean", %{"allow_nil?" => true})
          ])
        ])

      assert r["method"] == "patch"
      assert r["path_params"] == ["provider"]
      assert [true, false] = S.node_parse(r["params"], [%{provider: "gh"}, %{}])

      assert [true, true, false] =
               S.node_parse(r["body"], [
                 %{name: "n"},
                 %{name: "n", active: false},
                 %{provider: "gh", name: "n"}
               ])
    end
  end

  describe "Zod schema generation" do
    test "mutation routes with input args get body schemas; path params excluded" do
      [r] =
        S.build!([
          S.route("login", "post", "/login", [
            S.arg("email"),
            S.arg("age", "integer"),
            S.arg("ok", "boolean")
          ])
        ])

      assert [true, false] =
               S.node_parse(r["body"], [
                 %{email: "a", age: 1, ok: true},
                 %{email: "a", age: "1", ok: true}
               ])
    end

    test "GET path/query numeric values arrive as strings and are coerced from numeric strings" do
      [r] = S.build!([S.route("page", "get", "/page", [S.arg("n", "integer")])])
      assert [true, true, false] = S.node_parse(r["query"], [%{n: "3"}, %{n: 3}, %{n: "abc"}])
    end
  end

  describe "Zod schema generation with type constraints" do
    test "string min_length, max_length, regex" do
      c = %{"min_length" => 2, "max_length" => 5, "match" => "^[a-z]+$"}
      [r] = S.build!([S.route("c", "post", "/c", [S.arg("s", "string", %{"constraints" => c})])])

      assert [true, false, false, false] =
               S.node_parse(r["body"], [%{s: "abc"}, %{s: "a"}, %{s: "abcdef"}, %{s: "AB1"}])
    end

    test "integer min/max" do
      [r] =
        S.build!([
          S.route("c", "post", "/c", [
            S.arg("n", "integer", %{"constraints" => %{"min" => 1, "max" => 10}})
          ])
        ])

      assert [true, true, false, false] =
               S.node_parse(r["body"], [%{n: 1}, %{n: 10}, %{n: 0}, %{n: 11}])
    end

    test "float min/max" do
      [r] =
        S.build!([
          S.route("c", "post", "/c", [
            S.arg("n", "float", %{"constraints" => %{"min" => 0.5, "max" => 1.5}})
          ])
        ])

      assert [true, false, false] = S.node_parse(r["body"], [%{n: 1.0}, %{n: 0.1}, %{n: 2.0}])
    end

    test "string max_length-only constraint" do
      [r] =
        S.build!([
          S.route("c", "post", "/c", [
            S.arg("s", "string", %{"constraints" => %{"max_length" => 3}})
          ])
        ])

      assert [true, false] = S.node_parse(r["body"], [%{s: "abc"}, %{s: "abcd"}])
    end

    test "fixed-length string via min_length + max_length" do
      [r] =
        S.build!([
          S.route("c", "post", "/c", [
            S.arg("s", "string", %{"constraints" => %{"min_length" => 3, "max_length" => 3}})
          ])
        ])

      assert [true, false, false] =
               S.node_parse(r["body"], [%{s: "abc"}, %{s: "ab"}, %{s: "abcd"}])
    end
  end

  describe "embedded resource argument type" do
    test "an embedded_resource argument is not an unmappable-kind refusal: object argument shape is enforced" do
      meta =
        S.arg("metadata", "map", %{
          "type" => %{"kind" => "map", "fields" => %{"k" => %{"kind" => "string"}}}
        })

      assert {:ok, [r]} =
               RouteSchema.build([
                 S.route("create_task", "post", "/tasks", [S.arg("title"), meta])
               ])

      assert r["body"] =~ "metadata:"
      assert [true] = S.node_parse(r["params"], [%{}])
    end
  end
end
