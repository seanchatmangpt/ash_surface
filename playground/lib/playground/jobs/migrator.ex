defmodule Playground.Jobs.Migrator do
  @moduledoc "Synchronously applies the Oban migration at boot, then returns :ignore (no process)."
  def child_spec(_), do: %{id: __MODULE__, start: {__MODULE__, :start_link, []}, restart: :temporary}

  def start_link do
    Ecto.Migrator.run(Playground.Repo, [{20260101000000, Playground.Jobs.ObanMigration}], :up,
      all: true,
      log: false,
      log_migrations_sql: false,
      log_migrator_sql: false
    )

    :ignore
  end
end
