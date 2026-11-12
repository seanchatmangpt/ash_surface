defmodule AshSurface.Ported.Rpc.C.RpcCompositePrimaryKeyIrSurfaceTest do
  @moduledoc """
  Adaptation of the reference composite primary key tests 001-004 that asserted generated
  TypeScript text (`identity: { tenantId: UUID; settingKey: string }` for update/destroy,
  the string-widened identity for validation). ash_surface emits no `.ts`; the behavior is:

    * the composite primary-key identity is an object with every key part required: the IR
      `schema.get["identities"]["primary_key"]` zod, parsed under node + real zod
    * update/destroy requests carry the composite identity map to the pipeline
    * the validation entry point accepts the identity without a type-level UUID requirement
      (`tenantId` as a plain string): validation never resolves the record

  Test 005 (channel function text) remains a loud skip in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.{Rpc, RpcValidate, Tsa10}

  defmodule Setting do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      attribute(:tenant_id, :uuid, allow_nil?: false, public?: true, primary_key?: true)
      attribute(:setting_key, :string, allow_nil?: false, public?: true, primary_key?: true)
      attribute(:value, :string, allow_nil?: false, public?: true)
    end

    actions do
      defaults([:read])
      read(:by_key, do: get?(true))
    end

    surface do
      projection :by_key, get?: true, identities: [:_primary_key]
    end
  end

  setup_all do
    ir = Tsa10.ir!(Tsa10.irs([{Setting, :by_key}]), Setting, :by_key)
    %{ir: ir}
  end

  @uuid "6fa459ea-ee8a-3ca4-894e-db77e160355e"

  defp identity_zod(ir), do: ir.schema.get["identities"]["primary_key"]

  test "001 generates object type for composite primary key in update function", %{ir: ir} do
    zod = identity_zod(ir)
    assert is_binary(zod)

    {t, k} = key_names(zod)

    assert Tsa10.node_eval(zod, [
             %{t => @uuid, k => "theme"},
             %{t => @uuid},
             %{k => "theme"},
             %{t => "not-a-uuid", k => "theme"}
           ]) == [true, false, false, false]

    params = %{
      "action" => "update_tenant_setting",
      "identity" => %{"tenantId" => @uuid, "settingKey" => "theme"},
      "input" => %{"value" => "light"},
      "fields" => ["value"]
    }

    assert {:ok, request} = Rpc.parse(params)
    assert request.identity == %{"tenantId" => @uuid, "settingKey" => "theme"}
  end

  test "002 generates union types for composite primary key in validation function" do
    # the validation entry point does not resolve the record: a non-UUID tenantId is not a type
    # error there (the reference widens `UUID | string`); the real UUID form is accepted too
    record = struct(P.TenantSetting, %{tenant_id: @uuid, setting_key: "theme", value: "dark"})

    for tenant <- [@uuid, "not-a-uuid"] do
      assert %{"success" => true} =
               RpcValidate.validate(
                 %{
                   "action" => "update_tenant_setting",
                   "identity" => %{"tenantId" => tenant, "settingKey" => "theme"},
                   "input" => %{"value" => "x"}
                 },
                 record: record
               )
    end
  end

  test "003 generates object type for composite primary key in destroy function", %{ir: ir} do
    zod = identity_zod(ir)
    {t, k} = key_names(zod)
    assert Tsa10.node_eval(zod, [%{t => @uuid, k => "language"}, %{t => @uuid}]) == [true, false]

    params = %{
      "action" => "destroy_tenant_setting",
      "identity" => %{"tenantId" => @uuid, "settingKey" => "language"}
    }

    assert {:ok, request} = Rpc.parse(params)
    assert request.identity == %{"tenantId" => @uuid, "settingKey" => "language"}
  end

  test "004 generates union types for composite primary key in destroy validation function" do
    record = struct(P.TenantSetting, %{tenant_id: @uuid, setting_key: "theme", value: "dark"})

    for tenant <- [@uuid, "not-a-uuid"] do
      assert %{"success" => true} =
               RpcValidate.validate(
                 %{
                   "action" => "destroy_tenant_setting",
                   "identity" => %{"tenantId" => tenant, "settingKey" => "theme"}
                 },
                 record: record
               )
    end
  end

  defp key_names(zod) do
    t = if zod =~ "tenantId", do: "tenantId", else: "tenant_id"
    k = if zod =~ "settingKey", do: "settingKey", else: "setting_key"
    {t, k}
  end

  describe "IR identity facts are exact (mutation-killing)" do
    test "the get schema admits exactly one identity, the primary key", %{ir: ir} do
      assert Map.keys(ir.schema.get["identities"]) == ["primary_key"]
    end

    test "the identity zod is strict about unknown and mistyped parts", %{ir: ir} do
      {t, k} = key_names(identity_zod(ir))

      assert Tsa10.node_eval(identity_zod(ir), [
               %{t => @uuid, k => "a"},
               %{t => @uuid, k => 1},
               %{t => 5, k => "a"},
               %{t => @uuid, k => "a", "extra" => true},
               %{},
               %{t => nil, k => nil}
             ]) == [true, false, false, false, false, false]
    end

    test "the identity zod names every key part exactly once", %{ir: ir} do
      zod = identity_zod(ir)
      {t, k} = key_names(zod)
      assert length(String.split(zod, t)) == 2
      assert length(String.split(zod, k)) == 2
      refute zod =~ "value"
    end

    test "resource facts: identities and primary key", %{ir: ir} do
      facts = AshSurface.Compiler.ResourceFacts.build(Setting, Ash.Resource.Info.action(Setting, :by_key))
      assert facts.get? == true
      assert facts.primary_key == ["tenantId", "settingKey"]
      assert [%{"name" => "_primary_key", "keys" => keys}] = facts.identities
      assert length(keys) == 2
      assert is_map(ir)
    end

    test "without the identity declaration no primary_key identity is admitted" do
      defmodule NoIdent do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Simple,
          validate_domain_inclusion?: false,
          extensions: [AshSurface.Resource]

        attributes do
          attribute(:a, :uuid, allow_nil?: false, public?: true, primary_key?: true)
          attribute(:b, :string, allow_nil?: false, public?: true, primary_key?: true)
        end

        actions do
          defaults([:read])
        end

        surface do
          projection :read
        end
      end

      facts =
        AshSurface.Compiler.ResourceFacts.build(NoIdent, Ash.Resource.Info.action(NoIdent, :read))

      assert facts.identities == []
      assert facts.get? == false
    end
  end
end
