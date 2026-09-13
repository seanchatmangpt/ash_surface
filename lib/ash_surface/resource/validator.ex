defmodule AshSurface.Resource.Validator do
  @moduledoc false

  @spec validate(map()) :: :ok | {:error, [map()]}
  def validate(%{surface: projections}) when is_list(projections) do
    duplicates =
      projections
      |> Enum.map(& &1.action)
      |> Enum.frequencies()
      |> Enum.filter(fn {_action, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    case duplicates do
      [] ->
        :ok

      actions ->
        {:error,
         Enum.map(actions, fn action ->
           %{
             code: "duplicate_action_projection",
             detail: "surface projection for #{inspect(action)} is declared more than once"
           }
         end)}
    end
  end

  def validate(_compiled) do
    {:error,
     [
       %{
         code: "invalid_surface_compilation",
         detail: "compiled AshSurface extension state must contain a surface projection list"
       }
     ]}
  end
end
