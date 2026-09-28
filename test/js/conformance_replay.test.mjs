import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  DEFAULT_CORPUS_DIR,
  loadCorpus,
  replayCorpus,
  replayVector,
  summarize,
} from "../../conformance/js/replay.mjs";
import { KNOWN_DIVERGENCES } from "../../conformance/js/known_divergences.mjs";
import { naiveCanonicalStringify, canonicalJson } from "../../conformance/js/reference.mjs";

/**
 * Law pinned: the shipped JavaScript runtime (priv/static/ash_surface_runtime.mjs)
 * agrees with the language-neutral conformance corpus that the REAL Elixir
 * implementation generated (conformance/vectors/*.json).
 *
 * Every vector gets exactly one status - PASS, NOT_APPLICABLE (with a reason the
 * runtime cannot express it), or KNOWN_DIVERGENCE (a pinned, asserted disagreement)
 * - and never a silent skip. Any other disagreement is FAIL: a real cross-language
 * bug. The replay is proven able to fail by mutating a vector's expected value in
 * memory and in a scratch copy of the corpus under _build/test.
 */

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const results = await replayCorpus();
const { manifest, files } = loadCorpus();

test("every vector in the manifest is replayed exactly once with exactly one status", () => {
  assert.equal(results.length, manifest.vectorCount);
  assert.equal(new Set(results.map((r) => r.id)).size, results.length, "vector ids are unique");
  for (const result of results) {
    assert.ok(["PASS", "FAIL", "NOT_APPLICABLE", "KNOWN_DIVERGENCE"].includes(result.status), result.id);
    if (result.status === "NOT_APPLICABLE" || result.status === "KNOWN_DIVERGENCE") {
      assert.ok(typeof result.reason === "string" && result.reason.length > 20, `${result.id}: declared status needs a reason`);
    }
  }
});

test("JavaScript agrees with the Elixir-generated corpus on every vector it can express", () => {
  const failures = results.filter((r) => r.status === "FAIL");
  assert.deepEqual(
    failures.map((r) => ({ id: r.id, reason: r.reason, actual: r.actual, want: r.want })),
    [],
    "cross-language disagreement (real bug) - see actual vs want",
  );
});

test("no MUST vector is silently unaccounted: each is PASS, NOT_APPLICABLE(reason) or KNOWN_DIVERGENCE(reason)", () => {
  const byLevel = {};
  for (const result of results) {
    byLevel[result.level] ??= { PASS: 0, NOT_APPLICABLE: 0, KNOWN_DIVERGENCE: 0 };
    byLevel[result.level][result.status] += 1;
  }
  console.log("\nJS conformance by level", JSON.stringify(byLevel));
  console.table(summarize(results));
  const dir = path.join(root, "_build", "test");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(
    path.join(dir, "conformance_js_report.json"),
    JSON.stringify(
      results.map(({ id, kind, level, status, reason }) => ({ id, kind, level, status, reason })),
      null,
      1,
    ),
  );
  for (const level of Object.keys(byLevel)) {
    assert.equal(byLevel[level].FAIL, undefined);
  }
});

test("every pinned known divergence names a real vector, and every vector of them still diverges", () => {
  const ids = new Set(results.map((r) => r.id));
  for (const id of Object.keys(KNOWN_DIVERGENCES)) assert.ok(ids.has(id), `stale divergence entry: ${id}`);
  const diverging = results.filter((r) => r.status === "KNOWN_DIVERGENCE").map((r) => r.id).sort();
  assert.deepEqual(diverging, Object.keys(KNOWN_DIVERGENCES).sort());
});

test("the exhaustive transport table is replayed for every expressible row (nothing skipped by accident)", () => {
  const table = results.filter((r) => r.id.startsWith("ts/d="));
  const passed = table.filter((r) => r.status === "PASS");
  assert.equal(table.length, 364);
  assert.ok(passed.length >= 200, `only ${passed.length} exhaustive rows PASS`);
  assert.deepEqual(table.filter((r) => r.status === "FAIL"), []);
  // every JS-inexpressible row is an order-parametric (MAY) or explained-shape row
  for (const row of table.filter((r) => r.status === "NOT_APPLICABLE")) assert.equal(row.level, "MAY", row.id);
});

test("post-dispatch failures are UNKNOWN_AFTER_DISPATCH and never replay over another transport (all causes PASS)", () => {
  const post = results.filter((r) => r.id.startsWith("to/post/"));
  assert.equal(post.length, 4);
  for (const row of post) assert.equal(row.status, "PASS", row.id);
  const pre = results.filter((r) => r.id.startsWith("to/pre/"));
  for (const row of pre) assert.equal(row.status, "PASS", row.id);
});

test("replay can fail: mutating an expected leaf stops a passing vector from PASSing (every kind)", async () => {
  for (const file of files) {
    const passing = file.vectors.filter((v) => results.find((r) => r.id === v.id)?.status === "PASS").slice(0, 40);
    assert.ok(passing.length > 0, `${file.kind}: has passing vectors to mutate`);
    let detected = 0;
    let mutations = 0;
    for (const vector of passing) {
      for (const leafPath of leafPaths(vector.expected)) {
        const mutated = structuredClone(vector);
        mutateAt(mutated.expected, leafPath);
        mutations += 1;
        if ((await replayVector(file.kind, mutated, {})).status !== "PASS") detected += 1;
      }
    }
    // JS compares the normative view only (error `detail` and some event fields
    // are diagnostic), so not every leaf is checked - but the replay must be able to fail.
    assert.ok(detected > 0, `${file.kind}: none of ${mutations} single-leaf mutations was detected`);
  }
});

test("replay can fail: a scratch copy of the corpus with one edited vector is RED", async () => {
  const scratch = path.join(root, "_build", "test", "conformance_mutated");
  fs.rmSync(scratch, { recursive: true, force: true });
  fs.cpSync(DEFAULT_CORPUS_DIR, scratch, { recursive: true, filter: (src) => !src.includes(`${path.sep}elixir`) && !src.includes(`${path.sep}js`) });
  const file = path.join(scratch, "vectors", "reconcile_status.json");
  const doc = JSON.parse(fs.readFileSync(file, "utf8"));
  doc.vectors[0].expected.admitted = false; // COMPLETED is admitted; claim it is not
  fs.writeFileSync(file, JSON.stringify(doc));
  const mutatedResults = await replayCorpus({ dir: scratch });
  const failed = mutatedResults.filter((r) => r.status === "FAIL");
  assert.deepEqual(failed.map((r) => r.id), [doc.vectors[0].id]);
});

test("a stale known-divergence entry fails (divergences are assertions, not exemptions)", async () => {
  const someKind = files.find((f) => f.kind === "reconcile_status");
  const vector = someKind.vectors[0];
  const outcome = await replayVector("reconcile_status", vector, { [vector.id]: { reason: "x".repeat(30), jsActual: { admitted: false } } });
  assert.equal(outcome.status, "FAIL");
  assert.match(outcome.reason, /no longer diverges/);
});

test("the shipped consumer runner's naive minting law differs from the corpus canonical law exactly where documented", () => {
  const vectors = Object.fromEntries(files.flatMap((f) => f.vectors.map((v) => [v.id, v])));
  const naive = (id) => naiveCanonicalStringify(JSON.parse(vectors[id].input.json));

  // agrees on plain data
  assert.equal(naive("cj/key-order"), vectors["cj/key-order"].expected.canonical);
  // control-character escape hex case (\u001f vs \u001F)
  assert.notEqual(naive("cj/escapes-control"), vectors["cj/escapes-control"].expected.canonical);
  assert.equal(canonicalJson(JSON.parse(vectors["cj/escapes-control"].input.json)), vectors["cj/escapes-control"].expected.canonical);
  // UTF-16 code-unit key order vs UTF-8 byte order for astral vs high-BMP keys
  assert.notEqual(naive("cj/key-sort-utf8-bytes"), vectors["cj/key-sort-utf8-bytes"].expected.canonical);
  assert.equal(canonicalJson(JSON.parse(vectors["cj/key-sort-utf8-bytes"].input.json)), vectors["cj/key-sort-utf8-bytes"].expected.canonical);
});

function leafPaths(node, prefix = []) {
  if (node !== null && typeof node === "object") {
    return Object.keys(node).flatMap((key) => leafPaths(node[key], [...prefix, key]));
  }
  return [prefix];
}

function mutateAt(root, leafPath) {
  const parent = leafPath.slice(0, -1).reduce((node, key) => node[key], root);
  const key = leafPath.at(-1);
  const value = parent[key];
  parent[key] =
    typeof value === "boolean" ? !value : typeof value === "number" ? value + 1 : value === null ? "mutated" : `${value}-mutated`;
}
