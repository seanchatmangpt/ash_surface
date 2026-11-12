defmodule AshSurface.Ported.Rpc.Ray.Emb do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:a, :integer, public?: true)
  end
end

defmodule AshSurface.Ported.Rpc.Ray.Item do
  @moduledoc "Lane RAY: calculations with one optional arg, a complex return, and no args."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Ray.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RayItem")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:base, :integer, public?: true)
  end

  calculations do
    calculate :opt, :integer, expr(base * ^arg(:factor)) do
      public?(true)

      argument :factor, :integer do
        allow_nil?(true)
      end
    end

    calculate :info, AshSurface.Ported.Rpc.Ray.Emb, fn records, _ctx ->
                {:ok, Enum.map(records, fn _ -> %AshSurface.Ported.Rpc.Ray.Emb{a: 1} end)}
              end do
      public?(true)

      argument :factor, :integer do
        allow_nil?(true)
      end
    end

    calculate :req, :integer, expr(base * ^arg(:factor)) do
      public?(true)

      argument :factor, :integer do
        allow_nil?(false)
      end
    end

    calculate :plain, :integer, expr(base + 1) do
      public?(true)
    end
  end

  actions do
    defaults([:read, create: [:base]])
  end
end

defmodule AshSurface.Ported.Rpc.Ray.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Ray.Item)
  end
end

defmodule AshSurface.Ported.Rpc.Ray.CalcBranchesTest do
  @moduledoc """
  Lane RAY. Calculation branches of the field selector (SK-mutG K3-K7): one-argument
  acceptance, load-spec shapes, and fields on a non-complex calculation.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc.Ray.Item
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFieldsProcessor, as: RFP

  @otp_app :ash_surface_ported_ray

  defp manifest do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Ray.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Compat.prepare(manifest)
  end

  defp process(fields), do: RFP.process(Item, :read, fields, manifest())

  test "K3: a calculation with exactly one argument accepts supplied args" do
    assert {:ok, {[], [opt: %{factor: 2}], [:opt]}} =
             process([%{opt: %{args: %{factor: 2}}}])
  end

  test "K3b: a calculation with no arguments refuses supplied args" do
    assert {:error, {:invalid_calculation_args, :plain, []}} =
             process([%{plain: %{args: %{factor: 2}}}])
  end

  test "K5: args plus nested fields load as {name, {args, fields}}" do
    assert {:ok, {[], [info: {%{factor: 2}, [:a]}], [info: [:a]]}} =
             process([%{info: %{args: %{factor: 2}, fields: [:a]}}])
  end

  test "K6: args without fields load as {name, args}; neither is the bare name" do
    assert {:ok, {[], [opt: %{factor: 2}], _}} = process([%{opt: %{args: %{factor: 2}}}])
    assert {:ok, {[], [:plain], [:plain]}} = process([:plain])
  end

  test "K7: fields on a non-complex calculation are :invalid_field_selection" do
    assert {:error, {:invalid_field_selection, :opt, :calculation, []}} =
             process([%{opt: %{args: %{factor: 2}, fields: [:a]}}])
  end

  test "K4: a required argument refuses empty args; an optional one accepts them" do
    assert {:error, {:invalid_calculation_args, :req, []}} = process([%{req: %{args: %{}}}])
    assert {:ok, {[], [opt: %{}], [:opt]}} = process([%{opt: %{args: %{}}}])
  end
end
