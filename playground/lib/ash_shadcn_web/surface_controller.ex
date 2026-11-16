defmodule AshShadcnWeb.SurfaceController do
  @moduledoc "Serves the compiled AshSurface projection of the admin domains."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias AshShadcn.Surface.Compiler

  def artifact(conn, _) do
    case Compiler.snapshot() do
      {:ok, %{artifact: text}} ->
        conn |> put_resp_content_type("text/javascript") |> send_resp(200, text)

      {:error, err} ->
        conn |> put_status(500) |> json(err)
    end
  end

  def resource(conn, %{"resource" => name}) do
    case Compiler.entries_for(name) do
      {:ok, %{entries: [], failures: []}} ->
        conn |> put_status(404) |> json(%{error: "not_found", message: "no surface entries for #{name}"})

      {:ok, body} ->
        json(conn, body)

      {:error, err} ->
        conn |> put_status(500) |> json(err)
    end
  end
end
