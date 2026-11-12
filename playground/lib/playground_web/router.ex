defmodule PlaygroundWeb.Router do
  use Phoenix.Router

  get "/", PlaygroundWeb.PageController, :index
  get "/artifact.mjs", PlaygroundWeb.PageController, :artifact
  get "/contract/:id", PlaygroundWeb.PageController, :contract
end
