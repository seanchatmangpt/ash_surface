defmodule AshSurface.HumanSurfaceTest do
  use ExUnit.Case, async: true

  alias AshSurface.{
    CommitmentBoundary,
    DevotionalEpisode,
    HumanSurface,
    Journey,
    OutcomeHypothesis,
    Possibility,
    PossibilitySet,
    WhyThis
  }

  defp fixture do
    hypothesis =
      OutcomeHypothesis.create(
        "person:demo",
        "practice:devotional:perseverance",
        "outcome:consistency",
        relationship: :MAY_SUPPORT,
        evidence_state: :UNKNOWN,
        horizon: "7d",
        falsifier: "Repeated completion is not followed by higher self-reported consistency."
      )

    why =
      WhyThis.create(
        "practice:devotional:perseverance",
        "Why this may matter today",
        "This practice may be relevant to the consistency outcome you chose to track.",
        claim_kind: :HYPOTHESIS,
        evidence_state: :UNKNOWN,
        falsifier: "The practice shows no repeated relationship with the selected outcome.",
        basis: ["user-selected outcome: consistency", "passage theme: perseverance"],
        caveats: ["This is a candidate relationship, not a causal claim."],
        profile_refs: ["profile:goal:consistency"],
        hypothesis_refs: [hypothesis.hypothesis_id]
      )

    devotional =
      DevotionalEpisode.create(
        "Perseverance when progress feels slow",
        [
          %{
            kind: :SCRIPTURE,
            ref: "bible:James.1.2-8",
            label: "James 1:2-8",
            duration_seconds: 180
          },
          %{kind: :TRANSITION, ref: "transition:1", label: "Next reading", duration_seconds: 5},
          %{
            kind: :SCRIPTURE,
            ref: "bible:Romans.5.1-5",
            label: "Romans 5:1-5",
            duration_seconds: 140
          },
          %{
            kind: :REFLECTION,
            ref: "reflection:perseverance",
            label: "Reflection",
            duration_seconds: 120
          }
        ],
        why_this_ref: why.explanation_id,
        hypothesis_refs: [hypothesis.hypothesis_id],
        source_refs: ["source:bible"]
      )

    devotional_option =
      Possibility.create(
        "person:demo",
        "capability:listen_devotional",
        "Listen to today's devotional",
        summary: "One uninterrupted devotional episode",
        action_ref: "Zoela.Devotional#start",
        why_this_ref: why.explanation_id,
        reversibility: :REVERSIBLE,
        cost_summary: "7 minutes",
        consequence_summary: "Starts local playback; no external commitment",
        requirements: ["audio-capable client"]
      )

    serve_option =
      Possibility.create(
        "person:demo",
        "capability:serve",
        "Explore serving this week",
        summary: "Review currently admitted service opportunities",
        action_ref: "Zoela.Service#explore",
        reversibility: :REVERSIBLE,
        consequence_summary: "No roster mutation until a later confirmed commitment boundary"
      )

    possibilities =
      PossibilitySet.create(
        "person:demo",
        "Choose a useful next practice without collapsing alternatives",
        [devotional_option, serve_option],
        horizon: "today",
        source_episode_refs: ["planner:episode:demo"],
        standing: :ALIVE
      )

    commitment =
      CommitmentBoundary.create(
        "person:demo",
        "Zoela.Service#volunteer",
        "Confirming expresses intent to volunteer and hands the request to BRCE.",
        reversibility: :CONDITIONAL,
        confirmation_state: :UNCONFIRMED,
        why_this_ref: why.explanation_id,
        external_effects: [
          "team may be notified after authorized DO",
          "roster may change after authorized DO"
        ]
      )

    journey =
      Journey.create(
        "person:demo",
        [
          %{
            kind: :PRACTICE,
            subject_ref: devotional.episode_id,
            label: "Completed perseverance devotional",
            occurred_at: "2026-09-21T18:00:00Z",
            receipt_ref: "receipt:devotional:001"
          },
          %{
            kind: :REFLECTION,
            subject_ref: "reflection:perseverance",
            label: "Saved reflection",
            occurred_at: "2026-09-21T18:05:00Z",
            evidence_refs: ["evidence:reflection:001"]
          }
        ],
        standing: :ALIVE,
        receipt_refs: ["receipt:devotional:001"]
      )

    %{
      hypothesis: hypothesis,
      why: why,
      devotional: devotional,
      devotional_option: devotional_option,
      serve_option: serve_option,
      possibilities: possibilities,
      commitment: commitment,
      journey: journey
    }
  end

  test "DfCM possibility set preserves a plural reversible frontier deterministically" do
    f = fixture()

    reversed =
      PossibilitySet.create(
        "person:demo",
        "Choose a useful next practice without collapsing alternatives",
        [f.serve_option, f.devotional_option],
        horizon: "today",
        source_episode_refs: ["planner:episode:demo"],
        standing: :ALIVE
      )

    assert length(f.possibilities.possibilities) == 2
    assert f.possibilities.mode == :MAXIMAL_REVERSIBLE_FRONTIER
    assert f.possibilities.state_digest == reversed.state_digest
    assert f.possibilities.authority_boundary == :OBSERVE
    refute f.possibilities.do_authority
  end

  test "ALIVE possibility set cannot manufacture an empty frontier" do
    assert_raise ArgumentError, ~r/at least one option/, fn ->
      PossibilitySet.create("person:demo", "objective", [], standing: :ALIVE)
    end
  end

  test "possibility identities must remain unique inside one frontier" do
    f = fixture()

    assert_raise ArgumentError, ~r/unique/, fn ->
      PossibilitySet.create(
        "person:demo",
        "objective",
        [f.devotional_option, f.devotional_option]
      )
    end
  end

  test "WhyThis refuses an unfalsifiable hypothesis" do
    assert_raise ArgumentError, ~r/requires a falsifier/, fn ->
      WhyThis.create("practice:x", "Why", "Maybe useful", claim_kind: :HYPOTHESIS)
    end
  end

  test "outcome hypothesis never becomes a causal claim in the surface" do
    f = fixture()
    map = OutcomeHypothesis.to_map(f.hypothesis)

    assert map["relationship"] == "MAY_SUPPORT"
    assert map["evidenceState"] == "UNKNOWN"
    assert map["causalClaim"] == false
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["doAuthority"] == false
  end

  test "devotional episode is an ordered straight-through audio program" do
    f = fixture()
    map = DevotionalEpisode.to_map(f.devotional)

    assert map["continuousPlay"] == true
    assert map["playbackPolicy"] == "STRAIGHT_THROUGH"
    assert map["durationSeconds"] == 445

    assert Enum.map(map["segments"], & &1["position"]) == [0, 1, 2, 3]

    assert Enum.map(map["segments"], & &1["ref"]) == [
             "bible:James.1.2-8",
             "transition:1",
             "bible:Romans.5.1-5",
             "reflection:perseverance"
           ]
  end

  test "completed devotional requires a receipt rather than inferred completion" do
    assert_raise ArgumentError, ~r/completion_receipt_ref/, fn ->
      DevotionalEpisode.create(
        "done",
        [%{kind: :SCRIPTURE, ref: "bible:James.1", duration_seconds: 1}],
        status: :COMPLETED
      )
    end
  end

  test "confirmed commitment remains intent-only and hands consequence to BRCE" do
    confirmed =
      CommitmentBoundary.create(
        "person:demo",
        "Zoela.Service#volunteer",
        "Notify the team and mutate the roster only after authorized DO.",
        confirmation_state: :CONFIRMED
      )

    map = CommitmentBoundary.to_map(confirmed)

    assert map["confirmationState"] == "CONFIRMED"
    assert map["nextHandoff"] == "BRCE"
    assert map["authorityCeiling"] == "CONSTRUCT"
    assert map["doAuthority"] == false
  end

  test "journey is subject-private receipt/evidence replay, not outcome manufacture" do
    f = fixture()
    map = Journey.to_map(f.journey)

    assert map["privacyScope"] == "SUBJECT_PRIVATE"
    assert map["standing"] == "ALIVE"
    assert map["receiptRefs"] == ["receipt:devotional:001"]
    assert map["authorityBoundary"] == "OBSERVE"
    refute map["doAuthority"]
  end

  test "human surface composes TODAY BIBLE LIFE ZOE YOU without gaining authority" do
    f = fixture()

    surface =
      HumanSurface.create(
        "person:demo",
        possibility_sets: [f.possibilities],
        explanations: [f.why],
        devotional_episodes: [f.devotional],
        outcome_hypotheses: [f.hypothesis],
        commitment_boundaries: [f.commitment],
        journeys: [f.journey],
        receipt_refs: ["receipt:devotional:001"],
        standing: :ALIVE
      )

    map = HumanSurface.to_map(surface)

    assert map["grammar"] == ["SEE", "UNDERSTAND", "EXPLORE", "CHOOSE", "ACT", "LEARN"]
    assert map["areas"] == ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"]
    assert map["today"]["devotionalEpisodeRefs"] == [f.devotional.episode_id]
    assert map["bible"]["devotionalEpisodeRefs"] == [f.devotional.episode_id]
    assert map["life"]["outcomeHypothesisRefs"] == [f.hypothesis.hypothesis_id]
    assert map["zoe"]["commitmentBoundaryRefs"] == [f.commitment.boundary_id]
    assert map["you"]["journeyRefs"] == [f.journey.journey_id]
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["doAuthority"] == false
  end
end
