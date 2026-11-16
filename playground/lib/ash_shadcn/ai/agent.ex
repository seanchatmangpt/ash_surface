defmodule AshShadcn.Ai.Agent do
  @moduledoc """
  Chat turn driver. Stream event protocol (one JSON object per SSE `data:` line):

      {type: "start"}
      {type: "reasoning",   text}
      {type: "tool-call",   id, name, args}
      {type: "tool-result", id, name, result | error}
      {type: "sources",     sources: [{title, url}]}
      {type: "text-delta",  text}
      {type: "finish",      reason}

  Uses an LLM through AshAi.ToolLoop (ReqLLM) only when ANTHROPIC_API_KEY or OPENAI_API_KEY is set,
  otherwise `AshShadcn.Ai.LocalAgent`.
  """
  alias AshShadcn.Ai.{LocalAgent, Tools}

  def provider do
    cond do
      System.get_env("ANTHROPIC_API_KEY") not in [nil, ""] -> {:llm, "anthropic:claude-sonnet-4-5"}
      System.get_env("OPENAI_API_KEY") not in [nil, ""] -> {:llm, "openai:gpt-4o-mini"}
      true -> :local
    end
  end

  def run(messages, actor, emit) do
    last = messages |> Enum.filter(&(&1["role"] == "user")) |> List.last() |> then(&((&1 || %{})["content"] || ""))

    case provider() do
      :local -> LocalAgent.run(last, actor, emit)
      {:llm, model} -> run_llm(model, messages, actor, emit)
    end
  end

  defp run_llm(model, messages, actor, emit) do
    emit.(%{type: "start"})

    on_start = fn ev ->
      emit.(%{type: "tool-call", id: ev.tool_name, name: ev.tool_name, args: ev.arguments})
    end

    on_end = fn ev ->
      case ev.result do
        {:ok, text, _} -> emit.(%{type: "tool-result", id: ev.tool_name, name: ev.tool_name, result: decode(text)})
        {:error, e} -> emit.(%{type: "tool-result", id: ev.tool_name, name: ev.tool_name, error: inspect(e)})
        _ -> :ok
      end
    end

    ctx = Enum.map(messages, fn %{"role" => r, "content" => c} -> (if r == "assistant", do: ReqLLM.Context.assistant(c), else: ReqLLM.Context.user(c)) end)

    case AshAi.ToolLoop.run(ctx,
           otp_app: :playground,
           actor: actor,
           model: model,
           on_tool_start: on_start,
           on_tool_end: on_end,
           system_prompt: fn _ -> "You operate a blog admin through tools. Be concise." end
         ) do
      {:ok, %{final_text: text}} -> LocalAgent.stream_text(text, emit)
      {:error, e} -> LocalAgent.stream_text("LLM error: #{inspect(e)}", emit)
    end

    emit.(%{type: "finish", reason: "stop"})
  end

  defp decode(t) do
    case Jason.decode(t) do
      {:ok, v} -> v
      _ -> t
    end
  end

  # keep the compiler honest about the alias used only for docs/tests
  def tools_for(actor), do: Tools.for_actor(actor)
end
