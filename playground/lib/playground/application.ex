defmodule Playground.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Playground.PubSub},
      # React SSR render server (bun runtime, bundle at priv/react/server.js).
      Phoenix.React,
      Playground.Jobs.Supervisor,
      PlaygroundWeb.Endpoint
    ]

    with {:ok, sup} <- Supervisor.start_link(children, strategy: :one_for_one, name: Playground.Supervisor) do
      if Application.get_env(:playground, :seed, false), do: Playground.Seed.run()
      {:ok, sup}
    end
  end
end
