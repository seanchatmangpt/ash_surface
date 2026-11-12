defmodule PlaygroundWeb.PageTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest

  @endpoint PlaygroundWeb.Endpoint
  @root Path.expand("..", __DIR__ |> Path.dirname())

  # Bounded deadline poll (no sleeps as coordination): the bun render server
  # boots asynchronously under Phoenix.React.
  defp get_ssr!(path, deadline_ms \\ 20_000) do
    deadline = System.monotonic_time(:millisecond) + deadline_ms
    poll(path, deadline)
  end

  defp poll(path, deadline) do
    conn = get(build_conn(), path)

    cond do
      conn.status == 200 ->
        conn

      System.monotonic_time(:millisecond) > deadline ->
        flunk("SSR not ready before deadline: #{conn.status} #{conn.resp_body}")

      true ->
        :erlang.yield()
        poll(path, deadline)
    end
  end

  test "SSR markup (react renderToString via Phoenix.React) carries the contract data" do
    body = get_ssr!("/").resp_body
    assert body =~ ~s(id="resource-list")
    assert body =~ "Todo.create"
    assert body =~ "Todo.read"
    # compiled IR contract JSON (AshSurface.IR.Codec)
    assert body =~ "ZodFixtures.Todo" or body =~ "AshSurface.ZodFixtures.Todo"
    assert body =~ "&quot;points&quot;"
    # emitted Zod source text
    assert body =~ "export const SCHEMAS"
    assert body =~ ~s(src="/assets/client.js")
    assert body =~ ~s(id="pg-props")
  end

  test "emitted artifact is served verbatim and imports zod" do
    conn = get_ssr!("/artifact.mjs")
    assert conn.resp_body =~ ~s(import { z } from "zod")
    assert conn.resp_body == Playground.Surface.snapshot().artifact
  end

  test "hydration bundle and bundled zod module are served" do
    client = get(build_conn(), "/assets/client.js")
    assert client.status == 200
    assert client.resp_body =~ "hydrat"
    zod = get(build_conn(), "/assets/zod.mjs")
    assert zod.status == 200
    assert byte_size(zod.resp_body) > 10_000
  end

  test "contract endpoint returns JSON for each compiled action" do
    for entry <- Playground.Surface.snapshot().entries do
      conn = get(build_conn(), "/contract/#{entry.id}")
      assert conn.status == 200
      assert {:ok, %{"ash" => _}} = Jason.decode(conn.resp_body)
    end

    assert get(build_conn(), "/contract/999").status == 404
  end

  test "real zod validates the emitted schema (bun test)" do
    dir = Path.join(@root, "tmp_artifact")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    path = Path.join(dir, "ash_surface_client.mjs")
    File.write!(path, Playground.Surface.snapshot().artifact)

    task =
      Task.async(fn ->
        System.cmd("bun", ["test", "assets/test/zod.test.mjs"],
          cd: @root,
          env: [{"ARTIFACT", path}],
          stderr_to_stdout: true
        )
      end)

    {out, code} =
      case Task.yield(task, 60_000) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        _ -> flunk("bun test exceeded 60s deadline")
      end

    assert code == 0, out
    assert out =~ "4 pass"
    assert out =~ "0 fail"
  end
end
