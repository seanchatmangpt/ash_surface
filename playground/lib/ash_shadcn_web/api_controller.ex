defmodule AshShadcnWeb.ApiController do
  @moduledoc "JSON API behind the React admin. Actor/tenant/authorize travel as request params."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias AshShadcn.{Data, Introspect}

  def domains(conn, _), do: json(conn, %{domains: Introspect.domains()})

  def resource(conn, %{"resource" => r}), do: with_resource(conn, r, fn res -> json(conn, Introspect.resource(res)) end)

  def actors(conn, _) do
    case AshShadcn.actor_resource() do
      nil -> json(conn, %{actors: []})
      res -> json(conn, %{actors: res |> Ash.read!(authorize?: false) |> Enum.map(&Data.record/1)})
    end
  end

  def index(conn, %{"resource" => r} = params),
    do: with_resource(conn, r, fn res -> reply(conn, Data.read(res, params, ctx(conn, params))) end)

  def show(conn, %{"resource" => r, "id" => id} = params),
    do: with_resource(conn, r, fn res -> reply(conn, Data.get(res, id, params, ctx(conn, params))) end)

  def export(conn, %{"resource" => r} = params) do
    with_resource(conn, r, fn res ->
      case Data.export(res, params, ctx(conn, params)) do
        {:ok, {mime, filename, body}} ->
          conn
          |> put_resp_content_type(mime)
          |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
          |> send_resp(200, body)

        other ->
          reply(conn, other)
      end
    end)
  end

  def bulk(conn, %{"resource" => r} = params),
    do: with_resource(conn, r, fn res -> reply(conn, Data.bulk(res, params, ctx(conn, params))) end)

  def validate(conn, %{"resource" => r} = params),
    do: with_resource(conn, r, fn res -> reply(conn, Data.validate(res, params, ctx(conn, params))) end)

  def submit(conn, %{"resource" => r} = params),
    do: with_resource(conn, r, fn res -> reply(conn, Data.submit(res, params, ctx(conn, params))) end)

  def run_action(conn, %{"resource" => r} = params),
    do: with_resource(conn, r, fn res -> reply(conn, Data.run_generic(res, params, ctx(conn, params))) end)

  defp with_resource(conn, name, fun) do
    fun.(AshShadcn.resource!(name))
  rescue
    e in ArgumentError -> conn |> put_status(404) |> json(%{error: "not_found", message: e.message})
  end

  defp reply(conn, {:ok, body}), do: json(conn, body)
  defp reply(conn, {:error, :not_found}), do: conn |> put_status(404) |> json(Data.error_body(:not_found))
  defp reply(conn, {:error, e}), do: conn |> put_status(422) |> json(Data.error_body(e))

  # Cookie session actor (AshShadcn.Auth, if the auth lane is present) wins over the actor_id param.
  defp actor(conn, params) do
    session =
      if Code.ensure_loaded?(AshShadcn.Auth) and function_exported?(AshShadcn.Auth, :actor_from_conn, 1),
        do: apply(AshShadcn.Auth, :actor_from_conn, [conn])

    session || AshShadcn.load_actor(params["actor_id"])
  end

  defp ctx(conn, params) do
    [
      actor: actor(conn, params),
      tenant: blank_to_nil(params["tenant"]),
      authorize?: params["authorize"] not in ["false", false]
    ]
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v
end
