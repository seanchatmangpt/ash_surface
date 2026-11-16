defmodule Playground.Accounts.Token do
  use Ash.Resource,
    domain: Playground.Accounts,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication.TokenResource],
    authorizers: [Ash.Policy.Authorizer]

  ets do
    private? false
  end

  token do
    domain Playground.Accounts
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy always() do
      forbid_if always()
    end
  end
end
