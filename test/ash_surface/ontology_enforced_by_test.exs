defmodule AshSurface.OntologyEnforcedByTest do
  @moduledoc """
  延 (externalization invariant) anchor for ontology.ttl: every
  `surf:enforcedBy` path named by a law row must exist on disk, and the 並
  capacity family (ticket gapfix-ontology-promo-017) must carry its facts —
  tier-scoped capacity, the flash-heavyweight ceiling, the rider setpoint
  exemption, and the storm protocol. A dropped row or a dangling anchor path
  fails here, so no concept in the ontology can silently lose its
  repo-side enforcement.
  """

  use ExUnit.Case, async: true

  @ontology "ontology.ttl"
  @enforced_by_regex ~r/surf:enforcedBy\s+"([^"]+)"/

  defp ttl, do: File.read!(@ontology)

  test "ontology.ttl exists at the authorship origin named by ggen.toml" do
    assert File.exists?(@ontology)
  end

  test "every surf:enforcedBy path exists on disk" do
    paths =
      @enforced_by_regex
      |> Regex.scan(ttl())
      |> Enum.map(fn [_, path] -> path end)
      |> Enum.uniq()

    assert length(paths) > 0, "ontology.ttl carries no enforcedBy anchors"

    for path <- paths do
      assert File.exists?(path), "enforcedBy anchor path does not exist: #{path}"
    end
  end

  test "並 capacity tier law row is present with its telemetry path" do
    ttl = ttl()
    assert ttl =~ "surf:CapacityTierLaw"
    assert ttl =~ ~s(surf:capacityTelemetry "capacity-ride/log.ndjson")
  end

  test "並 flash-heavyweight ceiling row pins ceiling 16" do
    ttl = ttl()
    assert ttl =~ "surf:FlashHeavyweightCeiling"
    assert ttl =~ "surf:capacityTier \"flash\""
    assert ttl =~ "surf:capacityWeight \"heavyweight\""
    assert ttl =~ "surf:capacityCeiling 16"
  end

  test "並 rider setpoint law row is present" do
    assert ttl() =~ "surf:RiderSetpointLaw"
  end

  test "並 storm protocol row is present with the [1302] refusal fact" do
    ttl = ttl()
    assert ttl =~ "surf:StormProtocol"
    assert ttl =~ "1302"
  end
end
