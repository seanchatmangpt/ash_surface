defmodule AshSurface.Ported.Rpc.Rbh.Item do
  @moduledoc "Lane RBH: calculation-argument fixtures (optional-only and optional+required)."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbh.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbhItem")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:base, :integer, public?: true)
  end

  calculations do
    calculate :mixed, :integer, expr(base * ^arg(:o) * ^arg(:r)) do
      public?(true)

      argument :o, :integer do
        allow_nil?(true)
      end

      argument :r, :integer do
        allow_nil?(false)
      end
    end

    calculate :opt, :integer, expr(base * ^arg(:factor)) do
      public?(true)

      argument :factor, :integer do
        allow_nil?(true)
      end
    end
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.Rbh.Parent do
  @moduledoc "Lane RBH: parent resource reaching the RBB Item calculations through a relationship."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbh.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbhParent")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  relationships do
    belongs_to :item, AshSurface.Ported.Rpc.Rbh.Item do
      public?(true)
    end
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.Rbh.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rbh.Parent)
    resource(AshSurface.Ported.Rpc.Rbh.Item)
  end
end

defmodule AshSurface.Ported.Rpc.Rbh.FieldSelectorPathsTest do
  @moduledoc """
  Lane RBH. SK-mutI survivors B3, B4, B5 in field_selector.ex: the optional-argument
  required-detection and the `path` carried by `{:invalid_calculation_args, name, path}`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc.Rbh.Item
  alias AshSurface.Ported.Rpc.Rbh.Parent
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFieldsProcessor, as: RFP

  @otp_app :ash_surface_ported_rbh

  defp manifest do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rbh.Domain])

    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Compat.prepare(manifest)
  end

  test "B3: empty args on an optional-only calculation are accepted (not 'required')" do
    assert {:ok, {[], [opt: %{}], [:opt]}} =
             RFP.process(Item, :read, [%{opt: %{args: %{}}}], manifest())
  end

  test "B4: nil args on an optional-arg calc nested under a relationship carry the nested path" do
    assert {:error, {:invalid_calculation_args, :opt, [:item]}} =
             RFP.process(Parent, :read, [%{item: [%{opt: %{fields: nil}}]}], manifest())
  end

  test "B5: empty args on a required-arg calc nested under a relationship carry the nested path" do
    assert {:error, {:invalid_calculation_args, :mixed, [:item]}} =
             RFP.process(Parent, :read, [%{item: [%{mixed: %{args: %{}}}]}], manifest())
  end
end
