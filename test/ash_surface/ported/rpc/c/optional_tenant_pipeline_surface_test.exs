defmodule AshSurface.Ported.Rpc.C.OptionalTenantPipelineSurfaceTest do
  @moduledoc """
  Port of the reference `optional tenant - pipeline behavior` describe (2 tests): request parsing
  of the `tenant` parameter for a non-multitenant resource. The 7 generated-TypeScript tests of
  the reference stay loud skips in `optional_tenant_for_all_actions_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R

  test "tenant from params is used when provided for non-multitenancy resource" do
    params = %{"action" => "list_todos", "fields" => ["id", "title"], "tenant" => "org_123"}

    assert {:ok, request} = R.parse(params)
    assert request.tenant == "org_123"
  end

  test "tenant is nil when not provided for non-multitenancy resource" do
    params = %{"action" => "list_todos", "fields" => ["id", "title"]}

    assert {:ok, request} = R.parse(params)
    assert request.tenant == nil
  end
end
