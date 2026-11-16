defmodule Playground.JsonApiRouter do
  @moduledoc "AshJsonApi router; mounted at /admin/api/json (see AshShadcnWeb.Routes.Jsonapi)."
  use AshJsonApi.Router,
    domains: [Playground.Blog],
    prefix: "/admin/api/json",
    open_api: "/open_api"
end
