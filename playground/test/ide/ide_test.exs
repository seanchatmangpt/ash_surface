defmodule AshShadcn.IdeTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Blog.{Author, Post}
  alias AshShadcn.Ide.Source

  setup do
    n = System.unique_integer([:positive])
    admin = Ash.create!(Author, %{name: "A", email: "ide-a#{n}@x.io", role: :admin}, authorize?: false)
    reader = Ash.create!(Author, %{name: "R", email: "ide-r#{n}@x.io", role: :reader}, authorize?: false)
    %{admin: admin, reader: reader}
  end

  defp tree, do: build_conn() |> get("/admin/api/ide/tree") |> json_response(200) |> Map.fetch!("tree")
  defp files(t), do: Enum.flat_map(t, & &1["children"])
  defp run(body), do: build_conn() |> post("/admin/api/ide/run", body) |> json_response(200)

  test "tree lists the domain and resource source files" do
    paths = tree() |> files() |> Enum.map(& &1["path"])
    assert "playground/blog/post.ex" in paths
    assert "playground/blog.ex" in paths
  end

  test "file returns real source of an allow-listed path" do
    r = build_conn() |> get("/admin/api/ide/file", %{"path" => "playground/blog/post.ex"}) |> json_response(200)
    assert r["content"] =~ "defmodule Playground.Blog.Post"
  end

  test "file refuses traversal, absolute, unlisted paths" do
    for p <- ["../../mix.exs", "/etc/hosts", Path.expand("mix.exs"), "playground/blog/../../../mix.exs", "playground/application.ex", "playground/blog/post.ex\0"] do
      conn = build_conn() |> get("/admin/api/ide/file", %{"path" => p})
      assert conn.status == 403, "expected 403 for #{inspect(p)}"
    end

    assert (build_conn() |> get("/admin/api/ide/file")).status == 400
  end

  test "Source.read refuses a symlink that escapes root even when allow-listed" do
    root = Path.join(System.tmp_dir!(), "ide_root_#{System.unique_integer([:positive])}")
    outside = Path.join(System.tmp_dir!(), "ide_out_#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    File.mkdir_p!(outside)
    File.write!(Path.join(outside, "secret.txt"), "secret")
    File.write!(Path.join(root, "ok.ex"), "ok")
    File.ln_s!(Path.join(outside, "secret.txt"), Path.join(root, "link.ex"))
    File.ln_s!(outside, Path.join(root, "dir"))
    on_exit(fn -> File.rm_rf!(root); File.rm_rf!(outside) end)

    allowed = ["ok.ex", "link.ex", "dir/secret.txt"]
    assert {:ok, "ok"} = Source.read("ok.ex", root: root, allowed: allowed)
    assert {:error, :forbidden} = Source.read("link.ex", root: root, allowed: allowed)
    assert {:error, :forbidden} = Source.read("dir/secret.txt", root: root, allowed: allowed)
  end

  test "run create returns transcript and persists; policy denies reader", %{admin: admin, reader: reader} do
    ok = run(%{"resource" => "Playground.Blog.Post", "action" => "create", "params" => %{"title" => "Studio post"}, "actor_id" => admin.id})
    assert ok["status"] == "ok"
    assert ok["command"] == ~s|Post.create(title: "Studio post")|
    assert is_integer(ok["duration_ms"])
    assert ok["result"]["title"] == "Studio post"

    before = length(Ash.read!(Post, authorize?: false))
    denied = run(%{"resource" => "Playground.Blog.Post", "action" => "create", "params" => %{"title" => "Nope nope"}, "actor_id" => reader.id})
    assert denied["status"] == "error"
    assert denied["lines"] != []
    assert length(Ash.read!(Post, authorize?: false)) == before
  end

  test "run read and unknown action/resource", %{admin: admin} do
    r = run(%{"resource" => "Playground.Blog.Post", "action" => "read", "actor_id" => admin.id})
    assert r["status"] == "ok" and is_list(r["result"])
    assert run(%{"resource" => "Playground.Blog.Post", "action" => "nope"})["status"] == "error"
    assert (build_conn() |> post("/admin/api/ide/run", %{"resource" => "Nope", "action" => "x"})).status == 404
  end
end
