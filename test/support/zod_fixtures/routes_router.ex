if Code.ensure_loaded?(Phoenix.Router) do
  defmodule AshSurface.ZodFixtures.RoutesController do
    @moduledoc false
    def init(action), do: action
    def call(conn, _action), do: conn
  end

  defmodule AshSurface.ZodFixtures.RoutesRouter do
    @moduledoc "Small Phoenix.Router fixture for route-introspection tests."
    use Phoenix.Router

    scope "/" do
      get("/items", AshSurface.ZodFixtures.RoutesController, :index)
      get("/items/:id", AshSurface.ZodFixtures.RoutesController, :show)
      post("/items", AshSurface.ZodFixtures.RoutesController, :create)
      patch("/items/:id", AshSurface.ZodFixtures.RoutesController, :update)
      delete("/items/:id", AshSurface.ZodFixtures.RoutesController, :delete)
    end
  end
end
