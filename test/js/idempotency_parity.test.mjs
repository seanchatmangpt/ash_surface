import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  VOCABULARY,
  IDEMPOTENCY_PROTOCOL,
  computeRequestDigest,
  deriveIdempotencyKey,
  validateIdempotencyKey,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Law pinned: the ash_surface.idempotency/1 key law and canonical request
 * digest are byte-identical across languages. The vectors live in
 * test/js/fixtures/idempotency_vectors.json and were minted by
 * AshSurface.Idempotency (Elixir); test/ash_surface/idempotency_test.exs
 * reads the SAME file. Drift on either side breaks both suites.
 */
const V = JSON.parse(
  readFileSync(new URL("./fixtures/idempotency_vectors.json", import.meta.url), "utf8"),
);

test("protocol identifier is shared", () => {
  assert.equal(V.protocol, IDEMPOTENCY_PROTOCOL);
  assert.equal(VOCABULARY.idempotencyProtocol, IDEMPOTENCY_PROTOCOL);
});

test("request digest vectors match the Elixir canonical digest", () => {
  for (const v of V.digests) {
    const digest = computeRequestDigest(v.actionId, JSON.parse(v.inputJson));
    assert.equal(digest, v.digest, `${v.actionId} ${v.inputJson}`);
    assert.equal(digest.length, VOCABULARY.digestHexLength);
  }
});

test("derived key vectors match Elixir and are themselves valid keys", () => {
  for (const v of V.derivedKeys) {
    const key = deriveIdempotencyKey(v.actionId, v.commandId);
    assert.equal(key, v.key);
    assert.equal(validateIdempotencyKey(key), true);
  }
});

test("key validation vectors", () => {
  for (const key of V.validKeys) assert.equal(validateIdempotencyKey(key), true, key);
  for (const key of V.invalidKeys) assert.equal(validateIdempotencyKey(key), false, JSON.stringify(key));
  for (const other of [null, undefined, 12345678, {}, ["abcd1234"]]) {
    assert.equal(validateIdempotencyKey(other), false);
  }
});

test("non-portable inputs are refused, matching Elixir's refusals", () => {
  for (const json of V.nonPortableInputJson) {
    assert.throws(
      () => computeRequestDigest("act", JSON.parse(json)),
      (e) => e instanceof SurfaceRuntimeError && e.code === "IDEMPOTENCY_INPUT_NOT_PORTABLE",
      json,
    );
  }
});

test("JS-only non-portable shapes are refused", () => {
  const bad = [{ a: undefined }, [undefined], new Date(0), () => 1, 10n, "\ud800", { "\udc00": 1 }, Object.create({ x: 1 })];
  for (const input of bad) {
    // Object.create({x:1}) has a non-plain prototype.
    assert.throws(() => computeRequestDigest("act", input), (e) => e.code === "IDEMPOTENCY_INPUT_NOT_PORTABLE");
  }
});

test("digest is insensitive to key order and undefined input equals null input", () => {
  assert.equal(computeRequestDigest("a", { x: 1, y: 2 }), computeRequestDigest("a", { y: 2, x: 1 }));
  assert.equal(computeRequestDigest("a", undefined), computeRequestDigest("a", null));
  assert.notEqual(computeRequestDigest("a", [1, 2]), computeRequestDigest("a", [2, 1]));
  assert.notEqual(computeRequestDigest("a", 1), computeRequestDigest("b", 1));
});
