defmodule AshSurface.Dsl.TypedControllerChannelParityTest do
  @moduledoc """
  Parity courts for ash_typescript's `typed_controller` and `typed_channel` DSLs.

  Documented analogues (descriptor-only; no controller or channel module is generated):
  typed_controller route/argument <-> `RouteSchema` route descriptors introspected from the
  Phoenix router (`RouteSchema.introspect_router/1`); typed_channel `resource` entity <->
  `ChannelDiscovery.discover/1` channel spec `resources: [Module | {Module, events}]`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{ChannelDiscovery, RouteSchema}
  alias AshSurface.ChannelFixtures.Item

  defp arg(n, extra \\ %{}),
    do: Map.merge(%{"name" => n, "type" => %{"kind" => "string"}, "allow_nil?" => false}, extra)

  defp route(m, path, args, extra \\ %{}),
    do: Map.merge(%{"name" => "r", "method" => m, "path" => path, "arguments" => args}, extra)

  test "typed_controller route entity: descriptors build deterministically sorted by path" do
    {:ok, built} =
      RouteSchema.build([route("get", "/b", []), route("get", "/a", [], %{"name" => "a"})])

    assert Enum.map(built, & &1["path"]) == ["/a", "/b"]

    assert {:ok, ^built} =
             RouteSchema.build([route("get", "/a", [], %{"name" => "a"}), route("get", "/b", [])])
  end

  test "typed_controller route option name: carried, duplicate refused per scope prefix" do
    assert {:ok, [%{"name" => "show"}]} =
             RouteSchema.build([route("get", "/a", [], %{"name" => "show"})])

    assert {:error, {:duplicate_route_name, "dup", nil}} =
             RouteSchema.build([
               route("get", "/a", [], %{"name" => "dup"}),
               route("get", "/b", [], %{"name" => "dup"})
             ])
  end

  test "typed_controller route option method: verb normalized and decides query vs body" do
    {:ok, [g]} = RouteSchema.build([route("GET", "/a", [arg("q")])])
    {:ok, [p]} = RouteSchema.build([route("post", "/a", [arg("q")])])
    assert g["method"] == "get" and g["query"] =~ "q:" and g["body"] == "z.object({}).strict()"
    assert p["method"] == "post" and p["body"] =~ "q:" and p["query"] == "z.object({}).strict()"
  end

  test "typed_controller route option namespace: scope_prefix distinguishes equal names" do
    assert {:ok, [_, _]} =
             RouteSchema.build([
               route("get", "/v1/a", [], %{"name" => "auth", "scope_prefix" => "/v1"}),
               route("get", "/v2/a", [], %{"name" => "auth", "scope_prefix" => "/v2"})
             ])
  end

  test "typed_controller route option returns and constraints shape the response schema" do
    {:ok, [a]} =
      RouteSchema.build([
        route("get", "/a", [], %{"returns" => %{"type" => %{"kind" => "integer"}}})
      ])

    assert a["response"] =~ "z.number().int()"

    {:ok, [b]} =
      RouteSchema.build([
        route("get", "/b", [], %{"returns" => "string", "constraints" => %{"min_length" => 2}})
      ])

    assert b["response"] =~ "min(2)"
  end

  test "typed_controller argument entity option name: required, unique, strict object keys" do
    assert {:error, {:duplicate_argument, "r", "x"}} =
             RouteSchema.build([route("post", "/a", [arg("x"), arg("x")])])

    assert {:error, {:argument_without_name, "r", nil}} =
             RouteSchema.build([route("post", "/a", [%{"type" => %{"kind" => "string"}}])])

    {:ok, [r]} = RouteSchema.build([route("post", "/a", [arg("x")])])
    assert r["body"] =~ ".strict()"
  end

  test "typed_controller argument option type: kind selects the schema fragment" do
    {:ok, [r]} =
      RouteSchema.build([
        route("post", "/a", [arg("n", %{"type" => %{"kind" => "integer"}}), arg("s")])
      ])

    assert r["body"] =~ "n: z.number().int()"
    assert r["body"] =~ "s: z.string()"
  end

  test "typed_controller argument option allow_nil?: nullable unless false; path param must be non-null" do
    bare = %{"name" => "id", "type" => %{"kind" => "string"}}

    assert {:error, {:path_param_nullable, "r", "id"}} =
             RouteSchema.build([route("get", "/a/:id", [bare])])

    {:ok, [r]} = RouteSchema.build([route("post", "/a", [Map.delete(arg("q"), "allow_nil?")])])
    assert r["body"] =~ ".nullable().optional()"
  end

  test "typed_controller argument option constraints: carried into the argument schema" do
    {:ok, [r]} =
      RouteSchema.build([
        route("post", "/a", [arg("s", %{"constraints" => %{"min_length" => 3}})])
      ])

    assert r["body"] =~ "min(3)"
  end

  test "typed_controller argument option default: a defaulted argument renders optional" do
    {:ok, [r]} = RouteSchema.build([route("post", "/a", [arg("s", %{"default" => "x"})])])
    assert r["body"] =~ "optional()" or r["body"] =~ "default("
  end

  test "typed_controller section: routes are introspected from the Phoenix router" do
    assert {:error, :phoenix_unavailable} = RouteSchema.introspect_router(NoSuchRouterG2)
  end

  test "typed_channel resource entity option module: bare module takes all publications, tuple selects events" do
    assert {:ok, %{"channels" => [%{"events" => all}]}} =
             ChannelDiscovery.discover([%{name: "Org", topic: "org:*", resources: [Item]}])

    assert Enum.sort(Enum.map(all, & &1["event"])) == ~w(item_created item_updated)

    assert {:ok, %{"channels" => [%{"events" => [%{"event" => "item_updated"}]}]}} =
             ChannelDiscovery.discover([
               %{name: "Org", topic: "org:*", resources: [{Item, [:item_updated]}]}
             ])
  end

  test "typed_channel section: a discovery spec yields a named channel with a topic" do
    assert {:ok, %{"channels" => [c]}} =
             ChannelDiscovery.discover([%{name: "Org", topic: "org:*", resources: [Item]}])

    assert c["name"] == "Org" and c["topic"] == "org:*"
  end
end
