defmodule AshSurface.Fixtures.IdentityTenantFixtureTest do
  use ExUnit.Case, async: true
  alias AshSurface.ZodFixtures.IdentityTenant, as: T

  test "single and composite identities" do
    ids = Ash.Resource.Info.identities(T.Account) |> Map.new(&{&1.name, &1.keys})
    assert ids == %{unique_email: [:email], org_handle: [:org, :handle]}
  end

  test "composite primary key" do
    assert Ash.Resource.Info.primary_key(T.Membership) == [:user_id, :group_id]
  end

  test "attribute multitenancy" do
    assert Ash.Resource.Info.multitenancy_strategy(T.TenantNote) == :attribute
    assert Ash.Resource.Info.multitenancy_attribute(T.TenantNote) == :tenant_id
  end

  test "get? and get_by actions" do
    assert Ash.Resource.Info.action(T.Account, :get_one).get?
    assert Ash.Resource.Info.action(T.Account, :get_by_email).get_by == [:email]
  end
end
