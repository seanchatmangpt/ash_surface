defmodule PlaygroundWeb.PageController do
  @moduledoc """
  Serves the compile-and-validate playground. SSR goes through
  `Phoenix.React.render_to_string/2` (renderToString, hydratable); the browser
  hydrates with `/assets/client.js` using the same props embedded as JSON.
  """
  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  alias Playground.Surface

  def index(conn, _params) do
    snap = Surface.snapshot()

    props = %{
      "entries" => Enum.map(snap.entries, &Map.take(&1, [:id, :resource, :action, :action_type, :actionId, :digest])),
      "selectedId" => 0,
      "contract" => hd(snap.entries).contract,
      "artifact" => snap.artifact,
      "initialPayload" => ~s({"title": "Ship it", "points": 150})
    }

    case Phoenix.React.render_to_string("surface_playground", props) do
      {:ok, markup} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, document(markup, props))

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "React SSR failed: #{inspect(reason)}")
    end
  end

  def artifact(conn, _params) do
    conn
    |> put_resp_content_type("text/javascript")
    |> send_resp(200, Surface.snapshot().artifact)
  end

  def contract(conn, %{"id" => id}) do
    entry = Enum.find(Surface.snapshot().entries, &(to_string(&1.id) == id))

    if entry do
      conn |> put_resp_content_type("application/json") |> send_resp(200, entry.contract)
    else
      send_resp(conn, 404, "unknown contract")
    end
  end

  defp document(markup, props) do
    json = props |> Jason.encode!() |> String.replace("</", "<\\/")

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>AshSurface playground</title>
    <style>
    body{font-family:system-ui,sans-serif;margin:1rem 2rem;max-width:90rem}
    pre{background:#f4f4f6;padding:.6rem;overflow:auto;max-height:22rem;font-size:12px}
    textarea{width:100%;height:11rem;font-family:ui-monospace,monospace}
    .grid{display:grid;grid-template-columns:1fr 1fr;gap:1rem}
    li.sel{font-weight:bold}.err{color:#b00020}.ok{color:#0a7d32}
    </style>
    </head>
    <body>
    <div id="root">#{markup}</div>
    <script type="application/json" id="pg-props">#{json}</script>
    <script type="module" src="/assets/client.js"></script>
    </body>
    </html>
    """
  end
end
