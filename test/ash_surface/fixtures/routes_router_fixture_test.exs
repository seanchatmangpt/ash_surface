defmodule AshSurface.Fixtures.RoutesRouterFixtureTest do
  use ExUnit.Case, async: true

  if Code.ensure_loaded?(Phoenix.Router) do
    test "router exposes its declared routes" do
      routes = Phoenix.Router.routes(AshSurface.ZodFixtures.RoutesRouter)
      assert {:get, "/items/:id"} in Enum.map(routes, &{&1.verb, &1.path})
      assert length(routes) == 5
    end
  else
    test "Phoenix.Router absent: fixture not defined" do
      refute Code.ensure_loaded?(AshSurface.ZodFixtures.RoutesRouter)
    end
  end
end
