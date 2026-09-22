import test from "node:test";
import assert from "node:assert/strict";

import {
  manufactureTraceSchema,
  personalizationContextSchema,
} from "../../priv/static/ash_surface_runtime.mjs";

function validContext() {
  return {
    contextId: "pc_demo",
    exactSubject: "person:demo",
    facets: [
      {
        facetId: "pf_goal",
        dimension: "life:outcome",
        valueRef: "life:outcome:consistency",
        source: "USER_STATED",
        standing: "ALIVE",
        falsifier: null,
        evidenceRefs: ["evidence:user-selection"],
      },
    ],
    consentRef: "consent:subject-only",
    evidenceRefs: ["evidence:user-selection"],
    standing: "ALIVE",
    privacyScope: "SUBJECT_PRIVATE",
    shareScope: "SUBJECT_ONLY",
    stateDigest: "digest-profile",
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };
}

function validTrace() {
  return {
    traceId: "mt_demo",
    exactSubject: "person:demo",
    artifactRef: "practice:devotional:perseverance",
    manufacturerIdentity: "zoe:personalization:semantic-map",
    humanSummary: "Built from the admitted goal and devotional semantics.",
    observedRefs: ["o:goal"],
    admittedRefs: ["o:goal"],
    groundedRefs: ["o:goal"],
    boundedRefs: ["o:goal"],
    alignedRefs: ["o:goal"],
    oStarRefs: ["o:goal"],
    receiptRefs: ["receipt:manufacture:001"],
    falsifiers: ["goal admission is withdrawn"],
    standing: "ALIVE",
    stateDigest: "digest-trace",
    equation: "A=mu(O*)",
    authorityBoundary: "OBSERVE",
    doAuthority: false,
  };
}

test("subject-private USER_STATED personalization context is admitted", () => {
  const context = personalizationContextSchema.parse(validContext());
  assert.equal(context.facets[0].source, "USER_STATED");
  assert.equal(context.privacyScope, "SUBJECT_PRIVATE");
  assert.equal(context.shareScope, "SUBJECT_ONLY");
  assert.equal(context.doAuthority, false);
});

test("INFERRED personalization cannot enter without a falsifier", () => {
  const context = validContext();
  context.facets[0].source = "INFERRED";
  context.facets[0].standing = "UNKNOWN";
  context.facets[0].falsifier = null;

  assert.equal(personalizationContextSchema.safeParse(context).success, false);
});

test("personalization context cannot acquire DO authority", () => {
  const context = validContext();
  context.doAuthority = true;

  assert.equal(personalizationContextSchema.safeParse(context).success, false);
});

test("receipted A=mu(O*) manufacture trace is admitted", () => {
  const trace = manufactureTraceSchema.parse(validTrace());

  assert.equal(trace.equation, "A=mu(O*)");
  assert.deepEqual(trace.oStarRefs, ["o:goal"]);
  assert.deepEqual(trace.receiptRefs, ["receipt:manufacture:001"]);
  assert.equal(trace.doAuthority, false);
});

test("O* must be inside observed/admitted/grounded/bounded/aligned intersection", () => {
  const trace = validTrace();
  trace.boundedRefs = [];

  assert.equal(manufactureTraceSchema.safeParse(trace).success, false);
});

test("ALIVE manufacture trace without receipt is refused", () => {
  const trace = validTrace();
  trace.receiptRefs = [];

  assert.equal(manufactureTraceSchema.safeParse(trace).success, false);
});

test("manufacture provenance cannot acquire authority", () => {
  const trace = validTrace();
  trace.doAuthority = true;

  assert.equal(manufactureTraceSchema.safeParse(trace).success, false);
});
