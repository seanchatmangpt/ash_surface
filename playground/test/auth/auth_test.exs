defmodule AshShadcn.AuthTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias AshShadcn.Auth
  alias Playground.Accounts.User
  alias Playground.Blog.Post

  @pw "correct-horse-battery"
  defp email, do: "u#{System.unique_integer([:positive])}@x.io"
  defp api(conn, verb, path, body \\ %{}), do: dispatch(conn, @endpoint, verb, "/admin/api/auth" <> path, body)
  defp cookie(conn), do: conn.resp_cookies[Auth.cookie()]

  defp register(e) do
    conn = api(build_conn(), :post, "/register", %{email: e, password: @pw})
    assert %{"user" => %{"email" => ^e, "role" => "reader"}} = json_response(conn, 201)
    conn
  end

  defp with_cookie(conn_from) do
    build_conn() |> Plug.Test.put_req_cookie(Auth.cookie(), cookie(conn_from).value)
  end

  defp sign_in(e), do: api(build_conn(), :post, "/sign_in", %{email: e, password: @pw})

  defp promote(e, role) do
    user = User |> Ash.read!(authorize?: false) |> Enum.find(&(to_string(&1.email) == e))
    user |> Ash.Changeset.for_update(:set_role, %{role: role}) |> Ash.update!(authorize?: false)
  end

  test "password is stored as a real bcrypt hash" do
    e = email()
    register(e)
    user = User |> Ash.read!(authorize?: false) |> Enum.find(&(to_string(&1.email) == e))
    assert String.starts_with?(user.hashed_password, "$2b$")
    assert Bcrypt.verify_pass(@pw, user.hashed_password)
  end

  test "register -> sign in -> me -> editor create succeeds" do
    e = email()
    register(e)
    promote(e, :editor)
    conn = sign_in(e)
    assert json_response(conn, 200)["user"]["role"] == "editor"

    me = api(with_cookie(conn), :get, "/me")
    assert %{"user" => %{"email" => ^e, "role" => "editor"}} = json_response(me, 200)

    actor = Auth.actor_from_conn(with_cookie(conn))
    assert %Post{} = Ash.create!(Post, %{title: "Editor post"}, actor: actor)
  end

  test "reader is forbidden by the Blog policy" do
    e = email()
    conn = register(e)
    actor = Auth.actor_from_conn(with_cookie(conn))
    assert actor.role == :reader
    before = length(Ash.read!(Post, authorize?: false))
    assert {:error, %Ash.Error.Forbidden{}} = Ash.create(Post, %{title: "Reader post"}, actor: actor)
    assert length(Ash.read!(Post, authorize?: false)) == before
  end

  test "registration cannot self-assign a role" do
    e = email()
    conn = api(build_conn(), :post, "/register", %{email: e, password: @pw, role: "admin"})
    assert json_response(conn, 201)["user"]["role"] == "reader"
  end

  test "wrong password and unknown user rejected, no cookie" do
    e = email()
    register(e)
    bad = api(build_conn(), :post, "/sign_in", %{email: e, password: "nope-nope-nope"})
    assert json_response(bad, 401)["error"] == "unauthorized"
    assert cookie(bad) == nil
    assert json_response(api(build_conn(), :post, "/sign_in", %{email: email(), password: @pw}), 401)
  end

  test "me without cookie is 401; duplicate register is 422" do
    assert json_response(api(build_conn(), :get, "/me"), 401)
    e = email()
    register(e)
    assert json_response(api(build_conn(), :post, "/register", %{email: e, password: @pw}), 422)
  end

  test "sign out clears the cookie and revokes the token" do
    e = email()
    conn = register(e)
    session = with_cookie(conn)
    assert %User{} = Auth.actor_from_conn(session)

    out = api(session, :delete, "/sign_out")
    assert json_response(out, 200)["ok"]
    assert cookie(out).max_age == 0

    assert Auth.actor_from_conn(with_cookie(conn)) == nil
    assert json_response(api(with_cookie(conn), :get, "/me"), 401)
  end
end
