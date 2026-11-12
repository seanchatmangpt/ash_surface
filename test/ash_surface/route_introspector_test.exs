defmodule AshSurface.Compiler.RouteSchema.IntrospectorTest do
  use ExUnit.Case, async: true
  alias AshSurface.Compiler.RouteSchema.Introspector

  @phoenix Code.ensure_loaded?(Phoenix.Router)

  if @phoenix do
    for c <- [RcSessionController, RcPageController] do
      defmodule c do
        def init(a), do: a
        def call(conn, _), do: conn
      end
    end

    defmodule NestedRouter do
      use Phoenix.Router

      scope "/api", as: :api do
        scope "/v1", as: :v1 do
          get("/auth", RcSessionController, :auth)
          get("/auth/providers/:provider", RcSessionController, :provider_page)
        end

        scope "/v2", as: :v2 do
          get("/auth", RcSessionController, :auth)
        end
      end

      get("/single/:id", RcPageController, :show)
    end

    defmodule AmbiguousRouter do
      use Phoenix.Router

      scope "/admin" do
        get("/auth", RcSessionController, :auth)
      end

      scope "/app" do
        get("/auth", RcSessionController, :auth)
      end
    end
  end

  defp cfg(controller, names),
    do: [{:src, controller, Enum.map(names, &%{name: &1, method: :get})}]

  test "missing phoenix or router is a typed error" do
    assert {:error, :phoenix_unavailable} = Introspector.introspect(NoSuchRouter, [])
    assert {:error, :phoenix_unavailable} = Introspector.introspect_router(NoSuchRouter)
  end

  test "path_params are strings" do
    assert Introspector.path_params("/a/:id/b/:slug") == ["id", "slug"]
  end

  if @phoenix do
    test "nested scopes yield one info per mount with scope_prefix" do
      assert {:ok, infos} =
               Introspector.introspect(
                 __MODULE__.NestedRouter,
                 cfg(RcSessionController, [:auth, :provider_page])
               )

      auth = Enum.filter(infos, &(&1.route.name == :auth))
      assert Enum.sort(Enum.map(auth, & &1.scope_prefix)) == ["api_v1", "api_v2"]
      assert Enum.map(auth, & &1.path) |> Enum.sort() == ["/api/v1/auth", "/api/v2/auth"]
      assert [one] = Enum.filter(infos, &(&1.route.name == :provider_page))
      assert one.path_params == ["provider"]
      assert one.scope_prefix == nil
      assert one.method == "get"
    end

    test "single mount and unmounted routes" do
      assert {:ok, [info]} =
               Introspector.introspect(__MODULE__.NestedRouter, cfg(RcPageController, [:show]))

      assert %{path: "/single/:id", path_params: ["id"], scope_prefix: nil} = info

      assert {:ok, [none]} =
               Introspector.introspect(__MODULE__.NestedRouter, cfg(RcPageController, [:ghost]))

      assert %{path: nil, path_params: []} = none
    end

    test "ambiguous mount without unique helpers is a typed error" do
      assert {:error, {:ambiguous_mount, RcSessionController, :auth, mounts}} =
               Introspector.introspect(
                 __MODULE__.AmbiguousRouter,
                 cfg(RcSessionController, [:auth])
               )

      assert mounts == [{"get", "/admin/auth"}, {"get", "/app/auth"}]
    end

    test "introspect_router/1 lists routes deterministically and RouteSchema delegates" do
      assert {:ok, routes} = Introspector.introspect_router(__MODULE__.NestedRouter)
      assert routes == Enum.sort_by(routes, &{&1.path, &1.verb})

      assert {:ok, ^routes} =
               AshSurface.Compiler.RouteSchema.introspect_router(__MODULE__.NestedRouter)

      assert Enum.any?(routes, &(&1.path == "/single/:id" and &1.path_params == ["id"]))
    end
  end
end
