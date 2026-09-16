defmodule AshSurface.Intent.CommandBus do
  @moduledoc """
  Delegated-DO boundary for intent dispatch.

  `ash_surface` never executes a consequential action itself. Actuation happens
  only on the far side of this behaviour, in a bus injected by the operator's
  runtime (Phoenix channel, HTTP command relay, test double). The bus owns the
  authority cut, the actuation, and the receipt; `ash_surface` owns only the
  manufacture of the intent handed over.
  """

  @doc """
  Submits a manufactured intent for actuation.

  Returns the bus's own receipt-bearing outcome `{:ok, receipt_ref}` or a typed
  refusal `{:error, reason}` (for example `{:error, :REFUSED_NO_AUTHORITY}`).
  """
  @callback submit(AshSurface.Intent.Envelope.t(), map()) :: {:ok, term()} | {:error, term()}
end

defmodule AshSurface.Intent.Envelope do
  @moduledoc """
  The minimal manufactured intent handed to an injected `CommandBus`.

  (Superseded-name note: declared as `AshSurface.Intent` on its landing
  branch; renamed at v50 integration — the full `SurfaceIntent` shape in
  `lib/ash_surface/intent.ex` owns the canonical name.) An action identity
  already admitted by the surface contract, plus the candidate payload
  carried verbatim. No execution semantics; a candidate/IR compilation
  pipeline, if ever admitted, lives upstream of this envelope, not inside it.
  """

  @enforce_keys [:action_id]
  defstruct [:action_id, :payload]

  @type t :: %__MODULE__{
          action_id: String.t(),
          payload: map()
        }
end

defmodule AshSurface.Intent.Dispatch do
  @moduledoc """
  Delegated-DO adapter: manufacture an intent from an admitted candidate map
  and hand it, with the caller's context, to the INJECTED command bus.

  This module never executes anything itself:

    - it performs no Ash action calls and owns no transport, process, or store;
    - it validates shape only, then delegates via `command_bus.submit/2`;
    - bus outcomes pass through EXACTLY — receipts are the bus's own, and
      typed refusals (e.g. `{:error, :REFUSED_NO_AUTHORITY}`) propagate
      untouched, never rewrapped or downgraded.

  The only refusals minted here are fail-closed input refusals: an invalid
  candidate is refused before the bus is ever touched, and a bus that does not
  conform to `AshSurface.Intent.CommandBus` is refused typed.
  """

  alias AshSurface.Intent.Envelope

  @doc """
  Manufactures an intent from `candidate_map` and submits it to `command_bus`.

  `candidate_map` must be a map carrying a non-empty string `:action_id`;
  every other key rides the intent payload verbatim. `context` (for example
  actor/tenant/authority material) is handed to the bus unchanged.
  """
  @spec submit(map(), module(), map()) :: {:ok, term()} | {:error, term()}
  def submit(candidate_map, command_bus, context) do
    with :ok <- validate_candidate(candidate_map),
         :ok <- validate_bus(command_bus) do
      intent = %Envelope{
        action_id: candidate_map.action_id,
        payload: Map.delete(candidate_map, :action_id)
      }

      command_bus.submit(intent, context)
    end
  end

  defp validate_candidate(candidate_map) when is_map(candidate_map) do
    action_id = Map.get(candidate_map, :action_id)

    cond do
      is_binary(action_id) and action_id != "" ->
        :ok

      action_id in [nil, ""] ->
        {:error, {:invalid_candidate, :missing_action_id}}

      true ->
        {:error, {:invalid_candidate, :invalid_action_id}}
    end
  end

  defp validate_candidate(_), do: {:error, {:invalid_candidate, :candidate_must_be_a_map}}

  defp validate_bus(command_bus)
       when is_atom(command_bus) and command_bus != nil do
    if function_exported?(command_bus, :submit, 2) do
      :ok
    else
      {:error, :REFUSED_NO_COMMAND_BUS}
    end
  end

  defp validate_bus(_), do: {:error, :REFUSED_NO_COMMAND_BUS}
end
