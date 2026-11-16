defmodule AshShadcn.JsonApiTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint
  @base "/admin/api/json"

  alias Playground.Blog.{Author, Post}

  setup do
    n = System.unique_integer([:positive])
    editor = Ash.create!(Author, %{name: "E", email: "e#{n}@x.io", role: :editor}, authorize?: false)
    reader = Ash.create!(Author, %{name: "R", email: "r#{n}@x.io", role: :reader}, authorize?: false)
    %{editor: editor, reader: reader}
  end

  defp req(method, path, actor \\ nil, body \\ nil) do
    conn =
      build_conn()
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
      |> then(fn c -> if actor, do: Plug.Conn.put_req_header(c, "x-actor-id", actor.id), else: c end)
      |> then(fn c -> if body, do: Plug.Conn.put_req_header(c, "content-type", "application/vnd.api+json"), else: c end)

    conn = dispatch(conn, @endpoint, method, @base <> path, body && Jason.encode!(body))
    {conn.status, if(conn.resp_body in [nil, ""], do: %{}, else: Jason.decode!(conn.resp_body))}
  end

  defp create(editor, attrs) do
    {201, %{"data" => d}} = req(:post, "/posts", editor, %{data: %{type: "post", attributes: attrs}})
    d
  end

  test "create, list, filter, sort, page, include", %{editor: editor} do
    tag = "t#{System.unique_integer([:positive])}"
    for {t, p} <- [{"Alpha #{tag}", 3}, {"Bravo #{tag}", 1}, {"Charlie #{tag}", 2}] do
      create(editor, %{title: t, points: p, author_id: editor.id})
    end

    {200, %{"data" => all}} = req(:get, "/posts?filter[title][contains]=#{tag}&sort=-points")
    assert Enum.map(all, & &1["attributes"]["points"]) == [3, 2, 1]

    {200, %{"data" => one}} = req(:get, "/posts?filter[title][contains]=#{tag}&filter[points][lte]=1")
    assert [%{"attributes" => %{"title" => "Bravo" <> _}}] = one

    {200, %{"data" => paged, "links" => links}} =
      req(:get, "/posts?filter[title][contains]=#{tag}&sort=title&page[limit]=2")
    assert length(paged) == 2
    assert is_map(links)

    {200, %{"data" => [_ | _], "included" => inc}} =
      req(:get, "/posts?filter[title][contains]=#{tag}&include=author")
    assert Enum.any?(inc, &(&1["type"] == "author" and &1["id"] == editor.id))
  end

  test "get, patch, publish, published read, delete", %{editor: editor} do
    d = create(editor, %{title: "Gamma post"})
    id = d["id"]
    {200, %{"data" => %{"id" => ^id}}} = req(:get, "/posts/#{id}")

    {200, %{"data" => %{"attributes" => %{"title" => "Gamma 2"}}}} =
      req(:patch, "/posts/#{id}", editor, %{data: %{type: "post", id: id, attributes: %{title: "Gamma 2"}}})

    {200, %{"data" => %{"attributes" => %{"status" => "published"}}}} =
      req(:patch, "/posts/#{id}/publish", editor, %{data: %{type: "post", id: id, attributes: %{}}})

    {200, %{"data" => pub}} = req(:get, "/posts/published")
    assert Enum.any?(pub, &(&1["id"] == id))

    {200, _} = req(:delete, "/posts/#{id}", editor)
    {404, _} = req(:get, "/posts/#{id}")
    assert {:error, _} = Ash.get(Post, id, authorize?: false)
  end

  test "policy-denied writes are 403", %{reader: reader} do
    assert {403, _} = req(:post, "/posts", reader, %{data: %{type: "post", attributes: %{title: "Nope!"}}})
    assert {403, _} = req(:post, "/posts", nil, %{data: %{type: "post", attributes: %{title: "Nope!"}}})
  end

  test "openapi spec contains every route and is served by the admin endpoint" do
    spec = build_conn() |> get("/admin/api/openapi") |> json_response(200)
    routes = build_conn() |> get("/admin/api/jsonapi/routes") |> json_response(200) |> Map.fetch!("routes")
    assert length(routes) >= 15

    ops =
      for {path, item} <- spec["paths"], {m, _} <- item, do: {String.upcase(m), path}

    for r <- routes do
      rel = String.replace_prefix(r["path"], "/admin/api/json", "")
      pat = Regex.replace(~r/:(\w+)/, rel, "{\\1}")
      assert Enum.any?(ops, fn {m, p} ->
               m == r["method"] and String.replace_prefix(p, "/admin/api/json", "") |> then(&(&1 == pat or &1 == rel))
             end),
             "spec lacks #{r["method"]} #{r["path"]}; has #{inspect(Enum.take(ops, 40))}"
    end
  end
end
