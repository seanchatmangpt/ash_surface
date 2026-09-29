defmodule AshSurface.CastleCapabilityIntakeRuntimeTest do
  use ExUnit.Case, async: true

  alias AshSurface.CastleCapabilityIntake

  test "mobile and document donors remain powerless projections" do
    assert CastleCapabilityIntake.owner_capability() == "HUMAN_BOARD_SURFACE"
    assert CastleCapabilityIntake.authority_ceiling() == :construct
    assert length(CastleCapabilityIntake.donors()) == 2

    assert {:ok, mmdio} = CastleCapabilityIntake.fetch("seanchatmangpt/mmdio")
    assert mmdio.sha == "afc1f6e890a6d1c17b84d5931b21d3c74a851ebc"
    assert mmdio.placement == :powerless_document_projection
    refute CastleCapabilityIntake.canonical_truth?(mmdio)
    refute CastleCapabilityIntake.do_authority?(mmdio)
  end
end
