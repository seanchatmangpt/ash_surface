defmodule AshSurface.Ported.Manifest.RelationshipQueryCapabilitiesGapTest do
  @moduledoc """
  Loud-skip half of `manifest/relationship_query_capabilities_test` (lane T4
  mixed-file split convention: runnable tests live in `<name>_surface_test.exs`,
  skips live here in `<name>_gap_test.exs`).
  """
  use ExUnit.Case, async: true

  @tag skip:
         "relationship_query_capabilities_gap: many-relationships to non-RPC destinations are not stamped"
  test "many-relationships to non-surface destinations are not stamped" do
    # ash_surface relationship facts carry `exposed: true` for every public relationship
    # (manifest-first: plain Ash destinations are valid); there is no RPC allow-list to
    # derive "not exposed" from. Operator decision pending (see receipt).
    flunk("unreachable: skipped")
  end
end
