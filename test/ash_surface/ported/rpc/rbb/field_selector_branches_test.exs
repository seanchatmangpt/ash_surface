defmodule AshSurface.Ported.Rpc.Rbb.Emb do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:a, :integer, public?: true)
  end
end

defmodule AshSurface.Ported.Rpc.Rbb.Item do
  @moduledoc "Lane RBB: calculation-argument branch fixtures."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbb.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbbItem")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:base, :integer, public?: true)
  end

  calculations do
    # one optional + one required argument
    calculate :mixed, :integer, expr(base * ^arg(:o) * ^arg(:r)) do
      public?(true)

      argument :o, :integer do
        allow_nil?(true)
      end

      argument :r, :integer do
        allow_nil?(false)
      end
    end

    # complex return, no arguments
    calculate :cinfo, AshSurface.Ported.Rpc.Rbb.Emb, fn records, _ctx ->
                {:ok, Enum.map(records, fn _ -> %AshSurface.Ported.Rpc.Rbb.Emb{a: 1} end)}
              end do
      public?(true)
    end

    # optional argument only
    calculate :opt, :integer, expr(base * ^arg(:factor)) do
      public?(true)

      argument :factor, :integer do
        allow_nil?(true)
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

defmodule AshSurface.Ported.Rpc.Rbb.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rbb.Item)
  end
end

defmodule AshSurface.Ported.Rpc.Rbb.FieldSelectorBranchesTest do
  @moduledoc """
  Lane RBB. SK-mutH survivors K-b, K-d, K-e, K-f, K-g of the calculation-argument
  validation and load-spec construction in field_selector.ex.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc.Rbb.Item
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFieldsProcessor, as: RFP

  @otp_app :ash_surface_ported_rbb

  defp manifest do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rbb.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Compat.prepare(manifest)
  end

  defp process(fields), do: RFP.process(Item, :read, fields, manifest())

  test "K-d: any required argument among optional ones refuses empty args" do
    assert {:error, {:invalid_calculation_args, :mixed, []}} =
             process([%{mixed: %{args: %{}}}])

    assert {:ok, {[], [mixed: %{r: 1}], [:mixed]}} =
             process([%{mixed: %{args: %{r: 1}}}])
  end

  test "K-e: nested fields with no args load as {name, fields}, not {name, {nil, fields}}" do
    assert {:ok, {[], [cinfo: [:a]], [cinfo: [:a]]}} =
             process([%{cinfo: %{fields: [:a]}}])
  end

  test "K-f: empty args on a no-arg complex calculation are accepted" do
    assert {:ok, {[], [cinfo: {%{}, [:a]}], [cinfo: [:a]]}} =
             process([%{cinfo: %{args: %{}, fields: [:a]}}])
  end

  test "K-f2: empty args on a no-arg non-complex calculation are refused" do
    assert {:error, {:invalid_calculation_args, :plain, []}} =
             process([%{plain: %{args: %{}}}])
  end

  test "K-b: non-empty args on a no-arg complex calculation are refused" do
    assert {:error, {:invalid_calculation_args, :cinfo, []}} =
             process([%{cinfo: %{args: %{x: 1}, fields: [:a]}}])
  end

  test "K-g: nil args on an optional-argument calculation are refused" do
    assert {:error, {:invalid_calculation_args, :opt, []}} = process([%{opt: %{fields: nil}}])
  end
end
