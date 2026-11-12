defmodule AshSurface.Naming do
  @moduledoc """
  Identifier-safety helpers for names that round-trip through Zod/TypeScript
  projection. Port of ash_typescript `name_validation.ex`.

  The canonical IR keeps snake_case names; these helpers only judge/suggest.
  """

  @doc "True when `name` would produce an awkward identifier (`_<digit>` or `?`)."
  @spec invalid_name?(atom | String.t()) :: boolean
  def invalid_name?(name), do: Regex.match?(~r/_+\d|\?/, to_string(name))

  @doc "True when `name` is usable verbatim as a JS identifier."
  @spec identifier?(atom | String.t()) :: boolean
  def identifier?(name), do: Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, to_string(name))

  @doc "Suggested replacement: drop the underscore before digits, drop `?`."
  @spec make_name_better(atom | String.t()) :: String.t()
  def make_name_better(name) do
    name
    |> to_string()
    |> String.replace(~r/_+\d/, fn v -> String.trim_leading(v, "_") end)
    |> String.replace("?", "")
  end
end
