defmodule AshSurface.PradyotChicagoProjectionCourtTest do
  use ExUnit.Case, async: true

  alias AshSurface.CastleCapabilityIntake

  @subject "urn:chicago:agentic-payment:purchase-001"

  test "the exact Chicago subject remains powerless when projected to a human surface" do
    for role <- ~w(buyer seller operator) do
      projection = %{subject: @subject, role: role, status: :admitted}

      refute CastleCapabilityIntake.canonical_truth?(projection)
      refute CastleCapabilityIntake.actuation_authority?(projection)
      assert CastleCapabilityIntake.authority_ceiling() == :construct
    end
  end

  test "changing presentation role cannot change the subject or authority ceiling" do
    projections =
      for role <- ~w(buyer seller operator) do
        %{subject: @subject, role: role, authority: CastleCapabilityIntake.authority_ceiling()}
      end

    assert Enum.uniq_by(projections, & &1.subject) == [hd(projections)]
    assert Enum.all?(projections, &(&1.subject == @subject))
    assert Enum.all?(projections, &(&1.authority == :construct))
    refute Enum.any?(projections, &CastleCapabilityIntake.actuation_authority?/1)
  end
end
