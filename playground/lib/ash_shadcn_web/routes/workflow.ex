defmodule AshShadcnWeb.Routes.Workflow do
  @moduledoc "Lane `workflow` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      get "/workflows", WorkflowController, :index
      get "/workflows/:name/graph", WorkflowController, :graph
      post "/workflows/:name/run", WorkflowController, :run
    end
  end
end
