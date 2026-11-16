defmodule AshShadcnWeb.Routes.Auth do
  @moduledoc "Lane `auth` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      post "/auth/register", AuthController, :register
      post "/auth/sign_in", AuthController, :sign_in
      delete "/auth/sign_out", AuthController, :sign_out
      get "/auth/me", AuthController, :me
    end
  end
end
