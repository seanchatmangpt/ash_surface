defmodule Playground.Repo do
  @moduledoc "SQLite repo backing Oban (lane jobs). Database file: tmp/ (see config.exs `# lane:jobs`)."
  use Ecto.Repo, otp_app: :playground, adapter: Ecto.Adapters.SQLite3
end
