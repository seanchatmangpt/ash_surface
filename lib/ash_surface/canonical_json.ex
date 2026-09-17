defmodule AshSurface.CanonicalJSON do
  @moduledoc """
  The repo's one canonical-JSON encoding law (finish-replay-020).

  Promoted verbatim from the determinism suite's test double
  (`AshSurface.ProjectorIRDeterminism.IR.to_canonical_json/1`): maps encode as
  recursively string-keyed, key-SORTED JSON objects; list order is semantic and
  preserved; scalars encode verbatim through `Jason`. Two structurally equal
  maps therefore always encode to identical bytes, independent of construction
  history (flatmap or >32-key HAMT iteration order can never leak into a
  digest).

  Consumers:

    * `AshSurface.Event.create/4` and `AshSurface.Observation.create/3` —
      state digests hash the canonical encoding, so event/observation identity
      is map-order invariant (previously raw `Jason.encode!`, which leaked
      HAMT iteration order for >32-key payloads);
    * receipt-hash re-derivation — the JavaScript runtime twins mint
      `receiptHash` over the same law (`canonicalStringify` in
      `test/js/consumer_e2e_runner.mjs`); agreement is pinned by the e2e and
      MX closed-loop suites.

  Non-JSON-encodable scalars raise through `Jason` exactly as before: this
  module owns the canonical BYTES law, not input admission.
  """

  @doc """
  Encodes a term to canonical JSON bytes: recursively string-keyed, key-sorted
  map pairs, order-preserving lists, verbatim `Jason` scalars.
  """
  @spec encode(term()) :: String.t()
  def encode(map) when is_map(map) do
    pairs =
      map
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.sort_by(fn {key, _value} -> key end)

    "{" <>
      Enum.map_join(pairs, ",", fn {key, value} ->
        Jason.encode!(key) <> ":" <> encode(value)
      end) <> "}"
  end

  def encode(list) when is_list(list) do
    "[" <> Enum.map_join(list, ",", &encode/1) <> "]"
  end

  def encode(scalar), do: Jason.encode!(scalar)

  @doc """
  SHA-256 of `encode/1` as lowercase hex — the digest form used for
  content-addressing (e.g. runtime receipt-hash re-derivation).
  """
  @spec sha256_hex(term()) :: String.t()
  def sha256_hex(term) do
    :crypto.hash(:sha256, encode(term)) |> Base.encode16(case: :lower)
  end
end
