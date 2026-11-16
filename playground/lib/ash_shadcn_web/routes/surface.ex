defmodule AshShadcnWeb.Routes.Surface do
  @moduledoc "Lane `surface` routes (inside scope \"/admin/api\", module AshShadcnWeb)."
  defmacro routes do
    quote do
      get "/surface/artifact.mjs", SurfaceController, :artifact
      get "/surface/resources/:resource", SurfaceController, :resource
    end
  end
end
