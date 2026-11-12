defmodule AshSurface.Ported.Rpc.Rbn.Gadget do
  @moduledoc "Lane RBN: argument-less simple calculation plus an optional-arg calculation."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbn.CalcDomain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbnGadget")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:base, :integer, public?: true)
  end

  calculations do
    calculate :plain, :integer, expr(base + 1) do
      public?(true)
    end
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.Rbn.Holder do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbn.CalcDomain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbnHolder")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  relationships do
    belongs_to :gadget, AshSurface.Ported.Rpc.Rbn.Gadget do
      public?(true)
    end
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.Rbn.CalcDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rbn.Holder)
    resource(AshSurface.Ported.Rpc.Rbn.Gadget)
  end
end

defmodule AshSurface.Ported.Rpc.Rbn.CalcArgsNestedPathsTest do
  @moduledoc """
  Lane RBN. Skeptic survivors H4/H6/H7: `{:invalid_calculation_args, name, path}` carries the
  real nested path for an argument-less calculation given a nested map / non-empty args / empty
  args, at top level (path []) and under a relationship (path [:gadget]).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc.Rbn.{Gadget, Holder}
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFieldsProcessor, as: RFP

  @otp_app :ash_surface_ported_rbn_calc

  defp manifest do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rbn.CalcDomain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Compat.prepare(manifest)
  end

  @cases [
    h4: %{plain: %{base: 1}},
    h6: %{plain: %{args: %{x: 1}}},
    h7: %{plain: %{args: %{}}}
  ]

  for {id, spec} <- @cases do
    test "#{id}: top-level path is []" do
      assert {:error, {:invalid_calculation_args, :plain, []}} =
               RFP.process(Gadget, :read, [unquote(Macro.escape(spec))], manifest())
    end

    test "#{id}: nested path is [:gadget]" do
      assert {:error, {:invalid_calculation_args, :plain, [:gadget]}} =
               RFP.process(
                 Holder,
                 :read,
                 [%{gadget: [unquote(Macro.escape(spec))]}],
                 manifest()
               )
    end
  end
end
