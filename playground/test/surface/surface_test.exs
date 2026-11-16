defmodule AshShadcn.SurfaceTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  @post "Playground.Blog.Post"

  defp api(path), do: build_conn() |> get("/admin/api" <> path)

  test "resource entries include Post.create with contract, digest and zod source" do
    body = api("/surface/resources/#{@post}") |> json_response(200)
    ids = Enum.map(body["entries"], & &1["id"])
    assert "Post.create" in ids and "Post.update" in ids

    create = Enum.find(body["entries"], &(&1["id"] == "Post.create"))
    assert create["type"] == "create"
    assert create["action"] == "create"
    assert is_binary(create["digest"]) and create["digest"] != ""
    assert is_map(create["contract"]) and map_size(create["contract"]) > 0
    assert create["zod"]["input"] =~ "export const Post_create_schema"
    assert create["zod"]["input"] =~ "title: z.string().min(3)"
    assert create["zod"]["response"] =~ "Post_create_response_schema"
  end

  test "unknown resource is a typed 404" do
    assert %{"error" => "not_found"} = api("/surface/resources/Nope.Missing") |> json_response(404)
  end

  test "artifact.mjs serves the emitted module text" do
    conn = api("/surface/artifact.mjs")
    assert conn.status == 200
    assert [ct | _] = Plug.Conn.get_resp_header(conn, "content-type")
    assert ct =~ "javascript"
    assert conn.resp_body =~ "export const SCHEMAS"
    assert conn.resp_body =~ ~s("Post.create": Post_create_schema)
  end

  test "bun: emitted schema under real zod accepts/rejects and matches Ash /validate" do
    dir = Path.expand("tmp_#{System.unique_integer([:positive])}", __DIR__)
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    artifact = Path.join(dir, "artifact.mjs")
    File.write!(artifact, api("/surface/artifact.mjs").resp_body)

    payloads = [%{"title" => "ab"}, %{"title" => "abc"}, %{"title" => "abcd", "points" => -1}]

    parity =
      for p <- payloads do
        body =
          build_conn()
          |> post("/admin/api/resources/#{@post}/validate", %{"action" => "create", "params" => p, "authorize" => "false"})
          |> json_response(200)

        %{
          payload: p,
          ashValid: body["valid"],
          ashFields: body["errors"] |> Enum.map(& &1["field"]) |> Enum.uniq()
        }
      end

    # the lane requirement: Ash itself rejects title "ab"
    assert [%{ashValid: false, ashFields: ["title"]}, %{ashValid: true}, %{ashValid: false}] = parity

    parity_file = Path.join(dir, "parity.json")
    File.write!(parity_file, Jason.encode!(parity))

    {out, code} =
      System.cmd("bun", ["test", "assets/admin/surface/validator.test.mjs"],
        env: [{"SURFACE_ARTIFACT", artifact}, {"SURFACE_PARITY", parity_file}],
        stderr_to_stdout: true
      )

    assert code == 0, out
    IO.puts(out)
  end
end
