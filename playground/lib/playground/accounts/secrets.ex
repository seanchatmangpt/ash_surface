defmodule Playground.Accounts.Secrets do
  @moduledoc "Dev-only JWT signing secret (config :playground, :token_signing_secret)."
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Playground.Accounts.User, _opts, _ctx) do
    case Application.fetch_env(:playground, :token_signing_secret) do
      {:ok, secret} -> {:ok, secret}
      :error -> :error
    end
  end
end
