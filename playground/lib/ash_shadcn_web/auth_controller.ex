defmodule AshShadcnWeb.AuthController do
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias AshShadcn.Auth
  alias Playground.Accounts.User

  def register(conn, params) do
    attrs = %{
      "email" => params["email"],
      "password" => params["password"],
      "password_confirmation" => params["password_confirmation"] || params["password"]
    }

    case AshAuthentication.Strategy.action(strategy(), :register, attrs) do
      {:ok, user} -> conn |> put_session_cookie(user) |> put_status(201) |> json(%{user: user_json(user)})
      {:error, e} -> conn |> put_status(422) |> json(%{error: "invalid", message: Exception.message(e)})
    end
  end

  def sign_in(conn, params) do
    creds = %{"email" => params["email"], "password" => params["password"]}

    case AshAuthentication.Strategy.action(strategy(), :sign_in, creds) do
      {:ok, %User{} = user} -> conn |> put_session_cookie(user) |> json(%{user: user_json(user)})
      _ -> conn |> put_status(401) |> json(%{error: "unauthorized", message: "Invalid email or password"})
    end
  end

  def sign_out(conn, _) do
    Auth.revoke(Auth.token_from_conn(conn))
    conn |> delete_resp_cookie(Auth.cookie()) |> json(%{ok: true})
  end

  def me(conn, _) do
    case Auth.actor_from_conn(conn) do
      nil -> conn |> put_status(401) |> json(%{error: "unauthorized", user: nil})
      user -> json(conn, %{user: user_json(user)})
    end
  end

  defp strategy, do: AshAuthentication.Info.strategy!(User, :password)

  defp put_session_cookie(conn, user) do
    token = user.__metadata__.token

    put_resp_cookie(conn, Auth.cookie(), token,
      sign: true,
      http_only: true,
      same_site: "Lax",
      max_age: 14 * 86_400
    )
  end

  defp user_json(u), do: %{id: u.id, email: to_string(u.email), role: u.role}
end
