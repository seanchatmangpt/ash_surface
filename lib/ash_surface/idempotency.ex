defmodule AshSurface.Idempotency do
  @moduledoc """
  The `ash_surface.idempotency/1` protocol: the SEPARATELY ADMITTED
  idempotency/consequence protocol that alone permits a post-dispatch retry.

  Transport law (AGENTS.md): after dispatch a timeout/disconnect is
  `UNKNOWN_AFTER_DISPATCH` and the action is never silently replayed. A retry
  is legal only when the contract action's profile admits this protocol
  (`profile["idempotency"]["protocol"] == "ash_surface.idempotency/1"`) AND
  the call carried an idempotency key. See `docs/IDEMPOTENCY.md`.

  This module is the server-side twin of the JavaScript runtime
  (`priv/static/ash_surface_runtime.mjs`, `retryUnknown`) and is pure: no
  processes, no ETS, no clocks. It owns three things.

    * **Key law** — `validate_key/1`, `derive_key/2`: 8..128 characters of
      `[A-Za-z0-9_.:-]`, starting alphanumeric. The derived key is
      `"ik_" <> sha256_hex(canonical(%{"actionId" => .., "commandId" => ..}))`.
    * **Request digest** — `request_digest/2` is
      `AshSurface.CanonicalJSON.sha256_hex(%{"actionId" => id, "input" => input})`
      over the JSON-safe subset shared with JavaScript: strings (well-formed
      UTF-8), integers within +/-(2^53 - 1), booleans, `nil`, lists, and maps
      with string keys. Floats and other terms are refused (`{:error, reason}`)
      because their JSON spelling is not language-portable.
    * **Ledger** — `admit/3`, `reserve/3`, `complete/4` over a caller-supplied
      plain map `key => %{digest: hex, outcome: :pending | {:done, term}}`.
      `admit/3` answers `:first`, `{:replay, recorded_outcome}`, or
      `{:conflict, :digest_mismatch | :in_flight}`; a key reused with a
      different request digest is always a conflict (fail closed).

  Persistence, expiry and concurrency of the store are the caller's; this
  module never becomes a cache.
  """

  alias AshSurface.CanonicalJSON

  @protocol "ash_surface.idempotency/1"
  @max_safe_integer 9_007_199_254_740_991
  @key_pattern ~r/\A[A-Za-z0-9][A-Za-z0-9_.:\-]{7,127}\z/

  @typedoc "A caller-supplied ledger: idempotency key => entry."
  @type state :: %{optional(String.t()) => entry()}
  @type entry :: %{digest: String.t(), outcome: :pending | {:done, term()}}
  @type admission ::
          :first
          | {:replay, term()}
          | {:conflict, :digest_mismatch | :in_flight}

  @doc "The protocol identifier a contract action's profile must name."
  @spec protocol() :: String.t()
  def protocol, do: @protocol

  @doc "Validates an idempotency key; `:ok` or a typed `{:error, reason}`."
  @spec validate_key(term()) :: :ok | {:error, :not_a_string | :invalid_key}
  def validate_key(key) when is_binary(key) do
    if Regex.match?(@key_pattern, key), do: :ok, else: {:error, :invalid_key}
  end

  def validate_key(_other), do: {:error, :not_a_string}

  @doc "True when `validate_key/1` returns `:ok`."
  @spec valid_key?(term()) :: boolean()
  def valid_key?(key), do: validate_key(key) == :ok

  @doc """
  Deterministically derives a key from the action identity and command
  identity, so a retry of the same command re-derives the same key.
  """
  @spec derive_key(String.t(), String.t()) :: String.t()
  def derive_key(action_id, command_id) when is_binary(action_id) and is_binary(command_id) do
    "ik_" <> CanonicalJSON.sha256_hex(%{"actionId" => action_id, "commandId" => command_id})
  end

  @doc """
  Canonical request digest binding the action identity to its admitted input.
  """
  @spec request_digest(String.t(), term()) :: {:ok, String.t()} | {:error, term()}
  def request_digest(action_id, input) when is_binary(action_id) do
    with :ok <- portable(input, []) do
      {:ok, CanonicalJSON.sha256_hex(%{"actionId" => action_id, "input" => input})}
    end
  end

  @doc "Decides what a request bearing `key` and `digest` is against `state`."
  @spec admit(String.t(), String.t(), state()) :: admission()
  def admit(key, digest, state) when is_binary(key) and is_binary(digest) and is_map(state) do
    case Map.fetch(state, key) do
      :error -> :first
      {:ok, %{digest: recorded}} when recorded != digest -> {:conflict, :digest_mismatch}
      {:ok, %{outcome: :pending}} -> {:conflict, :in_flight}
      {:ok, %{outcome: {:done, outcome}}} -> {:replay, outcome}
    end
  end

  @doc "Reserves a first-seen key as in flight; refuses anything but `:first`."
  @spec reserve(String.t(), String.t(), state()) ::
          {:ok, state()} | {:error, {:not_first, admission()}}
  def reserve(key, digest, state) do
    case admit(key, digest, state) do
      :first -> {:ok, Map.put(state, key, %{digest: digest, outcome: :pending})}
      other -> {:error, {:not_first, other}}
    end
  end

  @doc "Records the outcome of a reserved key (exactly once)."
  @spec complete(String.t(), String.t(), term(), state()) ::
          {:ok, state()} | {:error, :not_reserved | :digest_mismatch | :already_completed}
  def complete(key, digest, outcome, state) do
    case Map.fetch(state, key) do
      :error -> {:error, :not_reserved}
      {:ok, %{digest: recorded}} when recorded != digest -> {:error, :digest_mismatch}
      {:ok, %{outcome: {:done, _}}} -> {:error, :already_completed}
      {:ok, entry} -> {:ok, Map.put(state, key, %{entry | outcome: {:done, outcome}})}
    end
  end

  defp portable(nil, _path), do: :ok
  defp portable(bool, _path) when is_boolean(bool), do: :ok

  defp portable(int, _path) when is_integer(int) and abs(int) <= @max_safe_integer, do: :ok

  defp portable(int, path) when is_integer(int),
    do: {:error, {:unsafe_integer, Enum.reverse(path)}}

  defp portable(str, path) when is_binary(str) do
    if String.valid?(str), do: :ok, else: {:error, {:invalid_utf8, Enum.reverse(path)}}
  end

  defp portable(list, path) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {item, index}, :ok ->
      case portable(item, [index | path]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp portable(map, path) when is_map(map) and not is_struct(map) do
    Enum.reduce_while(map, :ok, fn
      {key, value}, :ok when is_binary(key) ->
        with :ok <- portable(key, [key | path]),
             :ok <- portable(value, [key | path]) do
          {:cont, :ok}
        else
          error -> {:halt, error}
        end

      {_key, _value}, :ok ->
        {:halt, {:error, {:non_string_key, Enum.reverse(path)}}}
    end)
  end

  defp portable(_other, path), do: {:error, {:not_portable, Enum.reverse(path)}}
end
