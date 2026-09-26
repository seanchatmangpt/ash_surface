defmodule AshSurface.Standing do
  @moduledoc """
  The single canonical owner of the standing vocabulary (F3, _SYNTHESIS.md).

  Every projection that carries a `standing` names this module as its
  vocabulary owner. The admitted base standings are:

    * `:ALIVE` — observed execution against the exact subject with the
      required verifier, in this session (`inspection != execution`).
    * `:PARTIAL_ALIVE` — verified for part of the subject, not all of it.
    * `:BLOCKED` — an admission gate refused progress; the blocker is named.
    * `:BUILD_BROKEN` — the tree does not compile/gate green.
    * `:UNSUPPORTED` — no admitted pack/generator expresses the element
      (ledger-backed).

  plus the REFUSED class: every `:"REFUSED_*"` atom (e.g. `:REFUSED_NO_AUTHORITY`,
  `:REFUSED_UNKNOWN_ACTION`). A refusal is a valid successful outcome, never a
  standing to be ashamed of — and it must name its reason: bare `:REFUSED` is
  NOT admitted, because an unnamed refusal is a fabricated refusal.

  `:UNKNOWN` is deliberately NOT a standing. Post-dispatch timeout/disconnect
  is `UNKNOWN_AFTER_DISPATCH`, a transport outcome — it is not, and must never
  be widened into, a verified standing. `validate!/1` refuses `:UNKNOWN` with
  an `ArgumentError` that names it as a post-dispatch outcome.

  The JavaScript projection mirrors this exact vocabulary in
  `priv/static/ash_surface_runtime.mjs` (`STANDING_VALUES` plus the
  `REFUSED_` prefix class). Changing either side is a cross-language contract
  change and must land on both.
  """

  @base_standings [:ALIVE, :PARTIAL_ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]

  @type base :: :ALIVE | :PARTIAL_ALIVE | :BLOCKED | :BUILD_BROKEN | :UNSUPPORTED

  # The REFUSED class: every `:"REFUSED_*"` atom. Bare `:REFUSED` is not a
  # member — a refusal must name its reason. A spec-level union over an open
  # atom family is not expressible, so the class is typed as atom() here and
  # enforced at runtime by `valid?/1` and `validate!/1`.
  @type refused :: atom()

  @type t :: base() | refused()

  @doc "Returns the admitted base standings (the REFUSED class is open-prefixed)."
  @spec base_standings :: [base(), ...]
  def base_standings, do: @base_standings

  @doc """
  Returns true exactly when `standing` is an admitted standing: a base
  member, or a `:"REFUSED_*"` atom (bare `:REFUSED` is not a standing —
  a refusal must name its reason).

  ## Examples

      iex> AshSurface.Standing.valid?(:ALIVE)
      true

      iex> AshSurface.Standing.valid?(:REFUSED_NO_AUTHORITY)
      true

      iex> AshSurface.Standing.valid?(:REFUSED)
      false

      iex> AshSurface.Standing.valid?(:BOGUS)
      false

      iex> AshSurface.Standing.valid?(:UNKNOWN)
      false

      iex> AshSurface.Standing.valid?("ALIVE")
      false
  """
  @spec valid?(term()) :: boolean()
  def valid?(standing) when standing in @base_standings, do: true

  def valid?(standing) when is_atom(standing) do
    case Atom.to_string(standing) do
      "REFUSED_" <> _ -> true
      _ -> false
    end
  end

  def valid?(_standing), do: false

  @doc """
  Returns true when `standing` is an admitted REFUSED-class standing
  (a `:"REFUSED_*"` atom naming its reason). Bare `:REFUSED` is not a
  refusal — an unnamed refusal is a fabricated refusal. Base members are
  not refusals.
  """
  @spec refused?(term()) :: boolean()
  def refused?(standing), do: valid?(standing) and standing not in @base_standings

  @doc """
  Validates `standing` as an admitted standing and returns it, or raises
  `ArgumentError` naming the offender and the admitted vocabulary.

  `:UNKNOWN` gets a dedicated refusal that names it as a post-dispatch
  outcome (`UNKNOWN_AFTER_DISPATCH`): post-dispatch timeout/disconnect is a
  transport outcome, never a verified standing.

  Constructors that carry a standing MUST route the caller-supplied value
  through this check — a standing is an evidence claim, and an unvalidated
  claim is a fabricated one.

  ## Examples

      iex> AshSurface.Standing.validate!(:PARTIAL_ALIVE)
      :PARTIAL_ALIVE

      iex> AshSurface.Standing.validate!(:REFUSED_UNKNOWN_SUBJECT)
      :REFUSED_UNKNOWN_SUBJECT
  """
  @spec validate!(term()) :: t()
  def validate!(:UNKNOWN) do
    raise ArgumentError,
          "invalid standing :UNKNOWN; UNKNOWN is a post-dispatch outcome " <>
            "(recorded as UNKNOWN_AFTER_DISPATCH, a transport outcome), never a " <>
            "verified standing; admitted standings are #{inspect(@base_standings)} " <>
            "plus the REFUSED class (every :\"REFUSED_*\" atom)"
  end

  def validate!(standing) do
    if valid?(standing) do
      standing
    else
      raise ArgumentError,
            "invalid standing #{inspect(standing)}; admitted standings are " <>
              "#{inspect(@base_standings)} plus the REFUSED class (every " <>
              ":\"REFUSED_*\" atom — a refusal must name its reason)"
    end
  end
end
