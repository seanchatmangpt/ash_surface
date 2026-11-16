defmodule AshShadcn.AiChatTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Blog.{Author, Post}

  setup do
    System.delete_env("ANTHROPIC_API_KEY")
    System.delete_env("OPENAI_API_KEY")
    mk = fn role -> Ash.create!(Author, %{name: "#{role}", email: "#{role}#{System.unique_integer([:positive])}@x.io", role: role}, authorize?: false) end
    %{admin: mk.(:admin), reader: mk.(:reader), editor: mk.(:editor)}
  end

  defp chat(text, actor) do
    conn = post(build_conn(), "/admin/api/ai/chat", %{"actor_id" => actor.id, "messages" => [%{"role" => "user", "content" => text}]})
    assert conn.status == 200
    assert ["text/event-stream" <> _] = Plug.Conn.get_resp_header(conn, "content-type")

    events =
      conn.resp_body
      |> String.split("\n\n", trim: true)
      |> Enum.map(fn "data: " <> j -> Jason.decode!(j) end)

    {events, conn.resp_body}
  end

  test "list posts streams tool-call, tool-result from real ETS data, text and finish", %{admin: admin} do
    p = Ash.create!(Post, %{title: "Streamed #{System.unique_integer([:positive])}"}, actor: admin)
    {events, _} = chat("list posts", admin)
    types = Enum.map(events, & &1["type"])
    assert hd(types) == "start" and List.last(types) == "finish"
    assert "reasoning" in types and "sources" in types
    assert %{"name" => "list_posts"} = Enum.find(events, &(&1["type"] == "tool-call"))
    res = Enum.find(events, &(&1["type"] == "tool-result"))
    assert Enum.any?(res["result"], &(&1["id"] == p.id))
    text = events |> Enum.filter(&(&1["type"] == "text-delta")) |> Enum.map_join(& &1["text"])
    assert text =~ p.title
  end

  test "create post as editor lands in ETS; reader is denied by policy and nothing lands", %{editor: editor, reader: reader} do
    title = "Made by agent #{System.unique_integer([:positive])}"
    {events, _} = chat("create post titled #{title}", editor)
    assert %{"result" => %{"title" => ^title}} = Enum.find(events, &(&1["type"] == "tool-result"))
    assert Enum.any?(Ash.read!(Post, authorize?: false), &(&1.title == title))

    denied = "Denied #{System.unique_integer([:positive])}"
    {events, _} = chat("create post titled #{denied}", reader)
    assert %{"error" => err} = Enum.find(events, &(&1["type"] == "tool-result"))
    assert is_binary(err)
    refute Enum.any?(Ash.read!(Post, authorize?: false), &(&1.title == denied))
    assert List.last(events)["type"] == "finish"
  end

  test "count comments runs the aggregate tool", %{admin: admin} do
    {events, _} = chat("count comments", admin)
    assert %{"error" => nil} = Map.merge(%{"error" => nil}, Enum.find(events, &(&1["type"] == "tool-result")))
  end
end
