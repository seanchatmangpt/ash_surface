defmodule AshSurface.Vocabulary do
  @moduledoc """
  The ONE Elixir definition of the cross-boundary vocabulary.

  Every closed set that also exists on the JavaScript side of the boundary
  (`VOCABULARY` in `priv/static/ash_surface_runtime.mjs`) is defined here and
  nowhere else in Elixir: the refusal prefix and predicate, base standings,
  reconcile statuses, known transports, dimensions, dimension classes and their
  weighing priority, the digest hex length, and dispatch outcomes.

  `AshSurface.Transport`, `AshSurface.Standing`, `AshSurface`,
  `AshSurface.IR.EventProjection` and `AshSurface.Telemetry` call into this
  module instead of restating the sets. A drift test
  (`test/ash_surface/vocabulary_drift_test.exs`) executes the JS runtime under
  Node and deep-compares `to_map/0` against its exported `VOCABULARY`, so a
  change on one side fails the build until the other side follows.

  ## Examples

      iex> AshSurface.Vocabulary.refusal_code?("REFUSED_NO_AUTHORITY")
      true

      iex> AshSurface.Vocabulary.refusal_code?("REFUSED_\\nX")
      false

      iex> AshSurface.Vocabulary.refusal_code?("REFUSED_")
      false

      iex> AshSurface.Vocabulary.known_transports()
      [:http, :phoenix_channel]
  """

  @refusal_prefix "REFUSED_"
  @base_standings [:ALIVE, :PARTIAL_ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]
  @reconcile_statuses ["COMPLETED", "NOT_OBSERVED", "STILL_UNKNOWN"]
  @known_transports [:http, :phoenix_channel]
  @dimensions [:cost, :latency, :privacy]
  @dimension_classes [:low, :medium, :high]
  @dimension_priority [:cost, :latency, :privacy]
  @digest_hex_length 64
  @dispatch_outcomes ["SUCCESS", "UNKNOWN_AFTER_DISPATCH"]
  @dispatch_states ["not_dispatched", "completed", "unknown_after_dispatch"]
  @idempotency_protocol "ash_surface.idempotency/1"

  @doc "The prefix every named refusal carries."
  @spec refusal_prefix() :: String.t()
  def refusal_prefix, do: @refusal_prefix

  @doc "The closed base standings (the REFUSED class is open-prefixed)."
  @spec base_standings() :: [atom(), ...]
  def base_standings, do: @base_standings

  @doc "Reconcile verdict statuses."
  @spec reconcile_statuses() :: [String.t(), ...]
  def reconcile_statuses, do: @reconcile_statuses

  @doc "Admitted transports, in canonical order."
  @spec known_transports() :: [atom(), ...]
  def known_transports, do: @known_transports

  @doc "Admitted transport dimensions."
  @spec dimensions() :: [atom(), ...]
  def dimensions, do: @dimensions

  @doc "Admitted dimension classes, weakest rank first."
  @spec dimension_classes() :: [atom(), ...]
  def dimension_classes, do: @dimension_classes

  @doc "Fixed deterministic weighing priority of the dimensions."
  @spec dimension_priority() :: [atom(), ...]
  def dimension_priority, do: @dimension_priority

  @doc "Length of a lowercase-hex sha256 digest."
  @spec digest_hex_length() :: pos_integer()
  def digest_hex_length, do: @digest_hex_length

  @doc "Dispatch outcomes (post-dispatch failure is never a verified standing)."
  @spec dispatch_outcomes() :: [String.t(), ...]
  def dispatch_outcomes, do: @dispatch_outcomes

  @doc "Dispatch states a receipt can record."
  @spec dispatch_states() :: [String.t(), ...]
  def dispatch_states, do: @dispatch_states

  @doc "The separately admitted idempotency protocol identity."
  @spec idempotency_protocol() :: String.t()
  def idempotency_protocol, do: @idempotency_protocol

  @doc """
  True exactly for a refusal code: the `REFUSED_` prefix plus a non-empty
  reason TOKEN (`[A-Za-z0-9_]+`). Bare `REFUSED` and `REFUSED_` are not
  refusals, and neither is a reason with line terminators or free text -
  codes flow into logs, events and receipts.

  ## Examples

      iex> AshSurface.Vocabulary.refusal_code?("REFUSED_UNKNOWN_ACTION")
      true

      iex> AshSurface.Vocabulary.refusal_code?("REFUSED")
      false

      iex> AshSurface.Vocabulary.refusal_code?(:REFUSED_X)
      false
  """
  @spec refusal_code?(term()) :: boolean()
  def refusal_code?(@refusal_prefix <> reason), do: Regex.match?(~r/\A[A-Za-z0-9_]+\z/, reason)
  def refusal_code?(_code), do: false

  @doc """
  True for an atom whose name is a refusal code (`:REFUSED_*` with a reason).

  ## Examples

      iex> AshSurface.Vocabulary.refusal_atom?(:REFUSED_NO_AUTHORITY)
      true

      iex> AshSurface.Vocabulary.refusal_atom?(:REFUSED)
      false
  """
  @spec refusal_atom?(term()) :: boolean()
  def refusal_atom?(atom) when is_atom(atom) and not is_nil(atom) and not is_boolean(atom),
    do: atom |> Atom.to_string() |> refusal_code?()

  def refusal_atom?(_other), do: false

  @doc """
  True when `value` has the runtime-minted digest byte shape: a binary of
  exactly `digest_hex_length/0` bytes. Shape only; case is not judged here.

  ## Examples

      iex> AshSurface.Vocabulary.digest_shape?(String.duplicate("a", 64))
      true

      iex> AshSurface.Vocabulary.digest_shape?("short")
      false
  """
  @spec digest_shape?(term()) :: boolean()
  def digest_shape?(value), do: is_binary(value) and byte_size(value) == @digest_hex_length

  @doc """
  True when `value` is a canonical digest: exactly `digest_hex_length/0`
  lowercase hex characters.

  ## Examples

      iex> AshSurface.Vocabulary.digest?(String.duplicate("a", 64))
      true

      iex> AshSurface.Vocabulary.digest?(String.duplicate("A", 64))
      false
  """
  @spec digest?(term()) :: boolean()
  def digest?(value) do
    digest_shape?(value) and value =~ ~r/\A[0-9a-f]+\z/
  end

  @doc """
  The whole comparable vocabulary as the JSON-shaped map the JS runtime
  mirrors (camelCase keys, string values): `VOCABULARY` plus `STANDING_VALUES`
  (as `standingValues`). `dimension_priority/0` is Elixir-side only until the
  runtime exports its `DIMENSION_PRIORITY`.
  """
  @spec to_map() :: map()
  def to_map do
    %{
      "refusalPrefix" => @refusal_prefix,
      "standingValues" => Enum.map(@base_standings, &Atom.to_string/1),
      "reconcileStatuses" => @reconcile_statuses,
      "knownTransports" => Enum.map(@known_transports, &Atom.to_string/1),
      "dimensions" => Enum.map(@dimensions, &Atom.to_string/1),
      "dimensionClasses" => Enum.map(@dimension_classes, &Atom.to_string/1),
      "digestHexLength" => @digest_hex_length,
      "dispatchStates" => @dispatch_states,
      "dispatchOutcomes" => @dispatch_outcomes,
      "idempotencyProtocol" => @idempotency_protocol
    }
  end
end
