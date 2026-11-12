defmodule Playground.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Playground.PubSub},
      # React SSR render server (bun runtime, bundle at priv/react/server.js).
      Phoenix.React,
      PlaygroundWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Playground.Supervisor)
  end
end
