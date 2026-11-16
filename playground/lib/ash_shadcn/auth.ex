defmodule AshShadcn.Auth do
  @moduledoc """
  Cookie-session auth for the admin JSON API. The cookie holds a signed AshAuthentication JWT
  (revocable via the token resource). `actor_from_conn/1` is independent of ApiController.
  """
  alias Playground.Accounts.{Token, User}

  @cookie "ash_admin_session"
  def cookie, do: @cookie

  @doc "The signed-in User for this conn, or nil."
  def actor_from_conn(conn) do
    with token when is_binary(token) <- token_from_conn(conn),
         {:ok, %{"sub" => sub}, User} <- AshAuthentication.Jwt.verify(token, :playground),
         {:ok, user} <- AshAuthentication.subject_to_user(sub, User, authorize?: false) do
      user
    else
      _ -> nil
    end
  end

  def token_from_conn(conn) do
    conn
    |> ensure_secret()
    |> Plug.Conn.fetch_cookies(signed: [@cookie])
    |> Map.fetch!(:cookies)
    |> Map.get(@cookie)
  end

  # Conns that did not pass through the endpoint carry no secret_key_base; fall back to its config.
  defp ensure_secret(%{secret_key_base: nil} = conn),
    do: %{conn | secret_key_base: PlaygroundWeb.Endpoint.config(:secret_key_base)}

  defp ensure_secret(conn), do: conn

  def revoke(token) when is_binary(token), do: AshAuthentication.TokenResource.Actions.revoke(Token, token, [])
  def revoke(_), do: :ok
end
