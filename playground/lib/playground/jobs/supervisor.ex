defmodule Playground.Jobs.Supervisor do
  @moduledoc """
  Starts Playground.Repo (SQLite), the Oban schema, and Oban (AshOban-configured).

  Add to application.ex children: `Playground.Jobs.Supervisor`
  """
  use Supervisor

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    db = Application.fetch_env!(:playground, Playground.Repo)[:database]
    File.mkdir_p!(Path.dirname(db))

    oban =
      AshOban.config([Playground.Jobs], Application.fetch_env!(:playground, Oban))

    Supervisor.init([Playground.Repo, Playground.Jobs.Migrator, {Oban, oban}], strategy: :rest_for_one)
  end
end
