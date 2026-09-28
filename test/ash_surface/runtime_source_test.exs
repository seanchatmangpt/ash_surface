defmodule AshSurface.RuntimeSourceTest do
  @moduledoc """
  State-based provenance tests for `AshSurface.runtime_source/0`.

  Law pinned: the served runtime is exactly the shipped artifact, is ordinary
  JavaScript (JSDoc + Zod, never TypeScript), carries the declared schema
  version, and exposes the documented public export surface. There is no
  whole-file digest golden: a byte-change-detector is not a correctness guard;
  behavioural drift is caught by the JS behaviour suites and the mutation
  falsifier (`scripts/ci_falsifier.sh`). No env, db, or network is exercised.
  """

  use ExUnit.Case, async: true

  @version_marker_regex ~r/SURFACE_RUNTIME_VERSION\s*=\s*"([^"]+)"/

  describe "runtime_source/0" do
    test "returns a non-empty binary of the shipped JS runtime" do
      assert {:ok, source} = AshSurface.runtime_source()
      assert is_binary(source)
      assert byte_size(source) > 0
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

    test "is ordinary JavaScript: no TypeScript syntax, no type-only files" do
      assert {:ok, source} = AshSurface.runtime_source()
      assert String.ends_with?(AshSurface.runtime_path(), ".mjs")
      refute source =~ ~r/^\s*(export\s+)?(interface|type)\s+\w+\s*(=|\{)/m
      refute source =~ ~r/\bimport\s+type\b/
      assert source =~ ~r/from\s+"zod"/
    end

    test "exports the documented public runtime surface" do
      assert {:ok, source} = AshSurface.runtime_source()

      exported =
        ~r/^export\s+(?:const|function|class)\s+([A-Za-z_$][\w$]*)/m
        |> Regex.scan(source, capture: :all_but_first)
        |> List.flatten()

      for name <-
            ~w(createClient SurfaceRuntimeError SURFACE_RUNTIME_VERSION STANDING_VALUES
               ashSurfaceContractSchema surfaceActionSchema eventProjectionSchema
               reconcileResultSchema) do
        assert name in exported, "runtime no longer exports #{name}"
      end

      assert Enum.uniq(exported) == exported
    end
  end
end
