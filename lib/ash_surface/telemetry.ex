defmodule AshSurface.Telemetry do
  @moduledoc """
  Elixir-side observability for AshSurface, over the `:telemetry` library.

  Events (all carry metadata only, never payload or input values):

    * `[:ash_surface, :transport, :select]` — `AshSurface.Transport.select/3`
      returned a decision. Measurements: `%{available_count: n}`. Metadata:
      `action_id`, `declared`, `available`, `selected`, `reason`,
      `dimensions` (`:undelegated | :declared`).
    * `[:ash_surface, :receipt, :refused]` — a receipt back-projection was
      refused. Metadata: `standing` (the `:REFUSED_*` atom) and
      `reason_class` (the refusal's reason head atom, never its values).
    * `[:ash_surface, :intent, :dispatch]` — `AshSurface.Intent.Dispatch.submit/3`
      finished. Metadata: `action_id` and `outcome`, one of `:submitted`,
      `:bus_error`, or `{:refused, class}` where class is one of
      `:invalid_candidate`, `:unknown_action`, `:invalid_context`,
      `:no_command_bus`.

  Emission is fire-and-forget: with no handler attached `:telemetry.execute/3`
  is a lookup on an empty ETS list, and a raising handler is detached by
  `:telemetry` itself, so an observer can never break a caller. Telemetry is
  observation only; it never changes selection, dispatch, or replay behaviour
  (transport law: selection before dispatch, no post-dispatch replay).
  """

  @transport_select [:ash_surface, :transport, :select]
  @receipt_refused [:ash_surface, :receipt, :refused]
  @intent_dispatch [:ash_surface, :intent, :dispatch]

  @doc "All event names emitted by AshSurface."
  @spec events() :: [[atom(), ...], ...]
  def events, do: [@transport_select, @receipt_refused, @intent_dispatch]

  @doc "Emits `[:ash_surface, :transport, :select]` for a selection decision."
  @spec transport_selected(AshSurface.Transport.Decision.t()) :: :ok
  def transport_selected(%AshSurface.Transport.Decision{} = decision) do
    :telemetry.execute(
      @transport_select,
      %{available_count: length(decision.available)},
      %{
        action_id: decision.action_id,
        declared: decision.declared,
        available: decision.available,
        selected: decision.selected,
        reason: decision.reason,
        dimensions: decision.dimensions
      }
    )
  end

  @doc "Emits `[:ash_surface, :receipt, :refused]` for a refusal map."
  @spec receipt_refused(%{required(:standing) => atom(), required(:reason) => term()}) :: :ok
  def receipt_refused(%{standing: standing, reason: reason}) do
    :telemetry.execute(@receipt_refused, %{count: 1}, %{
      standing: standing,
      reason_class: reason_class(reason)
    })
  end

  @doc "Emits `[:ash_surface, :intent, :dispatch]` with a classified outcome."
  @spec intent_dispatched(term(), term()) :: :ok
  def intent_dispatched(action_id, result) do
    :telemetry.execute(@intent_dispatch, %{count: 1}, %{
      action_id: if(is_binary(action_id), do: action_id),
      outcome: outcome(result)
    })
  end

  defp outcome({:ok, _receipt}), do: :submitted
  defp outcome({:error, {:invalid_candidate, _}}), do: {:refused, :invalid_candidate}
  defp outcome({:error, {:invalid_context, _}}), do: {:refused, :invalid_context}
  defp outcome({:error, :REFUSED_UNKNOWN_ACTION}), do: {:refused, :unknown_action}
  defp outcome({:error, :REFUSED_NO_COMMAND_BUS}), do: {:refused, :no_command_bus}
  defp outcome({:error, _bus_reason}), do: :bus_error
  defp outcome(_other), do: :bus_error

  defp reason_class(reason) when is_atom(reason), do: reason

  defp reason_class(reason) when is_tuple(reason) and tuple_size(reason) > 0 do
    case elem(reason, 0) do
      head when is_atom(head) -> head
      _ -> :unclassified
    end
  end

  defp reason_class(_reason), do: :unclassified
end
