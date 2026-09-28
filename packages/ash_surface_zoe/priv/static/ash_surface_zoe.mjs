import { z } from "zod";
import { SurfaceRuntimeError } from "ash_surface";

/**
 * ZOE / DfCM human-surface Zod boundary schemas (package ash_surface_zoe).
 *
 * Extracted verbatim from the core ash_surface runtime. Ordinary executable
 * JavaScript: JSDoc is the static typing surface, Zod is the executable
 * boundary. TypeScript is not required, emitted, or consumed. The core runtime
 * is imported by its package name ("ash_surface"), exactly as generated
 * artifacts import it; consumers resolve that name to the core runtime file.
 */

export const ZOE_RUNTIME_VERSION = "0.1.0";

const jsonRecordSchema = z.record(z.string(), z.unknown());

const evidenceStandingSchema = z.enum(["UNKNOWN", "PARTIAL_ALIVE", "ALIVE", "BLOCKED", "REFUSED"]);

export const possibilitySchema = z
  .object({
    possibilityId: z.string().min(1),
    exactSubject: z.string().min(1),
    capabilityId: z.string().min(1),
    label: z.string().min(1),
    summary: z.string().nullable().optional(),
    actionRef: z.string().nullable().optional(),
    whyThisRef: z.string().nullable().optional(),
    status: z.enum(["CANDIDATE", "PRESERVED", "BLOCKED", "REFUSED"]),
    reversibility: z.enum(["REVERSIBLE", "CONDITIONAL", "IRREVERSIBLE"]),
    stateDigest: z.string().min(1),
    costSummary: z.string().nullable().optional(),
    consequenceSummary: z.string().nullable().optional(),
    requirements: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    expiresAt: z.string().nullable().optional(),
    authorityCeiling: z.enum(["OBSERVE", "SELECT", "CONSTRUCT"]).default("SELECT"),
    doAuthority: z.literal(false).default(false),
  })
  .passthrough();

export const possibilitySetSchema = z
  .object({
    setId: z.string().min(1),
    exactSubject: z.string().min(1),
    objective: z.string().min(1),
    horizon: z.string().nullable().optional(),
    selectionRef: z.string().nullable().optional(),
    closureReason: z.string().nullable().optional(),
    possibilities: z.array(possibilitySchema),
    constraints: z.array(z.string()).default([]),
    sourceEpisodeRefs: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    standing: evidenceStandingSchema.default("PARTIAL_ALIVE"),
    mode: z.literal("MAXIMAL_REVERSIBLE_FRONTIER"),
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .superRefine((value, ctx) => {
    if (value.standing === "ALIVE" && value.possibilities.length === 0) {
      ctx.addIssue({ code: "custom", message: "ALIVE possibility set requires at least one option" });
    }
    if (new Set(value.possibilities.map((item) => item.possibilityId)).size !== value.possibilities.length) {
      ctx.addIssue({ code: "custom", message: "possibility ids must be unique" });
    }
  });

export const whyThisSchema = z
  .object({
    explanationId: z.string().min(1),
    subjectRef: z.string().min(1),
    title: z.string().min(1),
    summary: z.string().min(1),
    claimKind: z.enum(["HYPOTHESIS", "OBSERVATION", "USER_STATED", "DOCTRINAL"]),
    evidenceState: evidenceStandingSchema,
    falsifier: z.string().nullable().optional(),
    basis: z.array(z.string()).default([]),
    caveats: z.array(z.string()).default([]),
    profileRefs: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    hypothesisRefs: z.array(z.string()).default([]),
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .superRefine((value, ctx) => {
    if (value.claimKind === "HYPOTHESIS" && !value.falsifier) {
      ctx.addIssue({ code: "custom", message: "HYPOTHESIS explanation requires falsifier" });
    }
  });

export const outcomeHypothesisSchema = z
  .object({
    hypothesisId: z.string().min(1),
    subjectRef: z.string().min(1),
    practiceRef: z.string().min(1),
    outcomeRef: z.string().min(1),
    relationship: z.enum(["MAY_SUPPORT", "MAY_HINDER", "ASSOCIATED", "UNKNOWN"]),
    evidenceState: evidenceStandingSchema,
    falsifier: z.string().min(1),
    horizon: z.string().nullable().optional(),
    evidenceRefs: z.array(z.string()).default([]),
    observationRefs: z.array(z.string()).default([]),
    stateDigest: z.string().min(1),
    causalClaim: z.literal(false),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .passthrough();

export const devotionalSegmentSchema = z
  .object({
    position: z.number().int().nonnegative(),
    kind: z.enum(["SCRIPTURE", "COMMENTARY", "PRAYER", "REFLECTION", "MUSIC", "TRANSITION"]),
    ref: z.string().min(1),
    label: z.string().min(1),
    durationSeconds: z.number().int().nonnegative(),
    audioRef: z.string().nullable().optional(),
  })
  .passthrough();

export const devotionalEpisodeSchema = z
  .object({
    episodeId: z.string().min(1),
    title: z.string().min(1),
    subtitle: z.string().nullable().optional(),
    whyThisRef: z.string().nullable().optional(),
    status: z.enum(["READY", "IN_PROGRESS", "COMPLETED", "BLOCKED"]),
    durationSeconds: z.number().int().nonnegative(),
    completionReceiptRef: z.string().nullable().optional(),
    stateDigest: z.string().min(1),
    segments: z.array(devotionalSegmentSchema),
    hypothesisRefs: z.array(z.string()).default([]),
    sourceRefs: z.array(z.string()).default([]),
    playbackPolicy: z.literal("STRAIGHT_THROUGH"),
    continuousPlay: z.literal(true),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .superRefine((value, ctx) => {
    if (value.status === "COMPLETED" && !value.completionReceiptRef) {
      ctx.addIssue({ code: "custom", message: "COMPLETED devotional requires completion receipt" });
    }
  });

export const commitmentBoundarySchema = z
  .object({
    boundaryId: z.string().min(1),
    subjectRef: z.string().min(1),
    actionRef: z.string().min(1),
    consequenceSummary: z.string().min(1),
    reversibility: z.enum(["REVERSIBLE", "CONDITIONAL", "IRREVERSIBLE"]),
    confirmationState: z.enum(["UNCONFIRMED", "CONFIRMED", "DECLINED", "EXPIRED"]),
    constructRef: z.string().nullable().optional(),
    whyThisRef: z.string().nullable().optional(),
    expiresAt: z.string().nullable().optional(),
    externalEffects: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    stateDigest: z.string().min(1),
    confirmationRequired: z.literal(true),
    nextHandoff: z.literal("BRCE"),
    authorityCeiling: z.literal("CONSTRUCT"),
    doAuthority: z.literal(false),
  })
  .passthrough();

export const journeyEntrySchema = z
  .object({
    entryId: z.string().min(1),
    kind: z.enum(["PRACTICE", "SERVICE", "ATTENDANCE", "COMMITMENT", "REFLECTION", "OUTCOME", "RECEIPT"]),
    subjectRef: z.string().min(1),
    label: z.string().min(1),
    occurredAt: z.string().min(1),
    receiptRef: z.string().nullable().optional(),
    evidenceRefs: z.array(z.string()).default([]),
    standing: evidenceStandingSchema,
  })
  .passthrough();

export const journeySchema = z
  .object({
    journeyId: z.string().min(1),
    exactSubject: z.string().min(1),
    entries: z.array(journeyEntrySchema),
    evidenceRefs: z.array(z.string()).default([]),
    receiptRefs: z.array(z.string()).default([]),
    privacyScope: z.literal("SUBJECT_PRIVATE"),
    standing: evidenceStandingSchema,
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .passthrough();

export const personalizationFacetSchema = z
  .object({
    facetId: z.string().min(1),
    dimension: z.string().min(1),
    valueRef: z.string().min(1),
    source: z.enum(["USER_STATED", "OBSERVED", "INFERRED"]),
    standing: evidenceStandingSchema,
    falsifier: z.string().nullable().optional(),
    evidenceRefs: z.array(z.string()).default([]),
  })
  .superRefine((value, ctx) => {
    if (value.source === "INFERRED" && !value.falsifier) {
      ctx.addIssue({ code: "custom", message: "INFERRED personalization facet requires falsifier" });
    }
  });

export const personalizationContextSchema = z
  .object({
    contextId: z.string().min(1),
    exactSubject: z.string().min(1),
    facets: z.array(personalizationFacetSchema),
    consentRef: z.string().nullable().optional(),
    evidenceRefs: z.array(z.string()).default([]),
    standing: evidenceStandingSchema,
    privacyScope: z.literal("SUBJECT_PRIVATE"),
    shareScope: z.literal("SUBJECT_ONLY"),
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE"),
    doAuthority: z.literal(false),
  })
  .passthrough();

export const manufactureTraceSchema = z
  .object({
    traceId: z.string().min(1),
    exactSubject: z.string().min(1),
    artifactRef: z.string().min(1),
    manufacturerIdentity: z.string().min(1),
    humanSummary: z.string().nullable().optional(),
    observedRefs: z.array(z.string()).default([]),
    admittedRefs: z.array(z.string()).default([]),
    groundedRefs: z.array(z.string()).default([]),
    boundedRefs: z.array(z.string()).default([]),
    alignedRefs: z.array(z.string()).default([]),
    oStarRefs: z.array(z.string()).default([]),
    receiptRefs: z.array(z.string()).default([]),
    falsifiers: z.array(z.string()).default([]),
    standing: evidenceStandingSchema,
    stateDigest: z.string().min(1),
    equation: z.literal("A=mu(O*)"),
    authorityBoundary: z.literal("OBSERVE"),
    doAuthority: z.literal(false),
  })
  .superRefine((value, ctx) => {
    const sources = [
      new Set(value.observedRefs),
      new Set(value.admittedRefs),
      new Set(value.groundedRefs),
      new Set(value.boundedRefs),
      new Set(value.alignedRefs),
    ];

    for (const ref of value.oStarRefs) {
      if (!sources.every((set) => set.has(ref))) {
        ctx.addIssue({
          code: "custom",
          message: "every O* reference must be observed, admitted, grounded, bounded, and aligned",
        });
      }
    }

    if (value.standing === "ALIVE" && value.receiptRefs.length === 0) {
      ctx.addIssue({ code: "custom", message: "ALIVE manufacture trace requires receipt" });
    }
  });

export const humanSurfaceSchema = z
  .object({
    surfaceId: z.string().min(1),
    exactSubject: z.string().min(1),
    stateDigest: z.string().min(1),
    standing: evidenceStandingSchema,
    grammar: z.tuple([
      z.literal("SEE"),
      z.literal("UNDERSTAND"),
      z.literal("EXPLORE"),
      z.literal("CHOOSE"),
      z.literal("ACT"),
      z.literal("LEARN"),
    ]),
    areas: z.tuple([
      z.literal("TODAY"),
      z.literal("BIBLE"),
      z.literal("LIFE"),
      z.literal("ZOE"),
      z.literal("YOU"),
    ]),
    today: jsonRecordSchema,
    bible: jsonRecordSchema,
    life: jsonRecordSchema,
    zoe: jsonRecordSchema,
    you: jsonRecordSchema,
    possibilitySets: z.array(possibilitySetSchema).default([]),
    explanations: z.array(whyThisSchema).default([]),
    devotionalEpisodes: z.array(devotionalEpisodeSchema).default([]),
    outcomeHypotheses: z.array(outcomeHypothesisSchema).default([]),
    commitmentBoundaries: z.array(commitmentBoundarySchema).default([]),
    journeys: z.array(journeySchema).default([]),
    personalizationContexts: z.array(personalizationContextSchema).default([]),
    manufactureTraces: z.array(manufactureTraceSchema).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    receiptRefs: z.array(z.string()).default([]),
    authorityBoundary: z.literal("OBSERVE"),
    doAuthority: z.literal(false),
  })
  .passthrough();

export function parseHumanSurfaceProjection(value) {
  const parsed = humanSurfaceSchema.safeParse(value);
  if (!parsed.success) {
    throw new SurfaceRuntimeError(
      "INVALID_HUMAN_SURFACE",
      "AshSurface human projection failed Zod validation",
      { issues: parsed.error.issues },
    );
  }
  return parsed.data;
}
