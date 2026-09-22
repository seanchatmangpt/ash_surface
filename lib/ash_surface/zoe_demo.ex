defmodule AshSurface.ZoeDemo do
  @moduledoc """
  Deterministic Wednesday-demo fixture for the ZOE human surface.

  This is synthetic demonstration state. It intentionally does not claim live
  Planning Center reads, member profile truth, devotional outcome evidence,
  roster mutation, or production standing.
  """

  alias AshSurface.{
    CommitmentBoundary,
    DevotionalEpisode,
    HumanSurface,
    Journey,
    ManufactureTrace,
    OutcomeHypothesis,
    PersonalizationContext,
    Possibility,
    PossibilitySet,
    WhyThis
  }

  @subject "zoe:demo-member"
  @demo_time "2026-09-23T19:00:00-07:00"

  @spec surface() :: HumanSurface.t()
  def surface do
    personalization =
      PersonalizationContext.create(
        @subject,
        [
          %{
            dimension: "life:outcome",
            value_ref: "life:outcome:consistency",
            source: :USER_STATED,
            standing: :ALIVE,
            evidence_refs: ["demo-evidence:synthetic-profile"]
          }
        ],
        consent_ref: "demo-consent:subject-only",
        evidence_refs: ["demo-evidence:synthetic-profile"],
        standing: :ALIVE
      )

    manufacture_trace =
      ManufactureTrace.create(
        @subject,
        "practice:devotional:perseverance",
        "zoe:personalization:semantic-map",
        observed_refs: ["demo-o:consistency-perseverance"],
        admitted_refs: ["demo-o:consistency-perseverance"],
        grounded_refs: ["demo-o:consistency-perseverance"],
        bounded_refs: ["demo-o:consistency-perseverance"],
        aligned_refs: ["demo-o:consistency-perseverance"],
        o_star_refs: ["demo-o:consistency-perseverance"],
        receipt_refs: ["demo-receipt:manufacture:001"],
        falsifiers: [
          "The profile facet is withdrawn or no longer admitted.",
          "The devotional semantics no longer include the mapped perseverance concept."
        ],
        human_summary:
          "The candidate was manufactured from the admitted demo goal and devotional semantics.",
        standing: :ALIVE
      )

    hypothesis =
      OutcomeHypothesis.create(
        @subject,
        "practice:devotional:perseverance",
        "life:outcome:consistency",
        relationship: :MAY_SUPPORT,
        evidence_state: :UNKNOWN,
        horizon: "7d",
        falsifier:
          "Across repeated observations, devotional completion does not precede improvement in the member-selected consistency measure."
      )

    why =
      WhyThis.create(
        "practice:devotional:perseverance",
        "Why this may matter today",
        "This devotional may be relevant to the consistency outcome selected in the demo profile.",
        claim_kind: :HYPOTHESIS,
        evidence_state: :UNKNOWN,
        falsifier:
          "No repeated association appears between this practice and the selected outcome.",
        basis: [
          "demo profile selects consistency as an outcome",
          "devotional passage theme is perseverance"
        ],
        caveats: [
          "synthetic demo profile",
          "candidate relevance only",
          "no causal effect has been admitted"
        ],
        profile_refs: [personalization.context_id],
        evidence_refs: manufacture_trace.receipt_refs,
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
            duration_seconds: 180,
            audio_ref: "demo-audio:James.1.2-8"
          },
          %{
            kind: :TRANSITION,
            ref: "transition:james-romans",
            label: "Continue",
            duration_seconds: 5
          },
          %{
            kind: :SCRIPTURE,
            ref: "bible:Romans.5.1-5",
            label: "Romans 5:1-5",
            duration_seconds: 140,
            audio_ref: "demo-audio:Romans.5.1-5"
          },
          %{
            kind: :REFLECTION,
            ref: "reflection:perseverance",
            label: "Reflection",
            duration_seconds: 120,
            audio_ref: "demo-audio:reflection:perseverance"
          }
        ],
        subtitle: "7 minutes · straight through",
        why_this_ref: why.explanation_id,
        hypothesis_refs: [hypothesis.hypothesis_id],
        source_refs: ["demo-source:bible-content"]
      )

    listen =
      Possibility.create(
        @subject,
        "zoe:capability:listen-devotional",
        "Listen to today's devotional",
        summary: "Play all readings and reflection in one uninterrupted episode.",
        action_ref: "Zoela.Devotional#start",
        why_this_ref: why.explanation_id,
        reversibility: :REVERSIBLE,
        cost_summary: "About 7 minutes",
        consequence_summary: "Begins client playback; no external organizational mutation.",
        requirements: ["audio-capable client"]
      )

    read =
      Possibility.create(
        @subject,
        "zoe:capability:read-devotional",
        "Read instead",
        summary: "Open the same episode as an ordered reading sequence.",
        action_ref: "Zoela.Devotional#read",
        why_this_ref: why.explanation_id,
        reversibility: :REVERSIBLE,
        cost_summary: "Self-paced",
        consequence_summary: "Opens local reading surface; no external mutation."
      )

    serve =
      Possibility.create(
        @subject,
        "zoe:capability:explore-serving",
        "Explore serving this week",
        summary: "See currently admitted service possibilities without joining a roster.",
        action_ref: "Zoela.Service#explore",
        reversibility: :REVERSIBLE,
        consequence_summary: "No roster or team notification occurs during exploration."
      )

    continue_current =
      Possibility.create(
        @subject,
        "zoe:capability:continue-current-rhythm",
        "Keep my current rhythm",
        summary: "Preserve the option to make no new commitment today.",
        reversibility: :REVERSIBLE,
        consequence_summary: "No new consequence."
      )

    frontier =
      PossibilitySet.create(
        @subject,
        "Choose a useful next practice while preserving lawful alternatives",
        [listen, read, serve, continue_current],
        horizon: "today",
        source_episode_refs: ["demo-planner:episode:2026-09-23"],
        evidence_refs: ["demo-evidence:synthetic-only"],
        standing: :ALIVE
      )

    service_boundary =
      CommitmentBoundary.create(
        @subject,
        "Zoela.Service#volunteer",
        "If confirmed, the intent may be handed to BRCE; only an authorized DO may notify the team or change a roster.",
        reversibility: :CONDITIONAL,
        confirmation_state: :UNCONFIRMED,
        why_this_ref: why.explanation_id,
        external_effects: [
          "team notification after authorized DO",
          "roster mutation after authorized DO"
        ],
        evidence_refs: ["demo-evidence:synthetic-only"]
      )

    journey =
      Journey.create(
        @subject,
        [
          %{
            kind: :ATTENDANCE,
            subject_ref: "zoe:service:demo-sunday",
            label: "Sunday service attendance — demo receipt",
            occurred_at: "2026-09-20T12:00:00-07:00",
            receipt_ref: "demo-receipt:attendance:001"
          },
          %{
            kind: :PRACTICE,
            subject_ref: "practice:devotional:demo-prior",
            label: "Prior devotional — demo receipt",
            occurred_at: "2026-09-21T08:00:00-07:00",
            receipt_ref: "demo-receipt:devotional:001"
          },
          %{
            kind: :REFLECTION,
            subject_ref: "reflection:demo-prior",
            label: "Reflection saved — demo evidence",
            occurred_at: "2026-09-21T08:08:00-07:00",
            evidence_refs: ["demo-evidence:reflection:001"]
          }
        ],
        standing: :ALIVE,
        evidence_refs: ["demo-evidence:synthetic-only"],
        receipt_refs: ["demo-receipt:attendance:001", "demo-receipt:devotional:001"]
      )

    HumanSurface.create(
      @subject,
      possibility_sets: [frontier],
      explanations: [why],
      devotional_episodes: [devotional],
      outcome_hypotheses: [hypothesis],
      commitment_boundaries: [service_boundary],
      journeys: [journey],
      personalization_contexts: [personalization],
      manufacture_traces: [manufacture_trace],
      today: %{
        "headline" => "Today",
        "asOf" => @demo_time,
        "possibilitySetRefs" => [frontier.set_id],
        "explanationRefs" => [why.explanation_id],
        "devotionalEpisodeRefs" => [devotional.episode_id]
      },
      bible: %{
        "headline" => "Bible",
        "devotionalEpisodeRefs" => [devotional.episode_id],
        "continuousPlayAvailable" => true
      },
      life: %{
        "headline" => "Life",
        "selectedOutcomeRefs" => ["life:outcome:consistency"],
        "outcomeHypothesisRefs" => [hypothesis.hypothesis_id],
        "personalizationContextRefs" => [personalization.context_id],
        "manufactureTraceRefs" => [manufacture_trace.trace_id],
        "causalClaimsAdmitted" => false
      },
      zoe: %{
        "headline" => "ZOE",
        "possibilitySetRefs" => [frontier.set_id],
        "commitmentBoundaryRefs" => [service_boundary.boundary_id],
        "liveProviderReads" => false
      },
      you: %{
        "headline" => "You",
        "journeyRefs" => [journey.journey_id],
        "privacyScope" => "SUBJECT_PRIVATE"
      },
      evidence_refs: ["demo-evidence:synthetic-only"],
      receipt_refs: ["demo-receipt:attendance:001", "demo-receipt:devotional:001"],
      standing: :ALIVE
    )
  end

  @spec map() :: map()
  def map, do: surface() |> HumanSurface.to_map()

  @spec acceptance() :: map()
  def acceptance do
    value = map()

    %{
      "continuousDevotional" => get_in(value, ["bible", "continuousPlayAvailable"]) == true,
      "pluralDfcmFrontier" =>
        value["possibilitySets"]
        |> List.first()
        |> Map.fetch!("possibilities")
        |> length() > 1,
      "whyThisPresent" => value["explanations"] != [],
      "outcomeHypothesisNonCausal" =>
        Enum.all?(value["outcomeHypotheses"], &(&1["causalClaim"] == false)),
      "commitmentStopsBeforeDo" =>
        Enum.all?(
          value["commitmentBoundaries"],
          &(&1["nextHandoff"] == "BRCE" and &1["doAuthority"] == false)
        ),
      "journeyPrivate" =>
        Enum.all?(value["journeys"], &(&1["privacyScope"] == "SUBJECT_PRIVATE")),
      "personalizationBounded" =>
        Enum.all?(
          value["personalizationContexts"],
          &(&1["privacyScope"] == "SUBJECT_PRIVATE" and &1["shareScope"] == "SUBJECT_ONLY")
        ),
      "manufactureReceipted" =>
        Enum.all?(
          value["manufactureTraces"],
          &(&1["equation"] == "A=mu(O*)" and &1["receiptRefs"] != [])
        ),
      "humanAreas" => value["areas"] == ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"],
      "syntheticOnly" => true
    }
  end
end
