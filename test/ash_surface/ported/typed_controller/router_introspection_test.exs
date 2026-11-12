defmodule AshSurface.Ported.TypedController.RouterIntrospectionTest do
  @moduledoc """
  Port of ash_typescript typed_controller/router_introspection_test.exs: real Phoenix routers
  introspected by `RouteSchema.Introspector` (typed errors replace the reference's raises;
  verbs and path params are strings, the config is `[{source, controller, routes}]`).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema.Introspector

  defmodule SessionController do
    def init(a), do: a
    def call(conn, _), do: conn
  end

  @routes [
    {:get, "/auth", :auth},
    {:get, "/auth/providers/:provider", :provider_page},
    {:get, "/search", :search},
    {:post, "/auth/login", :login},
    {:post, "/auth/logout", :logout},
    {:patch, "/auth/providers/:provider", :update_provider},
    {:get, "/profile", :profile},
    {:post, "/raise-error", :raise_error},
    {:post, "/echo", :echo_params},
    {:post, "/register", :register},
    {:post, "/tasks", :create_task}
  ]

  defmodule SingleRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SessionController, as: C

    scope "/" do
      get("/auth", C, :auth)
      get("/auth/providers/:provider", C, :provider_page)
      get("/search", C, :search)
      post("/auth/login", C, :login)
      post("/auth/logout", C, :logout)
      patch("/auth/providers/:provider", C, :update_provider)
      get("/profile", C, :profile)
      post("/raise-error", C, :raise_error)
      post("/echo", C, :echo_params)
      post("/register", C, :register)
      post("/tasks", C, :create_task)
    end
  end

  defmodule MultiMountRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SessionController, as: C

    scope "/admin", as: :admin do
      get("/auth", C, :auth)
      get("/auth/providers/:provider", C, :provider_page)
      get("/search", C, :search)
      get("/profile/:user_id", C, :profile)
      post("/auth/login", C, :login)
      post("/auth/logout", C, :logout)
      patch("/auth/providers/:provider", C, :update_provider)
      post("/raise-error", C, :raise_error)
      post("/echo", C, :echo_params)
      post("/register", C, :register)
      post("/tasks", C, :create_task)
    end

    scope "/app", as: :app do
      get("/auth", C, :auth)
      get("/auth/providers/:provider", C, :provider_page)
      get("/search", C, :search)
      get("/profile", C, :profile)
      post("/auth/login", C, :login)
      post("/auth/logout", C, :logout)
      patch("/auth/providers/:provider", C, :update_provider)
      post("/raise-error", C, :raise_error)
      post("/echo", C, :echo_params)
      post("/register", C, :register)
      post("/tasks", C, :create_task)
    end
  end

  defmodule NestedScopeRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SessionController, as: C

    scope "/api", as: :api do
      scope "/v1", as: :v1 do
        get("/auth", C, :auth)
        get("/auth/providers/:provider", C, :provider_page)
      end

      scope "/v2", as: :v2 do
        get("/auth", C, :auth)
        get("/auth/providers/:provider", C, :provider_page)
      end
    end

    scope "/legacy", as: :legacy do
      get("/auth", C, :auth)
      get("/auth/providers/:provider", C, :provider_page)
    end
  end

  defmodule AmbiguousRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SessionController, as: C

    scope "/admin" do
      get("/auth", C, :auth)
    end

    scope "/app" do
      get("/auth", C, :auth)
    end
  end

  defmodule OtherController do
    def init(a), do: a
    def call(conn, _), do: conn
  end

  defmodule SharedActionRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.OtherController, as: O
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SessionController, as: C

    scope "/" do
      get("/other/auth", O, :auth)
      get("/auth", C, :auth)
    end
  end

  # Declared in reverse of sorted order so ordering is observable.
  defmodule ReverseRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SessionController, as: C

    scope "/zulu", as: :zulu do
      get("/auth", C, :auth)
    end

    scope "/alpha", as: :alpha do
      get("/auth", C, :auth)
    end

    post("/b", C, :login)
    get("/b", C, :login)
    get("/a", C, :profile)
  end

  defp config do
    routes = for {m, _p, n} <- @routes, do: %{name: n, method: m}
    [{:session, SessionController, routes}]
  end

  defp config_only(names) do
    [{:session, SessionController, for(n <- names, do: %{name: n, method: :get})}]
  end

  describe "single mount router introspection" do
    test "introspects test router and matches routes to descriptor config" do
      assert {:ok, infos} = Introspector.introspect(SingleRouter, config())
      assert length(infos) == 11

      auth = Enum.find(infos, &(&1.route.name == :auth))
      assert %{path: "/auth", method: "get", path_params: [], scope_prefix: nil} = auth

      pp = Enum.find(infos, &(&1.route.name == :provider_page))
      assert %{path: "/auth/providers/:provider", method: "get", path_params: ["provider"]} = pp
      assert pp.scope_prefix == nil

      search = Enum.find(infos, &(&1.route.name == :search))
      assert %{path: "/search", path_params: [], scope_prefix: nil} = search

      login = Enum.find(infos, &(&1.route.name == :login))
      assert %{path: "/auth/login", method: "post", scope_prefix: nil} = login

      up = Enum.find(infos, &(&1.route.name == :update_provider))
      assert %{path: "/auth/providers/:provider", method: "patch", path_params: ["provider"]} = up
      assert up.scope_prefix == nil
    end
  end

  describe "multi-mount router introspection" do
    test "returns multiple entries per route with scope prefixes" do
      assert {:ok, infos} = Introspector.introspect(MultiMountRouter, config())
      assert length(infos) == 22

      auth = Enum.filter(infos, &(&1.route.name == :auth))
      assert auth |> Enum.map(& &1.scope_prefix) |> Enum.sort() == ["admin", "app"]
      assert Enum.find(auth, &(&1.scope_prefix == "admin")).path == "/admin/auth"
      assert Enum.find(auth, &(&1.scope_prefix == "app")).path == "/app/auth"

      providers = Enum.filter(infos, &(&1.route.name == :provider_page))
      assert length(providers) == 2
      admin = Enum.find(providers, &(&1.scope_prefix == "admin"))
      assert admin.path == "/admin/auth/providers/:provider"
      assert admin.path_params == ["provider"]
    end
  end

  describe "nested scope router introspection" do
    test "resolves scope prefixes and path params through nested scopes" do
      assert {:ok, infos} =
               Introspector.introspect(NestedScopeRouter, config_only([:auth, :provider_page]))

      auth = Enum.filter(infos, &(&1.route.name == :auth))
      assert auth |> Enum.map(& &1.scope_prefix) |> Enum.sort() == ["api_v1", "api_v2", "legacy"]
      assert Enum.find(auth, &(&1.scope_prefix == "api_v1")).path == "/api/v1/auth"

      providers = Enum.filter(infos, &(&1.route.name == :provider_page))
      assert length(providers) == 3
      v2 = Enum.find(providers, &(&1.scope_prefix == "api_v2"))
      assert v2.path == "/api/v2/auth/providers/:provider"
      assert v2.path_params == ["provider"]
    end
  end

  describe "ambiguous mount detection" do
    test "controller mounted at multiple paths without as: options is a typed error" do
      assert {:error, {:ambiguous_mount, SessionController, :auth, mounts}} =
               Introspector.introspect(AmbiguousRouter, config_only([:auth]))

      assert is_list(mounts)
    end

    test "error carries the conflicting paths and the route name" do
      assert {:error, {:ambiguous_mount, _c, :auth, mounts}} =
               Introspector.introspect(AmbiguousRouter, config_only([:auth]))

      assert mounts == [{"get", "/admin/auth"}, {"get", "/app/auth"}]
    end

    test "error carries the unmangled controller module" do
      assert {:error, {:ambiguous_mount, controller, :auth, _}} =
               Introspector.introspect(AmbiguousRouter, config_only([:auth]))

      assert inspect(controller) =~ "RouterIntrospectionTest.SessionController"
      refute inspect(controller) =~ "Elixir."
    end
  end

  describe "controller identity" do
    test "a route name shared by another controller matches only the configured controller" do
      assert {:ok, [info]} = Introspector.introspect(SharedActionRouter, config_only([:auth]))
      assert info.path == "/auth"
      assert info.controller == SessionController
      assert info.scope_prefix == nil
    end
  end

  describe "ordering" do
    test "multi-mount infos are ordered by path regardless of declaration order" do
      assert {:ok, infos} = Introspector.introspect(ReverseRouter, config_only([:auth]))
      assert Enum.map(infos, & &1.path) == ["/alpha/auth", "/zulu/auth"]
      assert Enum.map(infos, & &1.scope_prefix) == ["alpha", "zulu"]
    end

    test "introspect_router lists routes sorted by {path, verb}" do
      assert {:ok, routes} = Introspector.introspect_router(ReverseRouter)

      assert Enum.map(routes, &{&1.path, &1.verb}) == [
               {"/a", "get"},
               {"/alpha/auth", "get"},
               {"/b", "get"},
               {"/b", "post"},
               {"/zulu/auth", "get"}
             ]
    end

    test "introspect_router reports path params as strings" do
      assert {:ok, routes} = Introspector.introspect_router(SingleRouter)
      pp = Enum.find(routes, &(&1.path == "/auth/providers/:provider" and &1.verb == "get"))
      assert pp.path_params == ["provider"]
    end
  end

  describe "method normalization" do
    test "an unmounted route's configured method is lowercased" do
      cfg = [
        {:session, SessionController,
         [%{name: :nowhere, method: "GET"}, %{name: :x, method: :POST}]}
      ]

      assert {:ok, [a, b]} = Introspector.introspect(SingleRouter, cfg)
      assert a.path == nil and a.method == "get"
      assert b.method == "post"
    end

    test "a missing method stays nil" do
      cfg = [{:session, SessionController, [%{name: :nowhere}]}]
      assert {:ok, [%{method: nil}]} = Introspector.introspect(SingleRouter, cfg)
    end
  end

  defmodule SegCtl do
    def init(a), do: a
    def call(conn, _), do: conn
  end

  defmodule AlphaZetaRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    scope "/alpha", as: :alpha do
      get("/auth", S, :auth)
    end

    scope "/zeta", as: :zeta do
      get("/auth", S, :auth)
    end
  end

  defmodule SharedCharRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    scope "/ab", as: :ab do
      get("/auth", S, :auth)
    end

    scope "/b", as: :b do
      get("/auth", S, :auth)
    end
  end

  defmodule UnscopedPlusScopedRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    get("/auth", S, :auth)

    scope "/x", as: :x do
      get("/auth", S, :auth)
    end
  end

  defmodule SuffixOfRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    scope "/p", as: :p do
      get("/auth", S, :auth)
    end

    scope "/p/q", as: :p_q do
      get("/auth", S, :auth)
    end
  end

  defmodule IdenticalPathRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    scope "/same", as: :one do
      get("/auth", S, :auth)
    end

    scope "/same", as: :one do
      get("/auth", S, :auth)
    end
  end

  defmodule TrailingParamRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    scope "/alpha/", as: :alpha do
      get("/:id/auth/", S, :auth)
    end

    scope "/zeta", as: :zeta do
      get("/:id/auth", S, :auth)
    end
  end

  defmodule NestedAsRouter do
    use Phoenix.Router
    alias AshSurface.Ported.TypedController.RouterIntrospectionTest.SegCtl, as: S
    scope "/api", as: :api do
      scope "/auth", as: :auth do
        get("/auth", S, :auth)
      end

      scope "/other", as: :other do
        get("/auth", S, :auth)
      end
    end
  end

  defp prefixes(router) do
    assert {:ok, infos} =
             Introspector.introspect(router, [{:s, SegCtl, [%{name: :auth, method: :get}]}])

    infos |> Enum.map(&{&1.path, &1.scope_prefix}) |> Enum.sort()
  end

  describe "segment-wise scope prefix derivation" do
    test "alpha/zeta keep whole prefixes (no shared trailing character trimmed)" do
      assert prefixes(AlphaZetaRouter) == [{"/alpha/auth", "alpha"}, {"/zeta/auth", "zeta"}]
    end

    test "prefixes sharing a trailing character keep it when segments differ" do
      assert prefixes(SharedCharRouter) == [{"/ab/auth", "ab"}, {"/b/auth", "b"}]
    end

    test "unscoped mount beside a scoped one gets an empty prefix, scoped keeps its name" do
      assert prefixes(UnscopedPlusScopedRouter) == [{"/auth", ""}, {"/x/auth", "x"}]
    end

    test "one scope name being a segment-suffix of another" do
      assert prefixes(SuffixOfRouter) == [{"/p/auth", "p"}, {"/p/q/auth", "p_q"}]
    end

    test "identical mount paths with identical helpers are a typed ambiguous_mount error" do
      assert {:error, {:ambiguous_mount, SegCtl, :auth, mounts}} =
               Introspector.introspect(IdenticalPathRouter, [
                 {:s, SegCtl, [%{name: :auth, method: :get}]}
               ])

      assert mounts == [{"get", "/same/auth"}, {"get", "/same/auth"}]
    end

    test "trailing slashes and :id params do not disturb prefixes or params" do
      assert {:ok, infos} =
               Introspector.introspect(TrailingParamRouter, [
                 {:s, SegCtl, [%{name: :auth, method: :get}]}
               ])

      assert infos |> Enum.map(& &1.scope_prefix) |> Enum.sort() == ["alpha", "zeta"]
      assert Enum.all?(infos, &(&1.path_params == ["id"]))
    end

    test "nested scopes whose prefix repeats a suffix segment keep the whole segment" do
      assert prefixes(NestedAsRouter) == [
               {"/api/auth/auth", "api_auth"},
               {"/api/other/auth", "api_other"}
             ]
    end
  end
end
