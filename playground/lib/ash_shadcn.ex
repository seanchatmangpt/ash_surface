defmodule AshShadcn do
  @moduledoc """
  shadcn/ui admin for Ash (ash_admin parity, React-rendered via phoenix_react_server).

  Configure the browsable domains:

      config :playground, :ash_shadcn, domains: [Playground.Blog]
  """

  def domains, do: Keyword.get(Application.get_env(:playground, :ash_shadcn, []), :domains, [])

  def resource!(name) when is_binary(name) do
    Enum.find(all_resources(), &(inspect(&1) == name)) ||
      raise ArgumentError, "unknown resource #{inspect(name)}"
  end

  def all_resources, do: Enum.flat_map(domains(), &Ash.Domain.Info.resources/1)

  @doc "Resource whose records can be selected as the acting actor (config `:actor_resource`)."
  def actor_resource, do: Keyword.get(Application.get_env(:playground, :ash_shadcn, []), :actor_resource)

  def load_actor(nil), do: nil
  def load_actor(""), do: nil

  def load_actor(id) do
    with res when not is_nil(res) <- actor_resource(),
         {:ok, actor} <- Ash.get(res, id, authorize?: false) do
      actor
    else
      _ -> nil
    end
  end
end
