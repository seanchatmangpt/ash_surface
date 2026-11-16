defmodule AshShadcnWeb.AiController do
  @moduledoc "POST /admin/api/ai/chat — streams a conversation turn as SSE (see AshShadcn.Ai.Agent)."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  def info(conn, _), do: json(conn, %{provider: provider_name(), tools: Enum.map(AshShadcn.Ai.Tools.definitions(), &to_string(&1.name))})

  def chat(conn, params) do
    actor = AshShadcn.load_actor(params["actor_id"])
    messages = normalize(params["messages"])

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> send_chunked(200)

    # the adapter state travels on the conn returned by chunk/2, so thread it through the emitter
    ref = make_ref()
    Process.put(ref, conn)

    emit = fn ev ->
      case chunk(Process.get(ref), "data: " <> Jason.encode!(ev) <> "\n\n") do
        {:ok, c} -> Process.put(ref, c) && :ok
        {:error, _} -> :closed
      end
    end

    AshShadcn.Ai.Agent.run(messages, actor, emit)
    Process.delete(ref) |> Kernel.||(conn)
  end

  defp normalize(ms) when is_list(ms), do: Enum.filter(ms, &(is_map(&1) and is_binary(&1["content"])))
  defp normalize(_), do: []

  defp provider_name do
    case AshShadcn.Ai.Agent.provider() do
      :local -> "local"
      {:llm, m} -> m
    end
  end
end
