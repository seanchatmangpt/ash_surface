defmodule Playground.Accounts do
  @moduledoc "Lane `auth` domain: login users + tokens. Not listed in the admin domain list (config :ash_shadcn)."
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource Playground.Accounts.User
    resource Playground.Accounts.Token
  end
end
