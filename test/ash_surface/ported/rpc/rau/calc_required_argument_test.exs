defmodule AshSurface.Ported.Rpc.Rau.Widget do
  @moduledoc "Lane RAU: calculation with a REQUIRED argument (allow_nil? false, no default)."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rau.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RauWidget")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:base, :integer, public?: true)
  end

  calculations do
    calculate :scaled, :integer, expr(base * ^arg(:factor)) do
      public?(true)

      argument :factor, :integer do
        allow_nil?(false)
      end
    end
  end

  actions do
    defaults([:read, create: [:base]])
  end
end

defmodule AshSurface.Ported.Rpc.Rau.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rau.Widget)
  end
end

defmodule AshSurface.Ported.Rpc.Rau.CalcRequiredArgumentTest do
  @moduledoc """
  Lane RAU. Field selection of a calculation whose argument is required: the
  empty-args branch (`calc_requires_args && !has_non_empty_args`) is only reachable here.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc.Rau.Widget
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFieldsProcessor, as: RFP

  @otp_app :ash_surface_ported_rau

  defp manifest do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rau.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Compat.prepare(manifest)
  end

  defp process(fields), do: RFP.process(Widget, :read, fields, manifest())

  test "bare atom for a required-arg calculation is :calculation_requires_args" do
    assert {:error, {:calculation_requires_args, :scaled, []}} = process([:scaled])
  end

  test "nil args is :invalid_calculation_args" do
    assert {:error, {:invalid_calculation_args, :scaled, []}} =
             process([%{scaled: %{fields: nil}}])
  end

  test "missing (empty) args is :invalid_calculation_args" do
    assert {:error, {:invalid_calculation_args, :scaled, []}} =
             process([%{scaled: %{args: %{}}}])
  end

  test "supplying the required arg succeeds and yields the load spec" do
    assert {:ok, {[], [scaled: %{factor: 3}], [:scaled]}} =
             process([%{scaled: %{args: %{factor: 3}}}])
  end

  test "wrong-typed required arg passes selection but fails the real Ash load" do
    assert {:ok, {[], [scaled: bad_args], _}} =
             process([%{scaled: %{args: %{factor: "abc"}}}])

    Ash.create!(Widget, %{base: 2})

    assert {:error, %Ash.Error.Invalid{}} =
             Widget |> Ash.Query.load(scaled: bad_args) |> Ash.read()

    assert {:ok, [%{scaled: 6}]} =
             Widget |> Ash.Query.load(scaled: %{factor: 3}) |> Ash.read()
  end
end
