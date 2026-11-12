defmodule AshSurface.Compiler.ObjectMode do
  @moduledoc """
  Single owner of the `zod_object_mode` -> zod object suffix mapping.

  `:strip` (zod's default object behaviour, the Config default) emits no suffix,
  `:strict` emits `.strict()`, `:passthrough` emits `.passthrough()`. ash_typescript has
  no object-mode option (its object schemas use zod defaults); this is an ash_surface
  extension and the unset default keeps that parity.
  """

  alias AshSurface.Config

  @spec suffix(:strip | :strict | :passthrough | nil) :: String.t()
  def suffix(mode \\ nil)
  def suffix(nil), do: suffix(Config.zod_object_mode())
  def suffix(:strict), do: ".strict()"
  def suffix(:passthrough), do: ".passthrough()"
  def suffix(:strip), do: ""

  @doc """
  Suffix for sites whose contract default is `.strict()`: an explicit per-call mode wins,
  `nil` keeps `.strict()` (byte-identical to the pre-ObjectMode output). The global
  `Config.zod_object_mode/0` is deliberately not consulted here, since its `:strip`
  default would change those sites' output.
  """
  @spec explicit_suffix(:strip | :strict | :passthrough | nil) :: String.t()
  def explicit_suffix(nil), do: ".strict()"
  def explicit_suffix(mode), do: suffix(mode)
end
