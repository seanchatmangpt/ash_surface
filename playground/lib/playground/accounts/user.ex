defmodule Playground.Accounts.User do
  @moduledoc "Login identity. Carries `role` so the Blog `actor_attribute_equals(:role, ..)` policies accept it."
  use Ash.Resource,
    domain: Playground.Accounts,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true
    attribute :role, :atom, constraints: [one_of: [:admin, :editor, :reader]], default: :reader, allow_nil?: false, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, :email, pre_check_with: Playground.Accounts
  end

  authentication do
    tokens do
      enabled? true
      token_resource Playground.Accounts.Token
      signing_secret Playground.Accounts.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        registration_enabled? true
        sign_in_tokens_enabled? false
      end
    end
  end

  actions do
    defaults [:read]

    # Role is never accepted from registration input (privilege escalation); admins use :set_role.
    update :set_role do
      require_atomic? false
      accept [:role]
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end

    policy action(:set_role) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end
end
