defmodule AshSurface.Transport do
  @moduledoc """
  Pure pre-dispatch transport selection.

  Selection is intentionally separate from execution. Once dispatch begins, this
  module never authorizes automatic transport fallback: a timeout or disconnect can
  occur after the server has already executed a consequential action.
  """

  @known_transports [:http, :phoenix_channel]

  defmodule Decision do
    @enforce_keys [:declared, :available, :selected, :preferred, :reason]

    @type t :: %__MODULE__{
            action_id: String.t() | nil,
            declared: [atom()],
            available: [atom()],
            selected: atom(),
            preferred: atom(),
            reason: atom(),
            dispatch_state: :not_dispatched | :dispatched,
            fallback: :pre_dispatch_only
          }
    defstruct [
      :action_id,
      :declared,
      :available,
      :selected,
      :preferred,
      :reason,
      dispatch_state: :not_dispatched,
      fallback: :pre_dispatch_only
    ]
  end

  @spec select([atom()], [atom()], keyword()) :: {:ok, Decision.t()} | {:error, term()}
  def select(declared, available, opts \\ []) do
    preferred = Keyword.get(opts, :preferred, :http)
    action_id = Keyword.get(opts, :action_id)

    with :ok <- validate_transports(declared),
         :ok <- validate_transports(available),
         :ok <- validate_available_subset(declared, available),
         :ok <- validate_preferred(preferred),
         {:ok, selected, reason} <- choose(declared, available, preferred) do
      {:ok,
       %Decision{
         action_id: action_id,
         declared: declared,
         available: available,
         selected: selected,
         preferred: preferred,
         reason: reason
       }}
    end
  end

  @spec mark_dispatched(Decision.t()) :: Decision.t()
  def mark_dispatched(%Decision{} = decision), do: %{decision | dispatch_state: :dispatched}

  @spec fallback_allowed?(Decision.t()) :: boolean()
  def fallback_allowed?(%Decision{dispatch_state: :not_dispatched}), do: true
  def fallback_allowed?(%Decision{}), do: false

  defp choose(_declared, [], preferred),
    do: {:error, {:unsupported_transport, %{preferred: preferred, available: []}}}

  defp choose(declared, available, preferred) do
    cond do
      preferred in available ->
        {:ok, preferred, :preferred_available}

      true ->
        selected = Enum.find(declared, &(&1 in available))

        if selected do
          {:ok, selected, :preferred_unavailable}
        else
          {:error, {:unsupported_transport, %{preferred: preferred, available: available}}}
        end
    end
  end

  defp validate_available_subset(declared, available) do
    unadmitted = available -- declared
    if unadmitted == [], do: :ok, else: {:error, {:unadmitted_transport, unadmitted}}
  end

  defp validate_preferred(preferred) when preferred in @known_transports, do: :ok
  defp validate_preferred(preferred), do: {:error, {:unknown_transport, preferred}}

  defp validate_transports(transports) when is_list(transports) do
    unknown = Enum.reject(transports, &(&1 in @known_transports))
    if unknown == [], do: :ok, else: {:error, {:unknown_transport, unknown}}
  end

  defp validate_transports(_), do: {:error, :transports_must_be_a_list}
end
