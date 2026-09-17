defmodule AshSurface.RuntimeSourceTest do
  @moduledoc """
  State-based provenance tests for `AshSurface.runtime_source/0`.

  Frozen against the shipped artifact `priv/static/ash_surface_runtime.mjs`.
  Any change to that file must, in the same change, update the golden digest
  here and re-freeze it. No env, db, or network is exercised.
  """

  use ExUnit.Case, async: true

  # v26.9.16 delegation: re-frozen after the runtime's surfaceActionSchema moved
  # delegated facts (semanticId/authorityBoundary/doAuthority/receiptRequired)
  # from client-side defaults to nullable delegated-or-null.
  # gapfix-test-surface-015: re-frozen after the ontologyDigest/
  # applicationReleaseIdentity producer-or-remove ledger comment was added to
  # ashSurfaceContractSchema (comment-only change; no executable byte moved).
  # gapfix-bump-mech-007 at integration (018): re-frozen after the 26.9.17
  # carrier bump and the 015 comment union — the schema-site comment is still
  # comment-only; the version marker moved through the bump mechanism.
  @golden_runtime_sha256 "37d5c1c91f9e23743c31e0830c2381d954783af42bad244d68e3b7923964fcc2"

  @version_marker_regex ~r/SURFACE_RUNTIME_VERSION\s*=\s*"([^"]+)"/

  describe "runtime_source/0" do
    test "returns a non-empty binary of the shipped JS runtime" do
      assert {:ok, source} = AshSurface.runtime_source()
      assert is_binary(source)
      assert byte_size(source) > 0
    end

    test "hashes to the golden-frozen SHA-256 digest of the shipped runtime" do
      assert {:ok, source} = AshSurface.runtime_source()
      digest = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
      assert digest == @golden_runtime_sha256
    end

    test "carries a SURFACE_RUNTIME_VERSION marker matching the declared schema version" do
      assert {:ok, source} = AshSurface.runtime_source()

      assert [marker_version] =
               Regex.run(@version_marker_regex, source, capture: :all_but_first) ||
                 flunk("no SURFACE_RUNTIME_VERSION marker found in runtime source")

      assert marker_version == AshSurface.schema_version()
    end

    test "hashes identically to the runtime file on disk (no function/artifact drift)" do
      assert {:ok, source} = AshSurface.runtime_source()
      assert {:ok, disk} = File.read(AshSurface.runtime_path())

      source_digest = Base.encode16(:crypto.hash(:sha256, source), case: :lower)
      disk_digest = Base.encode16(:crypto.hash(:sha256, disk), case: :lower)

      assert source_digest == disk_digest
      assert source == disk
    end
  end
end
