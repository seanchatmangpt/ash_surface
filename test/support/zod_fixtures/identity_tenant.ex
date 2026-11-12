defmodule AshSurface.ZodFixtures.IdentityTenant.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.IdentityTenant.Account)
    resource(AshSurface.ZodFixtures.IdentityTenant.Membership)
    resource(AshSurface.ZodFixtures.IdentityTenant.TenantNote)
  end
end

defmodule AshSurface.ZodFixtures.IdentityTenant.Account do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.IdentityTenant.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:email, :string, public?: true, allow_nil?: false)
    attribute(:org, :string, public?: true, allow_nil?: false)
    attribute(:handle, :string, public?: true, allow_nil?: false)
  end

  identities do
    identity(:unique_email, [:email], pre_check_with: AshSurface.ZodFixtures.IdentityTenant.Domain)
    identity(:org_handle, [:org, :handle],
      pre_check_with: AshSurface.ZodFixtures.IdentityTenant.Domain
    )
  end

  actions do
    defaults([:read, create: [:email, :org, :handle]])

    read :get_by_email do
      get_by([:email])
    end

    read :get_one do
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      filter(expr(id == ^arg(:id)))
    end
  end
end

defmodule AshSurface.ZodFixtures.IdentityTenant.Membership do
  @moduledoc "Composite primary key."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.IdentityTenant.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    attribute(:user_id, :uuid, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:group_id, :uuid, primary_key?: true, allow_nil?: false, public?: true)
    attribute(:role, :string, public?: true)
  end

  actions do
    defaults([:read, create: [:user_id, :group_id, :role]])
  end
end

defmodule AshSurface.ZodFixtures.IdentityTenant.TenantNote do
  @moduledoc "Attribute-multitenant resource."
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.IdentityTenant.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:tenant_id)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:tenant_id, :string, public?: true, allow_nil?: false)
    attribute(:text, :string, public?: true)
  end

  actions do
    defaults([:read, create: [:text]])
  end
end
