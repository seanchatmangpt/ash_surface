defmodule AshSurface.Digest do
  @moduledoc """
  The repo's one content-addressing law (ERRC consolidation, lane W11).

  Four private, byte-identical copies of the frozen AshSurface canon —
  recursively string-keyed, key-sorted map terms, semantic list order,
  `:erlang.term_to_binary/1`, SHA-256, lowercase hex — existed in
  `AshSurface` (lib/ash_surface.ex), `AshSurface.Compiler`,
  `AshSurface.Health` (as `content_digest/1`), and `AshSurface.IR.Codec`
  (whose own header admitted it was "mirrored only because the upstream
  function is private"). The canon is moved here verbatim, byte-for-byte:
  every existing digest value is unchanged.

  A second, deliberately different canon — `:erlang.term_to_binary/2` with
  `[:deterministic]` over the term as-is (no key canonicalization) — was
  privately duplicated in `AshSurface.Obligation` and
  `AshSurface.CommandCenter`; it is consolidated here as
  `deterministic_term_digest/1` without unifying it with `content_digest/1`:
  the two produce different bytes and are pinned independently by their
  respective suites.
  """

  @doc """
  The frozen AshSurface content canon: recursively string-keyed, key-sorted
  map terms; list order preserved; SHA-256 of `:erlang.term_to_binary/1`
  bytes as lowercase hex.
  """
  @spec content_digest(term()) :: String.t()
  def content_digest(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc """
  SHA-256 of `:erlang.term_to_binary/2` with `[:deterministic]` over the
  term as-is — no key canonicalization, no JSON staging. Used for state
  digests of already-normalized records (obligations, command centers).
  """
  @spec deterministic_term_digest(term()) :: String.t()
  def deterministic_term_digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical_term(term) when is_list(term), do: Enum.map(term, &canonical_term/1)
  defp canonical_term(term), do: term
end
