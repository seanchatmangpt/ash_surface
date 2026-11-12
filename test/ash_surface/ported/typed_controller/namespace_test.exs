Code.require_file("support/tc_support.exs", __DIR__)

defmodule AshSurface.Ported.TypedController.NamespaceTest do
  @moduledoc """
  Port of ash_typescript typed_controller/namespace_test.exs. ash_surface has no
  controller-level namespace nor generated re-export files; the surviving contract is the
  per-route `"namespace"` option carried verbatim on `RouteSchema` descriptors (route-level
  precedence is vacuous without a controller level), which downstream consumers group on.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.TypedController.Support, as: S

  defp routes do
    [
      S.route("auth", "get", "/auth", [], %{"namespace" => "session"}),
      S.route("login", "post", "/login", [S.arg("u")], %{"namespace" => "session"}),
      S.route("profile", "get", "/profile", [], %{"namespace" => "account"}),
      S.route("health", "get", "/health")
    ]
  end

  describe "namespace resolution" do
    test "route-level namespace is carried on the descriptor" do
      by_name = Map.new(S.build!(routes()), &{&1["name"], &1})
      assert by_name["auth"]["namespace"] == "session"
      assert by_name["profile"]["namespace"] == "account"
    end

    test "a route without a namespace carries no namespace key" do
      by_name = Map.new(S.build!(routes()), &{&1["name"], &1})
      refute Map.has_key?(by_name["health"], "namespace")
    end

    test "an empty-string namespace is treated as absent" do
      [r] = S.build!([S.route("x", "get", "/x", [], %{"namespace" => ""})])
      refute Map.has_key?(r, "namespace")
    end
  end

  describe "routes grouped by namespace" do
    test "descriptors group by namespace with a nil group for un-namespaced routes" do
      groups =
        routes()
        |> S.build!()
        |> Enum.group_by(& &1["namespace"], & &1["name"])
        |> Map.new(fn {k, v} -> {k, Enum.sort(v)} end)

      assert groups == %{
               "session" => ["auth", "login"],
               "account" => ["profile"],
               nil => ["health"]
             }
    end

    test "namespace does not change the schemas of a route" do
      [with_ns] =
        S.build!([S.route("login", "post", "/login", [S.arg("u")], %{"namespace" => "s"})])

      [without] = S.build!([S.route("login", "post", "/login", [S.arg("u")])])
      assert Map.delete(with_ns, "namespace") == without
    end
  end

  describe "route exports collection (per-route schema surface)" do
    test "GET routes with query args expose a query schema; mutation routes expose a body schema" do
      by_name =
        Map.new(
          S.build!(routes() ++ [S.route("search", "get", "/search", [S.arg("q")])]),
          &{&1["name"], &1}
        )

      assert by_name["search"]["query"] =~ "q:"
      assert by_name["login"]["body"] =~ "u:"
      # input types are not collected for GET routes: GET args never land in the body
      assert by_name["search"]["body"] == "z.object({}).strict()"
    end

    test "result schemas exist for routes declaring returns" do
      [r] = S.build!([S.route("me", "get", "/me", [], %{"returns" => "string"})])
      assert [true, false] = S.node_parse(r["response"], ["a", 1])
    end
  end
end
