defmodule AshShadcnWeb.AdminController do
  @moduledoc "Renders the shadcn admin shell via phoenix_react_server (SSR) and hydrates in the browser."
  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  def index(conn, params) do
    path = "/" <> Enum.join(List.wrap(params["path"]), "/")
    props = %{"path" => path, "domains" => AshShadcn.Introspect.domains()}

    case Phoenix.React.render_to_string("admin_app", props) do
      {:ok, markup} ->
        conn |> put_resp_content_type("text/html") |> send_resp(200, document(markup, props))

      {:error, reason} ->
        conn |> put_resp_content_type("text/plain") |> send_resp(500, "React SSR failed: #{inspect(reason)}")
    end
  end

  defp document(markup, props) do
    json = props |> Jason.encode!() |> String.replace("</", "<\\/")

    """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Ash Admin</title>
    <link rel="stylesheet" href="/assets/styles.css">
    </head>
    <body>
    <div id="root">#{markup}</div>
    <script type="application/json" id="admin-props">#{json}</script>
    <script type="module" src="/assets/admin.js"></script>
    </body>
    </html>
    """
  end
end
