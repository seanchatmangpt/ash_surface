defmodule AshShadcnWeb.IdeController do
  @moduledoc "Studio backend: read-only source browsing + action runs with the ApiController ctx contract."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias AshShadcn.Ide.{Runner, Source}

  def tree(conn, _), do: json(conn, %{tree: Source.tree()})

  def file(conn, %{"path" => path}) do
    case Source.read(path) do
      {:ok, text} -> json(conn, %{path: path, language: "elixir", content: text})
      {:error, :forbidden} -> conn |> put_status(403) |> json(%{error: "forbidden", message: "path not allowed"})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "not_found", message: "file not found"})
    end
  end

  def file(conn, _), do: conn |> put_status(400) |> json(%{error: "bad_request", message: "path required"})

  def run(conn, %{"resource" => name, "action" => _} = params) do
    resource = AshShadcn.resource!(name)
    ctx = [
      actor: AshShadcn.load_actor(params["actor_id"]),
      tenant: blank_to_nil(params["tenant"]),
      authorize?: params["authorize"] not in ["false", false]
    ]

    json(conn, Runner.run(resource, params, ctx))
  rescue
    e in ArgumentError -> conn |> put_status(404) |> json(%{error: "not_found", message: e.message})
  end

  def run(conn, _), do: conn |> put_status(400) |> json(%{error: "bad_request", message: "resource and action required"})

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v
end
