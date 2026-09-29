defmodule AshSurface.CastleCapabilityIntakeTest do
  use ExUnit.Case, async: true

  @path Path.expand("../conformance/castle-capability-intake.ttl", __DIR__)

  test "mobile and document projections remain powerless views" do
    graph = File.read!(@path)

    assert graph =~ "50fdfa20c84205a80c6eb94e916cffbedc4b816e"
    assert graph =~ ~s(eco:ownerCapability "HUMAN_BOARD_SURFACE")
    assert graph =~ "seanchatmangpt/ash_expo"
    assert graph =~ "024852b92330c76e12d0ab26531ef1e511c71041"
    assert graph =~ "seanchatmangpt/mmdio"
    assert graph =~ "afc1f6e890a6d1c17b84d5931b21d3c74a851ebc"
    assert graph =~ ~s(eco:runtimePlacement "POWERLESS_DOCUMENT_PROJECTION")
    assert graph =~ ~s(eco:projectionStanding "CANDIDATE")
    assert graph =~ ~s(eco:authorityCeiling "CONSTRUCT")
    refute graph =~ ~s(eco:authorityCeiling "DO")
    refute graph =~ ~s(eco:projectionStanding "ALIVE")
  end
end
