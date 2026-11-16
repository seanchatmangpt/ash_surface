defmodule AshShadcn.Ai.Tools do
  @moduledoc "AshAi tool access for the chat agent. Every call runs through Ash policies with the request actor."

  @otp_app :playground

  @doc "AshAi tool definitions (with domain/action resolved) for every configured domain."
  def definitions do
    for domain <- Application.get_env(@otp_app, :ash_domains) || [],
        tool <- AshAi.Info.tools(domain) do
      %{tool | domain: domain, action: Ash.Resource.Info.action(tool.resource, tool.action)}
    end
  end

  def definition(name), do: Enum.find(definitions(), &(to_string(&1.name) == to_string(name)))

  @doc "ReqLLM tools + registry the actor is allowed to use (AshAi filters by `can?`)."
  def for_actor(actor), do: AshAi.build_tools_and_registry(otp_app: @otp_app, actor: actor)

  @doc """
  Execute one tool as `actor`. Returns `{:ok, decoded_result}` or `{:error, message}`.
  Authorization failures surface here as real Ash policy errors.
  """
  def run(name, args, actor) do
    case definition(name) do
      nil ->
        {:error, "unknown tool #{name}"}

      tool ->
        case AshAi.Tools.execute(tool, args, %{actor: actor}) do
          {:ok, text, _raw} -> {:ok, unwrap(decode(text))}
          {:error, e} -> {:error, error_text(e)}
        end
    end
  end

  # keyset-paginated reads come back as %{"results" => rows, ...}; the agent works with the rows
  defp unwrap(%{"results" => rows}) when is_list(rows), do: rows
  defp unwrap(other), do: other

  defp decode(text) when is_binary(text) do
    case Jason.decode(text) do
      {:ok, v} -> v
      _ -> text
    end
  end

  defp decode(other), do: other

  defp error_text(e) when is_binary(e), do: e
  defp error_text(e), do: inspect(e)
end
