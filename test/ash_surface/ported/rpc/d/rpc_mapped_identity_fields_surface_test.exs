defmodule AshSurface.Ported.Rpc.D.RpcMappedIdentityFieldsSurfaceTest do
  @moduledoc """
  Surface port of the runtime half of `rpc_mapped_identity_fields_test.exs`: the identity map is
  resolved (`Pipeline.resolve_identity/1`) with `field_names` mappings applied (`isActive` -> `is_active?`). The action result is a
  caller-built `Subscription` struct (no data layer). TypeScript-text codegen tests are not
  portable (README: no generated `.ts`); their facts live in `rpc_mapped_identity_fields_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Subscription}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  @user_id "33333333-3333-3333-3333-333333333333"
  @sub_id "44444444-4444-4444-4444-444444444444"

  test "update by identity with mapped field names" do
    subscription = struct(Subscription, id: @sub_id, user_id: @user_id, plan: "enterprise")

    params = %{
      "action" => "update_subscription_by_user_status",
      "identity" => %{"userId" => @user_id, "isActive" => true},
      "input" => %{"plan" => "enterprise"},
      "fields" => ["id", "plan"]
    }

    assert {:ok, request} = Rpc.parse(params)
    assert {:ok, [user_id: @user_id, is_active?: true]} = Pipeline.resolve_identity(request)

    assert %{"success" => true, "data" => data} = Rpc.run(params, subscription)
    assert data["id"] == @sub_id
    assert data["plan"] == "enterprise"
  end

  test "destroy by identity with mapped field names" do
    params = %{
      "action" => "destroy_subscription_by_user_status",
      "identity" => %{"userId" => @user_id, "isActive" => false}
    }

    assert {:ok, request} = Rpc.parse(params)
    assert {:ok, [user_id: @user_id, is_active?: false]} = Pipeline.resolve_identity(request)

    assert %{"success" => true} =
             Rpc.run(params, struct(Subscription, id: @sub_id, user_id: @user_id))
  end
end
