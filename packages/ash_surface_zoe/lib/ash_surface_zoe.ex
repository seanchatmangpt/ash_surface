defmodule AshSurfaceZoe do
  @moduledoc """
  ZOE / DfCM devotional human-surface family, extracted from `ash_surface` core.

  The modules keep their original names (`AshSurface.HumanSurface`,
  `AshSurface.Possibility`, `AshSurface.ZoeDemo`, ...) so consumers only add
  the `:ash_surface_zoe` dependency; this namespace module owns the package's
  JavaScript runtime path and the Expo human/demo projector
  (`AshSurfaceZoe.Projector.Human`).
  """

  @doc "Absolute path of the package's JavaScript human-surface schemas (`ash_surface_zoe.mjs`)."
  @spec runtime_path() :: String.t()
  def runtime_path do
    Application.app_dir(:ash_surface_zoe, "priv/static/ash_surface_zoe.mjs")
  end

  @doc "Reads the package's JavaScript human-surface schemas."
  @spec runtime_source() :: {:ok, String.t()} | {:error, File.posix()}
  def runtime_source, do: File.read(runtime_path())
end
