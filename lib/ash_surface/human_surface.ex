defmodule AshSurface.HumanSurface do
  @moduledoc """
  Human projection of admitted ecosystem state.

  The surface composes domain-specific projections into five stable areas:
  TODAY, BIBLE, LIFE, ZOE, and YOU. It owns no theology, planning, profile
  inference, organizational truth, or consequence authority.

  Human grammar:
    SEE -> UNDERSTAND -> EXPLORE -> CHOOSE -> ACT -> LEARN

  ACT means presenting the commitment boundary. Actual DO remains BRCE-owned.
  """

  alias AshSurface.{
    CommitmentBoundary,
    DevotionalEpisode,
    Journey,
    OutcomeHypothesis,
    PossibilitySet,
    WhyThis
  }

  @standings [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]
  @grammar [:SEE, :UNDERSTAND, :EXPLORE, :CHOOSE, :ACT, :LEARN]
  @areas [:TODAY, :BIBLE, :LIFE, :ZOE, :YOU]

  @enforce_keys [
    :surface_id,
    :exact_subject,
    :state_digest,
    :today,
    :bible,
    :life,
    :zoe,
    :you
  ]

  defstruct [
    :surface_id,
    :exact_subject,
    :state_digest,
    :today,
    :bible,
    :life,
    :zoe,
    :you,
    possibility_sets: [],
    explanations: [],
    devotional_episodes: [],
    outcome_hypotheses: [],
    commitment_boundaries: [],
    journeys: [],
    evidence_refs: [],
    receipt_refs: [],
    standing: :PARTIAL_ALIVE,
    grammar: @grammar,
    areas: @areas,
    authority_boundary: :OBSERVE,
    do_authority: false
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), keyword()) :: t()
  def create(exact_subject, opts \\ []) when is_binary(exact_subject) do
    possibility_sets = Keyword.get(opts, :possibility_sets, [])
    explanations = Keyword.get(opts, :explanations, [])
    devotional_episodes = Keyword.get(opts, :devotional_episodes, [])
    outcome_hypotheses = Keyword.get(opts, :outcome_hypotheses, [])
    commitment_boundaries = Keyword.get(opts, :commitment_boundaries, [])
    journeys = Keyword.get(opts, :journeys, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    receipt_refs = Keyword.get(opts, :receipt_refs, [])
    standing = Keyword.get(opts, :standing, :PARTIAL_ALIVE)

    validate_struct_list!(possibility_sets, PossibilitySet, :possibility_sets)
    validate_struct_list!(explanations, WhyThis, :explanations)
    validate_struct_list!(devotional_episodes, DevotionalEpisode, :devotional_episodes)
    validate_struct_list!(outcome_hypotheses, OutcomeHypothesis, :outcome_hypotheses)
    validate_struct_list!(commitment_boundaries, CommitmentBoundary, :commitment_boundaries)
    validate_struct_list!(journeys, Journey, :journeys)
    validate_string_list!(evidence_refs, :evidence_refs)
    validate_string_list!(receipt_refs, :receipt_refs)

    unless standing in @standings,
      do: raise(ArgumentError, "unknown standing: #{inspect(standing)}")

    today =
      Keyword.get(opts, :today, %{
        "possibilitySetRefs" => Enum.map(possibility_sets, & &1.set_id),
        "explanationRefs" => Enum.map(explanations, & &1.explanation_id),
        "devotionalEpisodeRefs" => Enum.map(devotional_episodes, & &1.episode_id)
      })

    bible =
      Keyword.get(opts, :bible, %{
        "devotionalEpisodeRefs" => Enum.map(devotional_episodes, & &1.episode_id)
      })

    life =
      Keyword.get(opts, :life, %{
        "outcomeHypothesisRefs" => Enum.map(outcome_hypotheses, & &1.hypothesis_id)
      })

    zoe =
      Keyword.get(opts, :zoe, %{
        "possibilitySetRefs" => Enum.map(possibility_sets, & &1.set_id),
        "commitmentBoundaryRefs" => Enum.map(commitment_boundaries, & &1.boundary_id)
      })

    you =
      Keyword.get(opts, :you, %{
        "journeyRefs" => Enum.map(journeys, & &1.journey_id)
      })

    Enum.each([today: today, bible: bible, life: life, zoe: zoe, you: you], fn {field, value} ->
      unless is_map(value), do: raise(ArgumentError, "#{field} must be a map")
    end)

    canonical = %{
      exact_subject: exact_subject,
      today: today,
      bible: bible,
      life: life,
      zoe: zoe,
      you: you,
      possibility_sets: canonicalize(possibility_sets, &PossibilitySet.to_map/1, "setId"),
      explanations: canonicalize(explanations, &WhyThis.to_map/1, "explanationId"),
      devotional_episodes:
        canonicalize(devotional_episodes, &DevotionalEpisode.to_map/1, "episodeId"),
      outcome_hypotheses:
        canonicalize(outcome_hypotheses, &OutcomeHypothesis.to_map/1, "hypothesisId"),
      commitment_boundaries:
        canonicalize(commitment_boundaries, &CommitmentBoundary.to_map/1, "boundaryId"),
      journeys: canonicalize(journeys, &Journey.to_map/1, "journeyId"),
      evidence_refs: Enum.sort(evidence_refs),
      receipt_refs: Enum.sort(receipt_refs),
      standing: standing,
      grammar: @grammar,
      areas: @areas
    }

    state_digest = digest({"ash_surface_human_surface/1", canonical})

    %__MODULE__{
      surface_id: "hs_" <> binary_part(state_digest, 0, 16),
      exact_subject: exact_subject,
      state_digest: state_digest,
      today: today,
      bible: bible,
      life: life,
      zoe: zoe,
      you: you,
      possibility_sets: possibility_sets,
      explanations: explanations,
      devotional_episodes: devotional_episodes,
      outcome_hypotheses: outcome_hypotheses,
      commitment_boundaries: commitment_boundaries,
      journeys: journeys,
      evidence_refs: evidence_refs,
      receipt_refs: receipt_refs,
      standing: standing
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "surfaceId" => value.surface_id,
      "exactSubject" => value.exact_subject,
      "stateDigest" => value.state_digest,
      "standing" => Atom.to_string(value.standing),
      "grammar" => Enum.map(value.grammar, &Atom.to_string/1),
      "areas" => Enum.map(value.areas, &Atom.to_string/1),
      "today" => value.today,
      "bible" => value.bible,
      "life" => value.life,
      "zoe" => value.zoe,
      "you" => value.you,
      "possibilitySets" => Enum.map(value.possibility_sets, &PossibilitySet.to_map/1),
      "explanations" => Enum.map(value.explanations, &WhyThis.to_map/1),
      "devotionalEpisodes" =>
        Enum.map(value.devotional_episodes, &DevotionalEpisode.to_map/1),
      "outcomeHypotheses" =>
        Enum.map(value.outcome_hypotheses, &OutcomeHypothesis.to_map/1),
      "commitmentBoundaries" =>
        Enum.map(value.commitment_boundaries, &CommitmentBoundary.to_map/1),
      "journeys" => Enum.map(value.journeys, &Journey.to_map/1),
      "evidenceRefs" => value.evidence_refs,
      "receiptRefs" => value.receipt_refs,
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
  end

  defp canonicalize(values, mapper, key) do
    values |> Enum.map(mapper) |> Enum.sort_by(& &1[key])
  end

  defp validate_struct_list!(values, module, field) when is_list(values) do
    unless Enum.all?(values, &match?(%{__struct__: ^module}, &1)),
      do: raise(ArgumentError, "#{field} must contain only #{inspect(module)} values")
  end

  defp validate_struct_list!(_, _module, field),
    do: raise(ArgumentError, "#{field} must be a list")

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
