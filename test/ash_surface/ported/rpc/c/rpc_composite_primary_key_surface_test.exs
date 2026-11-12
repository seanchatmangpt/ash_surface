defmodule AshSurface.Ported.Rpc.C.RpcCompositePrimaryKeySurfaceTest do
  @moduledoc """
  Port of the reference composite primary key runtime tests that are decidable without an
  action run: the composite `identity` map reaches the `Request` untouched, result processing of
  caller-built records, and the not_found envelope of a caller-built error. Missing composite
  identity fields are refused by the non-actuating `Pipeline.resolve_identity/1`. The five
  generated-TypeScript tests stay loud skips in `rpc_composite_primary_key_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.Ported, as: P

  test "updates record using composite primary key identity" do
    tenant_id = Ash.UUID.generate()

    params = %{
      "action" => "update_tenant_setting",
      "identity" => %{"tenantId" => tenant_id, "settingKey" => "theme"},
      "input" => %{"value" => "light"},
      "fields" => ["tenantId", "settingKey", "value"]
    }

    assert {:ok, request} = R.parse(params)
    assert request.identity == %{"tenantId" => tenant_id, "settingKey" => "theme"}
    assert request.input == %{value: "light"}

    updated =
      struct(P.TenantSetting, %{tenant_id: tenant_id, setting_key: "theme", value: "light"})

    assert %{"success" => true, "data" => data} = R.run(params, updated)
    assert data["tenantId"] == tenant_id
    assert data["settingKey"] == "theme"
    assert data["value"] == "light"
  end

  test "destroys record using composite primary key identity" do
    new_tenant_id = Ash.UUID.generate()

    params = %{
      "action" => "destroy_tenant_setting",
      "identity" => %{"tenantId" => new_tenant_id, "settingKey" => "language"}
    }

    assert {:ok, request} = R.parse(params)
    assert request.identity == %{"tenantId" => new_tenant_id, "settingKey" => "language"}

    assert %{"success" => true} =
             R.run(
               params,
               struct(P.TenantSetting, %{tenant_id: new_tenant_id, setting_key: "language"})
             )
  end

  test "returns error when composite identity fields are missing" do
    params = %{
      "action" => "update_tenant_setting",
      "identity" => %{"tenantId" => Ash.UUID.generate()},
      "input" => %{"value" => "updated"},
      "fields" => ["value"]
    }

    assert {:ok, request} = R.parse(params)

    assert {:error, reason} = AshSurface.RuntimeParity.Rpc.Pipeline.resolve_identity(request)
    assert {:invalid_identity, _} = reason

    result = AshSurface.RuntimeParity.Rpc.Pipeline.error_response(reason)
    assert %{"success" => false, "errors" => errors} = result
    assert errors != []
  end

  test "returns not found error when composite identity doesn't match" do
    result =
      R.run(
        %{
          "action" => "update_tenant_setting",
          "identity" => %{"tenantId" => Ash.UUID.generate(), "settingKey" => "nonexistent"},
          "input" => %{"value" => "updated"},
          "fields" => ["value"]
        },
        {:error, Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: P.TenantSetting})}
      )

    assert %{"success" => false, "errors" => errors} = result
    assert Enum.any?(errors, &(&1["type"] == "not_found"))
  end

  describe "composite identity resolution is exact (mutation-killing)" do
    alias AshSurface.RuntimeParity.Rpc.Pipeline

    defp parsed(action, identity) do
      params =
        %{"action" => action, "input" => %{"value" => "x"}, "fields" => ["value"]}
        |> then(&if identity == :none, do: &1, else: Map.put(&1, "identity", identity))

      assert {:ok, request} = R.parse(params)
      request
    end

    test "full composite identity resolves to the ordered primary-key filter" do
      t = Ash.UUID.generate()

      assert {:ok, filter} =
               Pipeline.resolve_identity(
                 parsed("update_tenant_setting", %{"tenantId" => t, "settingKey" => "theme"})
               )

      assert filter == [tenant_id: t, setting_key: "theme"]
    end

    test "destroy resolves the same composite filter" do
      t = Ash.UUID.generate()

      assert {:ok, [tenant_id: ^t, setting_key: "language"]} =
               Pipeline.resolve_identity(
                 parsed("destroy_tenant_setting", %{"tenantId" => t, "settingKey" => "language"})
               )
    end

    test "each missing part is refused with the exact provided and expected keys" do
      t = Ash.UUID.generate()

      assert {:error, {:invalid_identity, info}} =
               Pipeline.resolve_identity(parsed("update_tenant_setting", %{"tenantId" => t}))

      assert info.provided_keys == ["tenantId"]
      assert info.expected_keys == ["tenantId", "settingKey"]
      assert info.identities == [:_primary_key]

      assert {:error, {:invalid_identity, info2}} =
               Pipeline.resolve_identity(
                 parsed("update_tenant_setting", %{"settingKey" => "theme"})
               )

      assert info2.provided_keys == ["settingKey"]
      assert info2.expected_keys == ["tenantId", "settingKey"]
    end

    test "absent identity is a missing_identity refusal naming both key parts" do
      assert {:error, {:missing_identity, info}} =
               Pipeline.resolve_identity(parsed("update_tenant_setting", :none))

      assert info.expected_keys == ["tenantId", "settingKey"]
      assert info.identities == [:_primary_key]
    end

    test "extra identity keys are ignored by the filter" do
      t = Ash.UUID.generate()

      assert {:ok, [tenant_id: ^t, setting_key: "k"]} =
               Pipeline.resolve_identity(
                 parsed("update_tenant_setting", %{
                   "tenantId" => t,
                   "settingKey" => "k",
                   "bogus" => 1
                 })
               )
    end

    test "non-identity actions resolve to no filter" do
      assert {:ok, nil} = Pipeline.resolve_identity(parsed("create_tenant_setting", :none))
    end

    test "the error envelope for a refused identity is a typed failure" do
      assert {:error, reason} =
               Pipeline.resolve_identity(
                 parsed("update_tenant_setting", %{"tenantId" => Ash.UUID.generate()})
               )

      assert %{"success" => false, "errors" => [first | _]} = Pipeline.error_response(reason)
      assert is_binary(first["type"])
    end
  end
end
