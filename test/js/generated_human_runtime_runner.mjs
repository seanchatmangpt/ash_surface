import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [targetDir, fixturePath] = process.argv.slice(2);

if (!targetDir || !fixturePath) {
  throw new Error("usage: node generated_human_runtime_runner.mjs <targetDir> <fixturePath>");
}

const human = await import(pathToFileURL(join(targetDir, "zoela_surface.human.mjs")).href);
const raw = JSON.parse(await readFile(fixturePath, "utf8"));

const surface = human.parseHumanSurface(raw);

assert.deepEqual(human.HUMAN_AREAS, ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"]);
assert.deepEqual(human.HUMAN_GRAMMAR, [
  "SEE",
  "UNDERSTAND",
  "EXPLORE",
  "CHOOSE",
  "ACT",
  "LEARN",
]);

assert.equal(human.getArea(surface, "BIBLE").continuousPlayAvailable, true);

const possibilities = human.preservedPossibilities(surface);
assert.equal(possibilities.length, 4);
assert.ok(possibilities.some((item) => item.label === "Keep my current rhythm"));

const episodeId = surface.bible.devotionalEpisodeRefs[0];
const queue = human.devotionalQueue(surface, episodeId);
assert.equal(queue.continuousPlay, true);
assert.equal(queue.playbackPolicy, "STRAIGHT_THROUGH");
assert.equal(queue.segments.length, 4);
assert.deepEqual(
  queue.segments.map((segment) => segment.position),
  [0, 1, 2, 3],
);

const boundary = human.commitmentPreview(surface, "Zoela.Service#volunteer");
assert.equal(boundary.nextHandoff, "BRCE");
assert.equal(boundary.authorityCeiling, "CONSTRUCT");
assert.equal(boundary.doAuthority, false);

const contextId = surface.life.personalizationContextRefs[0];
const context = human.personalizationContext(surface, contextId);
assert.equal(context.privacyScope, "SUBJECT_PRIVATE");
assert.equal(context.shareScope, "SUBJECT_ONLY");
assert.equal(context.facets[0].source, "USER_STATED");

const trace = human.manufactureTraceFor(surface, "practice:devotional:perseverance");
assert.equal(trace.equation, "A=mu(O*)");
assert.deepEqual(trace.oStarRefs, ["demo-o:consistency-perseverance"]);
assert.deepEqual(trace.receiptRefs, ["demo-receipt:manufacture:001"]);

const timeline = human.journeyTimeline(surface);
assert.equal(timeline.length, 3);
assert.ok(timeline.every((entry) => entry.privacyScope === "SUBJECT_PRIVATE"));

assert.equal(human.assertNoDoAuthority(surface), true);

console.log(
  JSON.stringify({
    standing: "ALIVE",
    receipt: "GENERATED_HUMAN_RUNTIME_PASS",
    areas: human.HUMAN_AREAS,
    possibilityCount: possibilities.length,
    devotionalSegmentCount: queue.segments.length,
    journeyEntryCount: timeline.length,
    manufactureTraceId: trace.traceId,
  }),
);
