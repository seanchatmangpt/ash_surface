defmodule AshShadcnWeb.Plugins do
  @moduledoc """
  Backend plugin seam. Each fan-out lane owns exactly one `lib/ash_shadcn_web/routes/<lane>.ex`
  defining `defmacro routes/0`; the router expands all of them inside the `/admin/api` scope.
  """
  defmacro all_routes do
    for lane <- ~w(realtime auth ai ide workflow jobs history jsonapi surface)a do
      mod = Module.concat(AshShadcnWeb.Routes, lane |> Atom.to_string() |> Macro.camelize())
      quote do
        require unquote(mod)
        unquote(mod).routes()
      end
    end
  end
end
