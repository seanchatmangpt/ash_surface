import test from "node:test";
import assert from "node:assert/strict";
import {
  surfaceActionSchema,
  idempotencyProfileSchema,
  reconcileResultSchema,
  validateIdempotencyKey,
  computeRequestDigest,
  deriveIdempotencyKey,
} from "../../../priv/static/ash_surface_runtime.mjs";

// Lane S2: adversarial inputs through the shipped runtime's real zod 4 schemas
// (no doubles). Seeded generator: mulberry32 with seed in the test name.
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const NASTY = ["__proto__", "constructor", "toString", 'a"b', "a\\b", "a\nb", "a b", "a b", "名前", "😀", "", "$", "${x}"];

const base = (over = {}) => ({ id: "a", resource: "r", action: "x", ...over });

for (const seed of [1, 2, 3, 4]) {
  test(`surfaceActionSchema accepts nasty id/resource/action strings, seed=${seed}`, () => {
    const r = rng(seed);
    for (let i = 0; i < 25; i++) {
      const pick = () => NASTY[Math.floor(r() * NASTY.length)] || "fallback";
      const res = surfaceActionSchema.safeParse(base({ id: pick(), resource: pick(), action: pick() }));
      assert.equal(res.success, true);
      assert.equal(Object.getPrototypeOf(res.data), Object.prototype);
    }
  });
}

test("surfaceActionSchema rejects empty / non-string / nil members", () => {
  for (const bad of [
    base({ id: "" }),
    base({ resource: null }),
    base({ action: 0 }),
    base({ authorityBoundary: "DOO" }),
    base({ possibleRefusals: ["REFUSED"] }),
    base({ possibleRefusals: ["REFUSED_"] }),
    base({ possibleRefusals: "REFUSED_X" }),
    null,
    [],
    "x",
    0,
  ]) {
    assert.equal(surfaceActionSchema.safeParse(bad).success, false, JSON.stringify(bad));
  }
});

test("__proto__ own key does not pollute and is not lifted to the prototype", () => {
  const input = JSON.parse('{"id":"a","resource":"r","action":"x","profile":{"__proto__":{"polluted":true}}}');
  const res = surfaceActionSchema.safeParse(input);
  assert.equal(({}).polluted, undefined);
  if (res.success) assert.equal(Object.getPrototypeOf(res.data.profile), Object.prototype);
});

test("idempotencyProfileSchema is strict and defaults crossTransport", () => {
  const ok = idempotencyProfileSchema.safeParse({ protocol: "ash_surface.idempotency/1" });
  assert.equal(ok.success, true);
  assert.equal(ok.data.crossTransport, false);
  for (const bad of [{}, { protocol: "x" }, { protocol: "ash_surface.idempotency/1", extra: 1 }, { protocol: "ash_surface.idempotency/1", keyHeader: "" }, null]) {
    assert.equal(idempotencyProfileSchema.safeParse(bad).success, false);
  }
});

test("validateIdempotencyKey edge lengths and charset", () => {
  assert.equal(validateIdempotencyKey("a".repeat(7)), false);
  assert.equal(validateIdempotencyKey("a".repeat(8)), true);
  assert.equal(validateIdempotencyKey("a".repeat(128)), true);
  assert.equal(validateIdempotencyKey("a".repeat(129)), false);
  assert.equal(validateIdempotencyKey("_aaaaaaaa"), false);
  assert.equal(validateIdempotencyKey("aaaaaaaa\n"), false);
  for (const v of [null, undefined, 1, {}, [], "名前名前名前名前名前"]) assert.equal(validateIdempotencyKey(v), false);
});

test("computeRequestDigest: numbers 0/-0/negative/huge/unsafe/float", () => {
  assert.equal(computeRequestDigest("a", 0), computeRequestDigest("a", -0));
  assert.match(computeRequestDigest("a", -5), /^[0-9a-f]+$/);
  assert.match(computeRequestDigest("a", Number.MAX_SAFE_INTEGER), /^[0-9a-f]+$/);
  for (const bad of [Number.MAX_SAFE_INTEGER + 2, 1.5, NaN, Infinity, "\ud800", { u: undefined }]) {
    assert.throws(() => computeRequestDigest("a", bad), (e) => e.code === "IDEMPOTENCY_INPUT_NOT_PORTABLE" || /portable/i.test(e.message), String(bad));
  }
});

for (const seed of [5, 6, 7]) {
  test(`computeRequestDigest is key-order independent over nasty keys, seed=${seed}`, () => {
    const r = rng(seed);
    const keys = [...NASTY.filter((k) => k !== "__proto__"), "k1", "k2"].sort(() => r() - 0.5).slice(0, 8);
    const a = {};
    const b = {};
    for (const k of keys) a[k] = 1;
    for (const k of [...keys].reverse()) b[k] = 1;
    assert.equal(computeRequestDigest("x", a), computeRequestDigest("x", b));
  });
}

test("computeRequestDigest nesting depth 0/1/8 and empty arrays/objects", () => {
  let v = "leaf";
  const seen = new Set([computeRequestDigest("a", v)]);
  for (let d = 1; d <= 8; d++) {
    v = [v];
    seen.add(computeRequestDigest("a", v));
  }
  assert.equal(seen.size, 9);
  assert.notEqual(computeRequestDigest("a", []), computeRequestDigest("a", {}));
  assert.equal(computeRequestDigest("a", undefined), computeRequestDigest("a", null));
});

test("deriveIdempotencyKey is deterministic and passes validateIdempotencyKey over nasty ids", () => {
  for (const n of NASTY) {
    const k = deriveIdempotencyKey(n, n);
    assert.equal(k, deriveIdempotencyKey(n, n));
    assert.equal(validateIdempotencyKey(k), true);
  }
  assert.notEqual(deriveIdempotencyKey("a", "bc"), deriveIdempotencyKey("ab", "c"));
});

test("reconcileResultSchema rejects junk", () => {
  for (const bad of [null, undefined, [], "x", 0, {}, { status: 1 }]) {
    assert.equal(reconcileResultSchema.safeParse(bad).success, false, JSON.stringify(bad));
  }
});
