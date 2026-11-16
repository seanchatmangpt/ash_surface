defmodule AshShadcnApiTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Blog.{Author, Post}

  setup do
    admin = Ash.create!(Author, %{name: "A", email: "a#{System.unique_integer([:positive])}@x.io", role: :admin}, authorize?: false)
    reader = Ash.create!(Author, %{name: "R", email: "r#{System.unique_integer([:positive])}@x.io", role: :reader}, authorize?: false)
    %{admin: admin, reader: reader}
  end

  defp api(path, params \\ %{}), do: build_conn() |> get("/admin/api" <> path, params) |> json_response(200)
  defp post_api(path, body), do: build_conn() |> post("/admin/api" <> path, body)

  test "introspection lists domain resources and Post actions/calculations/aggregates" do
    assert %{"domains" => domains} = api("/domains")
    rs = Enum.flat_map(domains, & &1["resources"])
    assert Enum.any?(rs, &(&1["module"] == "Playground.Blog.Post"))
    meta = api("/resources/Playground.Blog.Post")
    assert Enum.any?(meta["actions"], &(&1["name"] == "word_count" and &1["type"] == "action"))
    assert Enum.any?(meta["calculations"], &(&1["name"] == "title_length"))
    assert Enum.any?(meta["aggregates"], &(&1["name"] == "comment_count"))
    status = Enum.find(meta["attributes"], &(&1["name"] == "status"))
    assert status["constraints"]["one_of"] == ["draft", "published", "archived"]
  end

  test "create goes through AshPhoenix.Form: invalid is reported, valid persists, policy gates the actor", %{admin: admin, reader: reader} do
    base = %{"action" => "create", "params" => %{"title" => "ab"}}
    assert %{"errors" => [%{"field" => "title"} | _]} =
             post_api("/resources/Playground.Blog.Post/validate", Map.put(base, "actor_id", admin.id)) |> json_response(200)

    ok = %{"action" => "create", "params" => %{"title" => "A fine title"}}
    assert %{"record" => %{"title" => "A fine title"}, "errors" => []} =
             post_api("/resources/Playground.Blog.Post/submit", Map.put(ok, "actor_id", admin.id)) |> json_response(200)

    # a reader is forbidden by the policy; the write must not land
    before = length(Ash.read!(Post, authorize?: false))
    body = post_api("/resources/Playground.Blog.Post/submit", Map.put(%{ok | "params" => %{"title" => "Nope nope"}}, "actor_id", reader.id)) |> json_response(200)
    assert body["errors"] != []
    assert length(Ash.read!(Post, authorize?: false)) == before
  end

  test "read pagination, sort, load and filter", %{admin: admin} do
    for t <- ["bbb post", "aaa post", "ccc post"], do: Ash.create!(Post, %{title: t}, actor: admin)
    r = api("/resources/Playground.Blog.Post/records", %{"limit" => "2", "sort" => "title", "load" => "title_length,comment_count", "filter" => %{"title" => %{"contains" => "post"}}})
    assert r["count"] >= 3 and length(r["records"]) == 2
    titles = Enum.map(r["records"], & &1["title"])
    assert titles == Enum.sort(titles)
    assert hd(r["records"])["title_length"] == String.length(hd(titles))
  end

  test "generic action runs and unknown resource is a 404" do
    assert %{"result" => 3} = post_api("/resources/Playground.Blog.Post/run", %{"action" => "word_count", "params" => %{"text" => "one two three"}}) |> json_response(200)
    assert build_conn() |> get("/admin/api/resources/Nope.Nope") |> json_response(404)
  end

  test "SSR shell renders the sidebar and resource through phoenix_react_server" do
    html = build_conn() |> get("/admin/r/Playground.Blog.Post") |> html_response(200)
    assert html =~ "Ash Admin" and html =~ "Author" and html =~ "admin-props"
  end
end
