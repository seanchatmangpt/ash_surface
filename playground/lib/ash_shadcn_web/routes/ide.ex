defmodule AshShadcnWeb.Routes.Ide do
  @moduledoc "Lane `ide` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      get "/ide/tree", IdeController, :tree
      get "/ide/file", IdeController, :file
      post "/ide/run", IdeController, :run
    end
  end
end
