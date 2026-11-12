defmodule AshSurface.Ported.TS.ShouldFail.TypedControllerResultsFailTest do
  @moduledoc """
  Adaptation of ash_typescript `test/ts/shouldFail/typedControllerResults.ts`. The reference
  asserts TS type errors on generated route fetch functions (`login`, `updateProvider`,
  `search`, `routes.*`). ash_surface emits no `.ts` route functions (README), so the
  value-level half is asserted instead: the per-route Zod schemas (`RouteSchema`, real zod
  under node) refuse the values the TS types refused, with typed issues. The fetch-wrapper
  half (`response.ok` narrowing, path-helper-only GET routes) has no ash_surface counterpart
  and is recorded per test in the ledger row.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.ZodFixtures.HarnessExt

  defp arg(name, kind, nil?, extra \\ %{}),
    do: Map.merge(%{"name" => name, "type" => %{"kind" => kind}, "allow_nil?" => nil?}, extra)

  defp run(expr, cases) do
    cases = Enum.with_index(cases, fn {p}, i -> %{label: "c#{i}", expect: false, payload: p} end)
    HarnessExt.run_fragment!(expr, cases)
  end

  defp refuses(expr, payloads) do
    for r <- run(expr, Enum.map(payloads, &{&1})) do
      assert r["success"] == false, "#{r["label"]} #{expr} accepted a refused value"
      assert r["issues"] != [], "#{r["label"]}: refusal carries no typed issue"
    end
  end

  defp accepts(expr, payloads) do
    for r <- run(expr, Enum.map(payloads, &{&1})) do
      assert r["success"] == true, "#{r["label"]} #{expr}: #{inspect(r["issues"])}"
    end
  end

  defp routes do
    summary = %{
      "type" => %{
        "kind" => "map",
        "fields" => %{
          "user_id" => %{"kind" => "uuid"},
          "field1" => %{"kind" => "string"}
        }
      }
    }

    {:ok, built} =
      AshSurface.Ported.AshNames.with_verbatim(fn ->
        RouteSchema.build([
          %{
            "name" => "login",
            "method" => "post",
            "path" => "/login",
            "arguments" => [arg("code", "string", false)],
            "returns" => summary
          },
          %{
            "name" => "update_provider",
            "method" => "patch",
            "path" => "/providers/:provider",
            "arguments" => [arg("provider", "string", false), arg("enabled", "boolean", false)],
            "returns" => summary
          },
          %{
            "name" => "search",
            "method" => "get",
            "path" => "/search",
            "arguments" => [arg("q", "string", false), arg("page", "integer", true)],
            "returns" => %{
              "type" => %{
                "kind" => "array",
                "items" => %{
                  "kind" => "map",
                  "fields" => %{
                    "tag_names" => %{"kind" => "array", "items" => %{"kind" => "string"}}
                  }
                }
              }
            }
          }
        ])
      end)

    Map.new(built, &{&1["name"], &1})
  end

  @uuid "123e4567-e89b-12d3-a456-426614174000"

  test "testResultShape: a search response is an array of objects, never a bare object" do
    r = routes()["search"]["response"]
    accepts(r, [[%{"tag_names" => ["a"]}], []])
    refuses(r, [%{"tag_names" => ["a"]}, "text", nil])
  end

  test "testWrongFieldTypes: a typed route result refuses a numeric user_id" do
    r = routes()["login"]["response"]
    refuses(r, [%{"user_id" => 123, "field1" => "x"}, %{"user_id" => @uuid, "field1" => 1}])
  end

  test "testUnmappedFieldName: a response carrying field_1 instead of field1 is refused" do
    r = routes()["login"]["response"]
    refuses(r, [%{"user_id" => @uuid, "field_1" => "x"}])
    accepts(r, [%{"user_id" => @uuid, "field1" => "x"}])
  end

  test "testResultShape: tag_names is a non-nullable array" do
    r = routes()["search"]["response"]
    refuses(r, [[%{"tag_names" => nil}], [%{"tag_names" => [1]}]])
    accepts(r, [[%{"tag_names" => []}]])
  end

  test "undeclared returns keep the open record" do
    {:ok, [route]} =
      RouteSchema.build([
        %{
          "name" => "open",
          "method" => "get",
          "path" => "/open",
          "arguments" => [],
          "returns" => %{"type" => %{"kind" => "map"}}
        }
      ])

    accepts(route["response"], [%{"anything" => 1}])
  end

  test "testGetFetchFunctionArgs: q is a required query argument" do
    q = routes()["search"]["query"]
    accepts(q, [%{"q" => "term"}, %{"q" => "term", "page" => 1}])
    refuses(q, [%{"page" => 1}, %{}, %{"q" => 5}])
  end

  test "testBodyUntypedBeforeNarrowing / testErrorBodyIsNotResult: a non-object body is refused by the response schema" do
    r = routes()["login"]["response"]
    accepts(r, [%{"user_id" => @uuid, "field1" => "x"}])
    refuses(r, ["string body", nil, [1]])
  end

  test "the path-parameter and body schemas of a mutation route stay separate (provider path param is not body)" do
    r = routes()["update_provider"]
    assert r["path_params"] == ["provider"]
    accepts(r["body"], [%{"enabled" => true}])
    refuses(r["body"], [%{"enabled" => "yes"}, %{}])
  end

  test "argument schemas are strict: undeclared extra keys are refused (body and query)" do
    r = routes()
    refuses(r["update_provider"]["body"], [%{"enabled" => true, "extra" => 1}])
    refuses(r["search"]["query"], [%{"q" => "term", "extra" => 1}])
    accepts(r["search"]["query"], [%{"q" => "term"}])
  end
end
