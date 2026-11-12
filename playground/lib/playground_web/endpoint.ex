defmodule PlaygroundWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :playground

  plug Plug.Static, at: "/", from: {:playground, "priv/static"}, only: ~w(assets)
  plug Plug.RequestId
  plug Plug.Parsers, parsers: [:urlencoded, :json], json_decoder: Jason
  plug PlaygroundWeb.Router
end
