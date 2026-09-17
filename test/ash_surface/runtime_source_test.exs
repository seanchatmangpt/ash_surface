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
  @golden_runtime_sha256 "911406b4ce0bcd6438d32ffe98041ceb6f210c7e440d73e9e993b06c39a52bfc"

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
