defmodule AshPostgres.Ltree do
  @moduledoc """
  Ltree-SHAPED fixture type for T7/GU7 (ash_postgres is not a dependency). Matched by module
  name by `AshSurface.Compiler.TypeFacts.kind_string/1` (kind "ltree"); the value is a list of
  label strings, exactly what the real type holds after `cast_input/2`. Not a mock: a real
  `Ash.Type` implementation, used only where a real AshPostgres.Ltree is infeasible (no dep).
  """
  use Ash.Type

  @impl true
  def constraints, do: [escape?: [type: :boolean, default: false]]

  @impl true
  def storage_type(_), do: :string

  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(list, _) when is_list(list), do: {:ok, list}
  def cast_input(str, _) when is_binary(str), do: {:ok, String.split(str, ".")}
  def cast_input(_, _), do: :error

  @impl true
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(str, _) when is_binary(str), do: {:ok, String.split(str, ".")}
  def cast_stored(list, _) when is_list(list), do: {:ok, list}
  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(list, _) when is_list(list), do: {:ok, Enum.join(list, ".")}
  def dump_to_native(_, _), do: :error
end
