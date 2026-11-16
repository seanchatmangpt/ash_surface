defmodule AshShadcnWeb.Routes.Jobs do
  @moduledoc "Lane `jobs` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      get "/jobs/triggers", JobsController, :triggers
      post "/jobs/triggers/:resource/:name/run", JobsController, :run_trigger
      get "/jobs", JobsController, :index
      post "/jobs/:id/cancel", JobsController, :cancel
      post "/jobs/:id/retry", JobsController, :retry
    end
  end
end
