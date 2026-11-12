defmodule AshSurface.Ported.VerifyActionTypesHelper do
  @moduledoc """
  Real-validator harness for the ported `verify_action_types/*` tests (lane T4).

  ash_typescript calls `AshTypescript.Manifest.verify_for_domains/1`, which returns
  `:ok | {:error, message}`. The ash_surface counterpart is the real
  `AshSurface.Resource.Validator` (no doubles): refusals with code
  `invalid_action_type_field_names` are rendered into one message whose first
  line keeps the reference wording so per-test assertions port verbatim.
  Spark compile output of the throwaway resources is captured, not hidden.
  """

  @code "invalid_action_type_field_names"

  @spec verify([module()]) :: :ok | {:error, String.t()}
  def verify(resources) do
    {result, _stderr} =
      ExUnit.CaptureIO.with_io(:standard_error, fn ->
        resources
        |> Enum.flat_map(fn resource ->
          case AshSurface.Resource.Validator.validate(%{resource: resource, surface: []}) do
            :ok -> []
            {:error, refusals} -> Enum.filter(refusals, &(&1.code == @code))
          end
        end)
      end)

    case result do
      [] ->
        :ok

      refusals ->
        {:error,
         "Invalid field names found in action return types or argument types.\n" <>
           Enum.map_join(refusals, "\n\n", & &1.detail)}
    end
  end
end
