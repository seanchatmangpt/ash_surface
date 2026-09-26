import test from "node:test";
import assert from "node:assert/strict";

import {
  commitmentBoundarySchema,
  devotionalEpisodeSchema,
  humanSurfaceSchema,
  outcomeHypothesisSchema,
  parseHumanSurfaceProjection,
  possibilitySetSchema,
  whyThisSchema,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

function fixture() {
  const hypothesis = {
    hypothesisId: "hyp_consistency",
    subjectRef: "person:demo",
    practiceRef: "practice:devotional:perseverance",
    outcomeRef: "outcome:consistency",
    relationship: "MAY_SUPPORT",
    evidenceState: "UNKNOWN",
    falsifier: "Repeated completion is not followed by higher consistency observations.",
    horizon: "7d",
    evidenceRefs: [],
    observationRefs: [],
    stateDigest: "digest-hypothesis",
    causalClaim: false,
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };

  const why = {
    explanationId: "why_perseverance",
    subjectRef: "practice:devotional:perseverance",
    title: "Why this may matter today",
    summary: "This may be relevant to the consistency outcome you chose to track.",
    claimKind: "HYPOTHESIS",
    evidenceState: "UNKNOWN",
    falsifier: "No repeated relationship appears between the practice and the selected outcome.",
    basis: ["user-selected outcome: consistency", "passage theme: perseverance"],
    caveats: ["Candidate relationship, not a causal claim."],
    profileRefs: ["profile:goal:consistency"],
    evidenceRefs: [],
    hypothesisRefs: [hypothesis.hypothesisId],
    stateDigest: "digest-why",
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };

  const devotional = {
    episodeId: "dev_perseverance",
    title: "Perseverance when progress feels slow",
    subtitle: "Straight-through devotional",
    whyThisRef: why.explanationId,
    status: "READY",
    durationSeconds: 445,
    completionReceiptRef: null,
    stateDigest: "digest-devotional",
    segments: [
      {
        position: 0,
        kind: "SCRIPTURE",
        ref: "bible:James.1.2-8",
        label: "James 1:2-8",
        durationSeconds: 180,
        audioRef: "audio:James.1.2-8",
      },
      {
        position: 1,
        kind: "TRANSITION",
        ref: "transition:1",
        label: "Next reading",
        durationSeconds: 5,
        audioRef: null,
      },
      {
        position: 2,
        kind: "SCRIPTURE",
        ref: "bible:Romans.5.1-5",
        label: "Romans 5:1-5",
        durationSeconds: 140,
        audioRef: "audio:Romans.5.1-5",
      },
      {
        position: 3,
        kind: "REFLECTION",
        ref: "reflection:perseverance",
        label: "Reflection",
        durationSeconds: 120,
        audioRef: "audio:reflection:perseverance",
      },
    ],
    hypothesisRefs: [hypothesis.hypothesisId],
    sourceRefs: ["source:bible"],
    playbackPolicy: "STRAIGHT_THROUGH",
    continuousPlay: true,
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };

  const possibilities = {
    setId: "ps_today",
    exactSubject: "person:demo",
    objective: "Choose a useful next practice without collapsing alternatives",
    horizon: "today",
    selectionRef: null,
    closureReason: null,
    possibilities: [
      {
        possibilityId: "pos_devotional",
        exactSubject: "person:demo",
        capabilityId: "capability:listen_devotional",
        label: "Listen to today's devotional",
        summary: "One uninterrupted devotional episode",
        actionRef: "Zoela.Devotional#start",
        whyThisRef: why.explanationId,
        status: "PRESERVED",
        reversibility: "REVERSIBLE",
        stateDigest: "digest-pos-devotional",
        costSummary: "7 minutes",
        consequenceSummary: "Starts local playback; no external commitment",
        requirements: ["audio-capable client"],
        evidenceRefs: [],
        expiresAt: null,
        authorityCeiling: "SELECT",
        doAuthority: false,
      },
      {
        possibilityId: "pos_serve",
        exactSubject: "person:demo",
        capabilityId: "capability:serve",
        label: "Explore serving this week",
        summary: "Review admitted service opportunities",
        actionRef: "Zoela.Service#explore",
        whyThisRef: null,
        status: "PRESERVED",
        reversibility: "REVERSIBLE",
        stateDigest: "digest-pos-serve",
        costSummary: null,
        consequenceSummary: "No roster mutation at exploration time",
        requirements: [],
        evidenceRefs: [],
        expiresAt: null,
        authorityCeiling: "SELECT",
        doAuthority: false,
      },
    ],
    constraints: [],
    sourceEpisodeRefs: ["planner:episode:demo"],
    evidenceRefs: [],
    standing: "ALIVE",
    mode: "MAXIMAL_REVERSIBLE_FRONTIER",
    stateDigest: "digest-possibility-set",
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };

  const commitment = {
    boundaryId: "cb_service",
    subjectRef: "person:demo",
    actionRef: "Zoela.Service#volunteer",
    consequenceSummary: "Confirmation expresses intent; authorized BRCE DO may later notify the team and mutate the roster.",
    reversibility: "CONDITIONAL",
    confirmationState: "UNCONFIRMED",
    constructRef: null,
    whyThisRef: why.explanationId,
    expiresAt: null,
    externalEffects: [
      "team may be notified after authorized DO",
      "roster may change after authorized DO",
    ],
    evidenceRefs: [],
    stateDigest: "digest-commitment",
    confirmationRequired: true,
    nextHandoff: "BRCE",
    authorityCeiling: "CONSTRUCT",
    doAuthority: false,
  };

  const journey = {
    journeyId: "journey_demo",
    exactSubject: "person:demo",
    entries: [
      {
        entryId: "je_devotional",
        kind: "PRACTICE",
        subjectRef: devotional.episodeId,
        label: "Completed perseverance devotional",
        occurredAt: "2026-09-21T18:00:00Z",
        receiptRef: "receipt:devotional:001",
        evidenceRefs: [],
        standing: "ALIVE",
      },
      {
        entryId: "je_reflection",
        kind: "REFLECTION",
        subjectRef: "reflection:perseverance",
        label: "Saved reflection",
        occurredAt: "2026-09-21T18:05:00Z",
        receiptRef: null,
        evidenceRefs: ["evidence:reflection:001"],
        standing: "ALIVE",
      },
    ],
    evidenceRefs: ["evidence:reflection:001"],
    receiptRefs: ["receipt:devotional:001"],
    privacyScope: "SUBJECT_PRIVATE",
    standing: "ALIVE",
    stateDigest: "digest-journey",
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };

  return {
    surfaceId: "hs_demo",
    exactSubject: "person:demo",
    stateDigest: "digest-human-surface",
    standing: "ALIVE",
    grammar: ["SEE", "UNDERSTAND", "EXPLORE", "CHOOSE", "ACT", "LEARN"],
    areas: ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"],
    today: {
      possibilitySetRefs: [possibilities.setId],
      explanationRefs: [why.explanationId],
      devotionalEpisodeRefs: [devotional.episodeId],
    },
    bible: { devotionalEpisodeRefs: [devotional.episodeId] },
    life: { outcomeHypothesisRefs: [hypothesis.hypothesisId] },
    zoe: {
      possibilitySetRefs: [possibilities.setId],
      commitmentBoundaryRefs: [commitment.boundaryId],
    },
    you: { journeyRefs: [journey.journeyId] },
    possibilitySets: [possibilities],
    explanations: [why],
    devotionalEpisodes: [devotional],
    outcomeHypotheses: [hypothesis],
    commitmentBoundaries: [commitment],
    journeys: [journey],
    evidenceRefs: ["evidence:reflection:001"],
    receiptRefs: ["receipt:devotional:001"],
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };
}

test("ZOE human surface admits the full DfCM member projection", () => {
  const value = parseHumanSurfaceProjection(fixture());

  assert.deepEqual(value.areas, ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"]);
  assert.deepEqual(value.grammar, ["SEE", "UNDERSTAND", "EXPLORE", "CHOOSE", "ACT", "LEARN"]);
  assert.equal(value.possibilitySets[0].possibilities.length, 2);
  assert.equal(value.devotionalEpisodes[0].continuousPlay, true);
  assert.equal(value.devotionalEpisodes[0].playbackPolicy, "STRAIGHT_THROUGH");
  assert.equal(value.outcomeHypotheses[0].causalClaim, false);
  assert.equal(value.commitmentBoundaries[0].nextHandoff, "BRCE");
  assert.equal(value.commitmentBoundaries[0].doAuthority, false);
  assert.equal(value.journeys[0].privacyScope, "SUBJECT_PRIVATE");
  assert.equal(value.authorityBoundary, "OBSERVE");
  assert.equal(value.doAuthority, false);
});

test("DfCM frontier refuses duplicate option identity", () => {
  const surface = fixture();
  const set = structuredClone(surface.possibilitySets[0]);
  set.possibilities.push(structuredClone(set.possibilities[0]));

  const result = possibilitySetSchema.safeParse(set);
  assert.equal(result.success, false);
});

test("ALIVE DfCM frontier refuses premature collapse to zero options", () => {
  const set = structuredClone(fixture().possibilitySets[0]);
  set.possibilities = [];

  const result = possibilitySetSchema.safeParse(set);
  assert.equal(result.success, false);
});

test("WhyThis refuses a hypothesis without a falsifier", () => {
  const why = structuredClone(fixture().explanations[0]);
  why.falsifier = null;

  const result = whyThisSchema.safeParse(why);
  assert.equal(result.success, false);
});

test("outcome hypothesis cannot claim causality on this surface", () => {
  const hypothesis = structuredClone(fixture().outcomeHypotheses[0]);
  hypothesis.causalClaim = true;

  const result = outcomeHypothesisSchema.safeParse(hypothesis);
  assert.equal(result.success, false);
});

test("completed devotional requires an observed completion receipt", () => {
  const devotional = structuredClone(fixture().devotionalEpisodes[0]);
  devotional.status = "COMPLETED";
  devotional.completionReceiptRef = null;

  const result = devotionalEpisodeSchema.safeParse(devotional);
  assert.equal(result.success, false);
});

test("commitment boundary cannot acquire DO authority", () => {
  const boundary = structuredClone(fixture().commitmentBoundaries[0]);
  boundary.confirmationState = "CONFIRMED";
  boundary.doAuthority = true;

  const result = commitmentBoundarySchema.safeParse(boundary);
  assert.equal(result.success, false);
});

test("top-level human surface refuses any attempt to promote UI into DO", () => {
  const surface = fixture();
  surface.doAuthority = true;

  assert.throws(
    () => parseHumanSurfaceProjection(surface),
    (error) => error instanceof SurfaceRuntimeError && error.code === "INVALID_HUMAN_SURFACE",
  );
});

test("all visible ACT state remains a BRCE handoff, not execution", () => {
  const surface = humanSurfaceSchema.parse(fixture());

  for (const boundary of surface.commitmentBoundaries) {
    assert.equal(boundary.authorityCeiling, "CONSTRUCT");
    assert.equal(boundary.nextHandoff, "BRCE");
    assert.equal(boundary.doAuthority, false);
  }

  for (const set of surface.possibilitySets) {
    for (const option of set.possibilities) {
      assert.notEqual(option.authorityCeiling, "DO");
      assert.equal(option.doAuthority, false);
    }
  }
});
