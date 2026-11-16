defmodule AshShadcn.Ai.LocalAgent do
  @moduledoc """
  Deterministic, real (non-mock) agent used when no LLM API key is configured. It parses simple
  intents, executes the matching AshAi tool through `AshShadcn.Ai.Tools`, and emits protocol events
  via `emit.(event)`.

  Intents: `list posts|comments|authors`, `count posts|comments|authors`,
  `create post titled X`, `publish post <id>`.
  """
  alias AshShadcn.Ai.Tools

  def plan(text) do
    t = String.trim(text)
    low = String.downcase(t)

    cond do
      m = Regex.run(~r/create (?:a )?post (?:titled|called|named)\s+["']?(.+?)["']?\s*$/i, t) ->
        {:tool, "create_post", %{"input" => %{"title" => Enum.at(m, 1)}}, "Create a post with the given title."}

      m = Regex.run(~r/publish (?:the )?post\s+(\S+)/i, t) ->
        {:tool, "publish_post", %{"id" => Enum.at(m, 1)}, "Publish the post by id."}

      m = Regex.run(~r/count\s+(posts|comments|authors)/, low) ->
        {:tool, "list_#{Enum.at(m, 1)}", %{"result_type" => "count"}, "Count #{Enum.at(m, 1)}."}

      m = Regex.run(~r/list\s+(?:all\s+)?(posts|comments|authors)/, low) ->
        {:tool, "list_#{Enum.at(m, 1)}", %{"limit" => 25}, "List #{Enum.at(m, 1)}."}

      true ->
        :help
    end
  end

  def run(text, actor, emit) do
    emit.(%{type: "start"})

    case plan(text) do
      {:tool, name, args, why} ->
        emit.(%{type: "reasoning", text: "Intent matched: #{why} Calling tool `#{name}`."})
        id = "call_" <> Integer.to_string(System.unique_integer([:positive]))
        emit.(%{type: "tool-call", id: id, name: name, args: args})

        case Tools.run(name, args, actor) do
          {:ok, result} ->
            emit.(%{type: "tool-result", id: id, name: name, result: result})
            sources(name, result) |> then(&if(&1 != [], do: emit.(%{type: "sources", sources: &1})))
            stream_text(summary(name, args, result), emit)

          {:error, msg} ->
            emit.(%{type: "tool-result", id: id, name: name, error: msg})
            stream_text("The `#{name}` tool failed: #{msg}", emit)
        end

      :help ->
        stream_text(
          "I can `list posts`, `count comments`, `create post titled <title>` or `publish post <id>`.",
          emit
        )
    end

    emit.(%{type: "finish", reason: "stop"})
    :ok
  end

  def stream_text(text, emit) do
    text |> String.split(~r/(?<=\s)/, trim: true) |> Enum.each(&emit.(%{type: "text-delta", text: &1}))
  end

  defp sources("list_posts", rows) when is_list(rows) and rows != [],
    do: [%{title: "Playground.Blog.Post records", url: "/admin/api/resources/Playground.Blog.Post/records"}]

  defp sources("list_comments", rows) when is_list(rows) and rows != [],
    do: [%{title: "Playground.Blog.Comment records", url: "/admin/api/resources/Playground.Blog.Comment/records"}]

  defp sources(_, _), do: []

  defp summary(_n, %{"result_type" => "count"}, %{"count" => c}), do: "There are #{c}."
  defp summary(n, %{"result_type" => "count"}, c) when is_integer(c), do: "There are #{c} (#{n})."

  defp summary("list_posts", _, rows) when is_list(rows) do
    "Found #{length(rows)} post(s):\n" <> Enum.map_join(rows, "\n", &"- #{&1["title"]} (#{&1["status"]})")
  end

  defp summary("list_" <> what, _, rows) when is_list(rows), do: "Found #{length(rows)} #{what}."
  defp summary("create_post", _, %{"title" => t}), do: "Created post \"#{t}\"."
  defp summary("publish_post", _, %{"title" => t}), do: "Published post \"#{t}\"."
  defp summary(n, _, r), do: "#{n} returned #{inspect(r)}"
end
