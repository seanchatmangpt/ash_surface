defmodule PlaygroundWeb.Router do
  use Phoenix.Router
  require AshShadcnWeb.Plugins

  get "/", PlaygroundWeb.PageController, :index
  get "/artifact.mjs", PlaygroundWeb.PageController, :artifact
  get "/contract/:id", PlaygroundWeb.PageController, :contract

  scope "/admin/api", AshShadcnWeb do
    get "/domains", ApiController, :domains
    get "/actors", ApiController, :actors
    get "/resources/:resource", ApiController, :resource
    get "/resources/:resource/records", ApiController, :index
    get "/resources/:resource/records/:id", ApiController, :show
    get "/resources/:resource/export", ApiController, :export
    post "/resources/:resource/bulk", ApiController, :bulk
    post "/resources/:resource/validate", ApiController, :validate
    post "/resources/:resource/submit", ApiController, :submit
    post "/resources/:resource/run", ApiController, :run_action

    AshShadcnWeb.Plugins.all_routes()
  end

  # SPA shell: every /admin/* path renders the React app (SSR + hydrate).
  get "/admin", AshShadcnWeb.AdminController, :index
  get "/admin/*path", AshShadcnWeb.AdminController, :index
end
