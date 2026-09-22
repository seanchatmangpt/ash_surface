defmodule AshSurface.PossibilitySet do
  @moduledoc """
  DfCM projection of the lawful reversible frontier available to a human.

  The set preserves plural options. Selection is represented only by a reference
  manufactured elsewhere; this module cannot collapse the frontier or dispatch.
  """

  alias AshSurface.Possibility

  @standings [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]

  @enforce_keys [
    :set_id,
    :exact_subject,
    :objective,
    :possibilities,
    :state_digest
  ]

  defstruct [
    :set_id,
    :exact_subject,
    :objective,
    :horizon,
    :selection_ref,
    :closure_reason,
    :state_digest,
    possibilities: [],
    constraints: [],
    source_episode_refs: [],
    evidence_refs: [],
    standing: :PARTIAL_ALIVE,
    mode: :MAXIMAL_REVERSIBLE_FRONTIER,
    authority_boundary: :OBSERVE,
    do_authority: false
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), String.t(), [Possibility.t()], keyword()) :: t()
  def create(exact_subject, objective, possibilities, opts \\ [])
      when is_binary(exact_subject) and is_binary(objective) and is_list(possibilities) do
    unless Enum.all?(possibilities, &match?(%Possibility{}, &1)),
      do: raise(ArgumentError, "possibilities must contain only AshSurface.Possibility values")

    ids = Enum.map(possibilities, & &1.possibility_id)

    if length(ids) != length(Enum.uniq(ids)),
      do: raise(ArgumentError, "possibility ids must be unique")

    standing = Keyword.get(opts, :standing, :PARTIAL_ALIVE)

    unless standing in @standings,
      do: raise(ArgumentError, "unknown standing: #{inspect(standing)}")

    if standing == :ALIVE and possibilities == [],
      do: raise(ArgumentError, "ALIVE possibility set must preserve at least one option")

    constraints = Keyword.get(opts, :constraints, [])
    source_episode_refs = Keyword.get(opts, :source_episode_refs, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])

    Enum.each(
      [
        constraints: constraints,
        source_episode_refs: source_episode_refs,
        evidence_refs: evidence_refs
      ],
      fn {field, values} -> validate_string_list!(values, field) end
    )

    canonical = %{
      exact_subject: exact_subject,
      objective: objective,
      horizon: Keyword.get(opts, :horizon),
      selection_ref: Keyword.get(opts, :selection_ref),
      closure_reason: Keyword.get(opts, :closure_reason),
      possibilities:
        possibilities
        |> Enum.map(&Possibility.to_map/1)
        |> Enum.sort_by(& &1["possibilityId"]),
      constraints: Enum.sort(constraints),
      source_episode_refs: Enum.sort(source_episode_refs),
      evidence_refs: Enum.sort(evidence_refs),
      standing: standing
    }

    state_digest = digest({"ash_surface_possibility_set/1", canonical})

    %__MODULE__{
      set_id: "ps_" <> binary_part(state_digest, 0, 16),
      exact_subject: exact_subject,
      objective: objective,
      horizon: canonical.horizon,
      selection_ref: canonical.selection_ref,
      closure_reason: canonical.closure_reason,
      possibilities: possibilities,
      constraints: constraints,
      source_episode_refs: source_episode_refs,
      evidence_refs: evidence_refs,
      standing: standing,
      state_digest: state_digest
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "setId" => value.set_id,
      "exactSubject" => value.exact_subject,
      "objective" => value.objective,
      "horizon" => value.horizon,
      "selectionRef" => value.selection_ref,
      "closureReason" => value.closure_reason,
      "possibilities" => Enum.map(value.possibilities, &Possibility.to_map/1),
      "constraints" => value.constraints,
      "sourceEpisodeRefs" => value.source_episode_refs,
      "evidenceRefs" => value.evidence_refs,
      "standing" => Atom.to_string(value.standing),
      "mode" => Atom.to_string(value.mode),
      "stateDigest" => value.state_digest,
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
  end

  defp validate_string_list!(values, field) when is_list(values) do
    unless Enum.all?(values, &is_binary/1),
      do: raise(ArgumentError, "#{field} must contain only strings")
  end

  defp validate_string_list!(_, field), do: raise(ArgumentError, "#{field} must be a list")

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
