defmodule AshShadcnWeb.JsonapiController do
  use Phoenix.Controller, formats: [:json]

  def openapi(conn, _), do: json(conn, AshShadcn.JsonApi.spec())
  def routes(conn, _), do: json(conn, %{routes: AshShadcn.JsonApi.routes()})
end
