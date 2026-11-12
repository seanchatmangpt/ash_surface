defmodule AshSurface.Ported.TS.ShouldPass.ZodRouteCasesTest do
  @moduledoc """
  Zod-behavior adaptations of ash_typescript `test/ts/shouldPass` files whose subject is the
  shape of values crossing the boundary rather than TS inference:

    * `typedControllerResults.ts` - route params/query/body/response schemas
      (`RouteSchema`, real zod under node; no `.ts` route functions exist, README);
    * `structArguments.ts` / `untypedMaps.ts` - struct and untyped-map arguments accept
      arbitrary nested JSON objects and refuse non-objects.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.ZodFixtures.HarnessExt

  defp arg(name, kind, nil?, extra \\ %{}),
    do: Map.merge(%{"name" => name, "type" => %{"kind" => kind}, "allow_nil?" => nil?}, extra)

  defp parse(expr, cases) do
    cases =
      Enum.with_index(cases, fn {expect, payload}, i ->
        %{label: "c#{i}", expect: expect, payload: payload}
      end)

    for r <- HarnessExt.run_fragment!(expr, cases) do
      assert r["success"] == r["expect"], "#{r["label"]} #{expr}: issues=#{inspect(r["issues"])}"
    end
  end

  defp routes do
    {:ok, built} =
      AshSurface.Ported.AshNames.with_verbatim(fn ->
        RouteSchema.build([
          %{
            "name" => "login",
            "method" => "post",
            "path" => "/login",
            "arguments" => [arg("code", "string", false), arg("remember_me", "boolean", true)],
            "returns" => %{"type" => %{"kind" => "map"}}
          },
          %{
            "name" => "update_provider",
            "method" => "patch",
            "path" => "/providers/:provider",
            "arguments" => [arg("provider", "string", false), arg("enabled", "boolean", false)],
            "returns" => %{"type" => %{"kind" => "map"}}
          },
          %{
            "name" => "search",
            "method" => "get",
            "path" => "/search",
            "arguments" => [
              arg("q", "string", false),
              %{
                "name" => "tags",
                "type" => %{"kind" => "array", "items" => %{"kind" => "string"}},
                "allow_nil?" => true
              }
            ],
            "returns" => %{"type" => %{"kind" => "array", "items" => %{"kind" => "map"}}}
          },
          %{
            "name" => "profile",
            "method" => "get",
            "path" => "/profile",
            "arguments" => [],
            "returns" => %{"type" => %{"kind" => "map"}}
          }
        ])
      end)

    Map.new(built, &{&1["name"], &1})
  end

  describe "typedControllerResults.ts (route schemas)" do
    test "POST body: required code accepted, optional remember_me nullable, unknown key refused" do
      r = routes()["login"]

      parse(r["body"], [
        {true, %{"code" => "abc"}},
        {true, %{"code" => "abc", "remember_me" => nil}},
        {true, %{"code" => "abc", "remember_me" => true}},
        {false, %{}},
        {false, %{"code" => "abc", "extra" => 1}},
        {false, %{"code" => "abc", "remember_me" => "yes"}}
      ])
    end

    test "path param + body of a mutation route are separate schemas" do
      r = routes()["update_provider"]
      assert r["path_params"] == ["provider"]
      parse(r["params"], [{true, %{"provider" => "github"}}, {false, %{}}])
      parse(r["body"], [{true, %{"enabled" => true}}, {false, %{"enabled" => "x"}}])
    end

    test "GET query carries array arguments; response array of objects" do
      r = routes()["search"]

      parse(r["query"], [
        {true, %{"q" => "term", "tags" => ["elixir", "ash"]}},
        {true, %{"q" => "term"}},
        {false, %{"tags" => ["a"]}},
        {false, %{"q" => "t", "tags" => [1]}}
      ])

      parse(r["response"], [
        {true, [%{"id" => "1", "tag_names" => ["a"]}]},
        {true, []},
        {false, %{"id" => "1"}}
      ])
    end

    test "no-argument route has empty strict schemas and an object response" do
      r = routes()["profile"]
      parse(r["query"], [{true, %{}}, {false, %{"x" => 1}}])
      parse(r["response"], [{true, %{"anything" => 1}}, {false, "str"}])
    end
  end

  describe "structArguments.ts / untypedMaps.ts (object-valued arguments)" do
    for kind <- ~w(struct map keyword) do
      test "#{kind} argument accepts nested objects and refuses scalars and arrays" do
        {:ok, [r]} =
          RouteSchema.build([
            %{
              "name" => "assign",
              "method" => "post",
              "path" => "/assign",
              "arguments" => [arg("payload", unquote(kind), false)],
              "returns" => %{"type" => %{"kind" => "map"}}
            }
          ])

        parse(r["body"], [
          {true,
           %{"payload" => %{"id" => "1", "name" => "Test User", "email" => "t@example.com"}}},
          {true,
           %{
             "payload" => %{
               "nested" => %{"level2" => %{"level3" => "deep"}},
               "arr" => [%{"id" => 1}],
               "n" => nil
             }
           }},
          {false, %{"payload" => "str"}},
          {false, %{"payload" => [1, 2]}},
          {false, %{}}
        ])
      end
    end

    test "array-of-struct argument (assignees) accepts a list of objects only" do
      {:ok, [r]} =
        RouteSchema.build([
          %{
            "name" => "assign_many",
            "method" => "post",
            "path" => "/assign_many",
            "arguments" => [
              %{
                "name" => "assignees",
                "type" => %{"kind" => "array", "items" => %{"kind" => "struct"}},
                "allow_nil?" => false
              }
            ],
            "returns" => %{"type" => %{"kind" => "map"}}
          }
        ])

      parse(r["body"], [
        {true, %{"assignees" => [%{"id" => "1"}, %{"id" => "2"}]}},
        {false, %{"assignees" => ["x"]}},
        {false, %{"assignees" => %{"id" => "1"}}}
      ])
    end
  end
end
