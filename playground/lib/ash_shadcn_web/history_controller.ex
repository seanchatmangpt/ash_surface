defmodule AshShadcnWeb.HistoryController do
  @moduledoc "Version history, state machine graph and archived records for the admin."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias AshShadcn.{Data, History}

  def versions(conn, %{"resource" => r, "id" => id} = params),
    do: with_resource(conn, r, fn res -> reply(conn, History.versions(res, id, ctx(params))) end)

  def state_machine(conn, %{"resource" => r}),
    do: with_resource(conn, r, fn res -> reply(conn, History.state_machine(res)) end)

  def archived(conn, %{"resource" => r} = params),
    do: with_resource(conn, r, fn res -> reply(conn, History.archived(res, ctx(params))) end)

  def restore(conn, %{"resource" => r, "id" => id} = params),
    do: with_resource(conn, r, fn res -> reply(conn, History.restore(res, id, ctx(params))) end)

  defp with_resource(conn, name, fun) do
    fun.(AshShadcn.resource!(name))
  rescue
    e in ArgumentError -> conn |> put_status(404) |> json(%{error: "not_found", message: e.message})
  end

  defp reply(conn, {:ok, body}), do: json(conn, body)
  defp reply(conn, {:error, :not_found}), do: conn |> put_status(404) |> json(Data.error_body(:not_found))

  defp reply(conn, {:error, :not_applicable}),
    do: conn |> put_status(404) |> json(%{error: "not_applicable", message: "resource does not support this feature"})

  defp reply(conn, {:error, e}), do: conn |> put_status(422) |> json(Data.error_body(e))

  defp ctx(params) do
    [
      actor: AshShadcn.load_actor(params["actor_id"]),
      tenant: if(params["tenant"] in [nil, ""], do: nil, else: params["tenant"]),
      authorize?: params["authorize"] not in ["false", false]
    ]
  end
end
