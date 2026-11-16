defmodule AshShadcnWeb.Routes.Ai do
  @moduledoc "Lane `ai` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      get "/ai/info", AiController, :info
      post "/ai/chat", AiController, :chat
    end
  end
end
