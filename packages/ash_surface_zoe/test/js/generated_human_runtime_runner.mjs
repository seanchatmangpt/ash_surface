import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [targetDir, fixturePath] = process.argv.slice(2);

if (!targetDir || !fixturePath) {
  throw new Error("usage: node generated_human_runtime_runner.mjs <targetDir> <fixturePath>");
}

const human = await import(pathToFileURL(join(targetDir, "zoela_surface.human.mjs")).href);
const demo = await import(pathToFileURL(join(targetDir, "zoela_surface.demo.mjs")).href);
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

const view = demo.buildZoeDemoViewModel(surface);
assert.equal(view.syntheticOnly, true);
assert.equal(view.liveProviderReads, false);
assert.equal(view.doAuthority, false);
assert.equal(view.possibilities.length, 4);
assert.equal(view.whyThis.claimKind, "HYPOTHESIS");
assert.equal(view.whyThis.evidenceState, "UNKNOWN");
assert.ok(view.whyThis.falsifier);
assert.equal(view.personalization.facets[0].source, "USER_STATED");
assert.equal(view.manufactureTrace.equation, "A=mu(O*)");
assert.deepEqual(view.manufactureTrace.oStarRefs, ["demo-o:consistency-perseverance"]);
assert.deepEqual(view.manufactureTrace.receiptRefs, ["demo-receipt:manufacture:001"]);

const playbackStates = [];
const player = demo.createContinuousDevotionalPlayer(surface, episodeId, {
  adapter: demo.createTimedDemoPlaybackAdapter({ millisPerSecond: 0 }),
});
player.subscribe((state) => playbackStates.push([state.status, state.segmentRef]));
const completed = await player.start();
assert.equal(completed.status, "COMPLETED");
assert.equal(completed.receipt.kind, "LOCAL_PLAYBACK_COMPLETED");
assert.equal(completed.receipt.externalEffects, false);
assert.equal(completed.receipt.authorityBoundary, "OBSERVE");
assert.equal(completed.receipt.doAuthority, false);
assert.deepEqual(completed.receipt.segmentRefs, queue.segments.map((segment) => segment.ref));
assert.deepEqual(
  playbackStates.filter(([status]) => status === "PLAYING").map(([, ref]) => ref),
  queue.segments.map((segment) => segment.ref),
);

function fakeAudioFactory() {
  const listeners = new Map();
  return {
    currentTime: 0,
    addEventListener(name, callback) {
      listeners.set(name, callback);
    },
    removeEventListener(name) {
      listeners.delete(name);
    },
    async play() {
      queueMicrotask(() => listeners.get("ended")?.());
    },
    pause() {},
  };
}

const htmlAudioPlayer = demo.createContinuousDevotionalPlayer(surface, episodeId, {
  adapter: demo.createHtmlAudioAdapter({
    resolveAudioRef: (audioRef) => "memory://" + audioRef,
    audioFactory: () => fakeAudioFactory(),
  }),
});
const htmlAudioCompleted = await htmlAudioPlayer.start();
assert.equal(htmlAudioCompleted.status, "COMPLETED");
assert.equal(htmlAudioCompleted.receipt.kind, "LOCAL_PLAYBACK_COMPLETED");

const intent = demo.constructBrceIntent(surface, "Zoela.Service#volunteer");
assert.equal(intent.kind, "CONSTRUCT_INTENT");
assert.equal(intent.authorityCeiling, "CONSTRUCT");
assert.equal(intent.nextHandoff, "BRCE");
assert.equal(intent.dispatched, false);
assert.equal(intent.doAuthority, false);

const html = demo.renderZoeDemoHtml(surface);
for (const marker of [
  'data-testid="zoe-demo"',
  'data-testid="dfcm-frontier"',
  'data-testid="devotional"',
  'data-testid="why-this"',
  'data-testid="chatman-equation"',
  'data-testid="journey"',
  'data-testid="commitment"',
]) {
  assert.ok(html.includes(marker), "missing demo marker " + marker);
}
assert.ok(html.includes("Synthetic demo · no live provider reads · no external effects"));
assert.ok(html.includes("A=mu(O*)"));
assert.ok(html.includes("Next handoff: BRCE"));

console.log(
  JSON.stringify({
    standing: "ALIVE",
    receipt: "GENERATED_HUMAN_RUNTIME_PASS",
    areas: human.HUMAN_AREAS,
    possibilityCount: possibilities.length,
    devotionalSegmentCount: queue.segments.length,
    journeyEntryCount: timeline.length,
    manufactureTraceId: trace.traceId,
    consumerStanding: "ALIVE",
    playbackReceiptKind: completed.receipt.kind,
    htmlAudioPlayback: htmlAudioCompleted.status,
    provenanceVisible: html.includes("A=mu(O*)"),
    brceDispatched: intent.dispatched,
  }),
);
