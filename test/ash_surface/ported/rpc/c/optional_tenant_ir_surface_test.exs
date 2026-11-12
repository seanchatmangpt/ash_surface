defmodule AshSurface.Ported.Rpc.C.OptionalTenantIrSurfaceTest do
  @moduledoc """
  Adaptation of the reference optional_tenant_for_all_actions tests 001-006 that asserted
  generated TypeScript text (`tenant?: string` in the read/get/create/update config and the
  conditional `...(config.tenant !== undefined && { tenant })` payload spread).

  ash_surface emits no `.ts`. The behavior is: on a resource without multitenancy every action
  kind accepts an optional `tenant` parameter (never required), and the parameter reaches the
  action request only when the caller supplied it. Asserted on the real non-actuating RPC
  pipeline for read, get, create, update and destroy, plus the compiled IR (no tenant parameter
  is declared as required for a non-multitenant resource).

  Test 007 (channel function text) stays a loud skip in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Tsa10}
  alias AshSurface.Ported, as: P

  @comment_input %{"content" => "c", "userId" => "u", "todoId" => "t"}

  # {label, params without tenant}
  @actions [
    read: %{"action" => "list_todos", "fields" => ["id", "title"]},
    get: %{"action" => "get_todo", "fields" => ["id"], "input" => %{"id" => "t"}},
    create: %{
      "action" => "create_todo_comment",
      "fields" => ["id"],
      "input" => @comment_input
    },
    update: %{
      "action" => "update_todo_comment",
      "fields" => ["id"],
      "identity" => "c1",
      "input" => %{"content" => "new"}
    }
  ]

  defp tenant_state(params) do
    {:ok, with_tenant} = Rpc.parse(Map.put(params, "tenant", "org_123"))
    {:ok, without} = Rpc.parse(params)
    {with_tenant.tenant, without.tenant}
  end

  test "001 read action on non-multitenancy resource has optional tenant in config" do
    assert tenant_state(@actions[:read]) == {"org_123", nil}
  end

  test "002 get action on non-multitenancy resource has optional tenant in function signature" do
    assert tenant_state(@actions[:get]) == {"org_123", nil}
  end

  test "003 create action on non-multitenancy resource has optional tenant" do
    assert tenant_state(@actions[:create]) == {"org_123", nil}
  end

  test "004 update action on non-multitenancy resource has optional tenant" do
    assert tenant_state(@actions[:update]) == {"org_123", nil}
  end

  test "005 read action function includes conditional tenant in payload" do
    # the tenant reaches the request only when provided; omitted, the request has no tenant
    {:ok, given} = Rpc.parse(Map.put(@actions[:read], "tenant", "org_a"))
    {:ok, omitted} = Rpc.parse(@actions[:read])
    assert given.tenant == "org_a"
    assert omitted.tenant == nil
  end

  test "006 create action function includes conditional tenant in payload" do
    {:ok, given} = Rpc.parse(Map.put(@actions[:create], "tenant", "org_a"))
    {:ok, omitted} = Rpc.parse(@actions[:create])
    assert given.tenant == "org_a"
    assert omitted.tenant == nil
    # the tenant does not leak into the action input
    assert given.input == omitted.input
  end

  test "destroy accepts an optional tenant too (all action kinds)" do
    params = %{"action" => "destroy_todo", "identity" => "t1"}
    assert tenant_state(params) == {"org_123", nil}
  end

  test "IR: a non-multitenant resource declares no required tenant parameter" do
    irs =
      Tsa10.irs([
        {P.TodoComment, :read},
        {P.TodoComment, :create},
        {P.TodoComment, :update},
        {P.TodoComment, :destroy}
      ])

    for ir <- irs do
      assert ir.schema.tenant == nil
      assert ir.schema.facts["multitenancy"]["strategy"] == nil
      refute ir.schema.zod =~ "tenant"
    end
  end
end
