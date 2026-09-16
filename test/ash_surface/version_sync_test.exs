defmodule AshSurface.VersionSyncTest do
  @moduledoc """
  Version law: the JavaScript runtime's SURFACE_RUNTIME_VERSION, the mix.exs
  @version, and the package.json version (when set) must all agree with the
  version exposed by `AshSurface.schema_version/0`.

  The golden below is the pinned truth for this checkout; a failure here means
  a version was bumped without its counterparts (or vice versa).
  """

  use ExUnit.Case, async: true

  @golden_version "26.9.16"
  @runtime_rel "priv/static/ash_surface_runtime.mjs"

  describe "version law across the surface, the runtime, and the manifests" do
    test "AshSurface.schema_version/0 matches the pinned golden version" do
      assert AshSurface.schema_version() == @golden_version
    end

    test "the JavaScript runtime SURFACE_RUNTIME_VERSION matches the Elixir surface version" do
      assert {:ok, source} = AshSurface.runtime_source(),
             "runtime adapter not readable at #{@runtime_rel} via AshSurface.runtime_source/0"

      assert runtime_constant(source) == AshSurface.schema_version(),
             "SURFACE_RUNTIME_VERSION in #{@runtime_rel} drifted from AshSurface.schema_version/0"
    end

    test "mix.exs @version matches the Elixir surface version" do
      assert {:ok, mix_source} = File.read("mix.exs")

      assert mix_exs_version(mix_source) == AshSurface.schema_version(),
             "mix.exs @version drifted from AshSurface.schema_version/0"
    end

    test "package.json version, when set, matches the Elixir surface version" do
      assert {:ok, raw} = File.read("package.json")
      assert {:ok, pkg} = Jason.decode(raw)

      case Map.get(pkg, "version") do
        nil ->
          # The JS projection package is private and ships no version;
          # the convention only binds package.json when it sets one.
          :ok

        version ->
          assert version == AshSurface.schema_version(),
                 "package.json version drifted from AshSurface.schema_version/0"
      end
    end
  end

  defp runtime_constant(source) do
    case Regex.run(~r/export\s+const\s+SURFACE_RUNTIME_VERSION\s*=\s*"([^"]+)"/, source) do
      [_, version] -> version
      other -> flunk("SURFACE_RUNTIME_VERSION not found in #{@runtime_rel}: #{inspect(other)}")
    end
  end

  defp mix_exs_version(source) do
    case Regex.run(~r/@version\s+"([^"]+)"/, source) do
      [_, version] -> version
      other -> flunk("@version not found in mix.exs: #{inspect(other)}")
    end
  end
end
