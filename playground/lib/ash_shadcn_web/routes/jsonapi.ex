defmodule AshShadcnWeb.Routes.Jsonapi do
  @moduledoc """
  Lane `jsonapi` routes (inside scope "/admin/api", module AshShadcnWeb).
  The JSON:API router is forwarded at /admin/api/json (scope-relative; the main router can
  additionally `forward "/api/json", Playground.JsonApiRouter`).
  """
  defmacro routes do
    quote do
      get "/openapi", JsonapiController, :openapi
      get "/jsonapi/routes", JsonapiController, :routes
      forward "/json", JsonApiPipeline, []
    end
  end
end
