import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Cross-language digest contract, round 2 — the IR-era re-pin of t26
 * (digest_cross_language.test.mjs, which pins the complete-contract encoding:
 * canonical tuple-list sorting, BIT_BINARY, atoms, integers, floats, lists).
 *
 * What this round pins that t26 does not: the digest subject is the runtime's
 * ACTUAL post-parse contract (`client.contract`), not the raw JSON handed to
 * createClient. The runtime normalizes through Zod before anything else sees
 * the contract:
 *
 *   - defaulted action fields (authorityBoundary, doAuthority,
 *     receiptRequired, evidenceRequired, possibleRefusals, per-action
 *     profile, surface.profile) are re-materialized by the runtime itself, so
 *     a contract JSON with those fields stripped still digests to the Elixir
 *     golden IFF the runtime's Zod defaults equal the Elixir-emitted values
 *     byte-for-byte (F4);
 *   - passthrough keeps IR-era envelope extensions — ontologyDigest,
 *     applicationReleaseIdentity, a surface `presentation` section, and
 *     per-action `irRef` keys, all accepted by the v26.9.13 schema — inside
 *     the digested term (F5).
 *
 * Fixtures (manifest-with-surface-envelope form, one Ash fixture resource,
 * distinct from t26's F1-F3 digests — asserted below):
 *
 *   F4 create-only manifest, empty profile. Golden from the real
 *      AshSurface.from_manifest/2 pipeline (s.digest).
 *   F5 read+record manifest whose profile pins ETF boundaries t26 left
 *      unpinned — 255/256 (SMALL_INTEGER/INTEGER), -2147483648/-2147483649
 *      (INTEGER/negative SMALL_BIG), -9876543210 (negative SMALL_BIG), 0.125
 *      and -0.5 (NEW_FLOAT), "" (zero-length BIT_BINARY), 4-byte UTF-8
 *      ("Σ🜂✓"), [] / {} in nested positions, literal true/false/nil list —
 *      extended with IR-era envelope keys. Golden from the same pipeline
 *      output digested by an exact replica of the private
 *      AshSurface.digest/1, asserted equal to the real pipeline digest on
 *      F4/F5-base/F6 during generation (mismatch aborts).
 *   F6 read+record manifest with per-action authority overrides
 *      (CONSTRUCT boundary, doAuthority/receiptRequired false,
 *      evidenceRequired true, refusal list, quota 9007199254740991 — the
 *      JSON-safe integer ceiling). Golden from the real pipeline.
 *
 * Goldens were produced in this worktree (exp/v43 @ 282f3ca, OTP 28 /
 * stdlib 7.2, ash 3.33.x) on 2026-09-15 via `MIX_ENV=test mix run` calling
 * AshSurface.from_manifest/2 on the VolunteerMilestone fixture, freezing
 * s.digest (F4/F6) or replica-digest of the extended contract map (F5) plus
 * the exact digested JSON (embedded below, byte-for-byte).
 *
 * Falsifiers: any field mutation flips the digest; deep key-order
 * permutation never does.
 */

const GOLDENS = [
  {
    name: "F4 create-only contract, empty profile (zod defaults == Elixir defaults)",
    elixirDigest: "012b9c94d1e44b29cc2eb862709334a2a5676fbbd4b1193e949b9991ec214437",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.13","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"406f4fdef72bb3f689f91015edfee1ea4d13a1cc8ea661a5fe8923baa085359b","marketplaceIdentity":"ggen-marketplace:v26.9.13","surface":{"actions":[{"action":"record","authorityBoundary":"DO","doAuthority":true,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#record","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"profile":{}},"surfaceSchemaVersion":"26.9.13"}',
  },
  {
    name: "F5 IR-era envelope extensions + ETF boundary values through passthrough",
    elixirDigest: "75788f949002d53e66ce59fcf61101e500f5df3c846d495d93a393b146ce7bae",
    contractJson:
      '{"applicationReleaseIdentity":"ash-surface-wt/v43@282f3ca","ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.13","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"},{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"af93be319ad1444518422a97f02f345dfba8e076445ec77d18e69e530d3e477a","marketplaceIdentity":"ggen-marketplace:v26.9.13","ontologyDigest":"85e9ee6c4aca8091953e325969b78199363c6add1e2d95e0b070d234cbd9f887","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"},{"action":"record","authorityBoundary":"DO","doAuthority":true,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#record","irRef":"ir:26.9.16:record","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"presentation":{"irRef":"ir:26.9.16:surface","sections":["identity","authority"]},"profile":{"bounds":{"i8max":255,"i8max1":256,"int32min":-2147483648,"int32min1":-2147483649,"negbig":-9876543210},"empty":{"list":[],"map":{}},"flags":[true,false,null],"floats":[0.125,-0.5],"glyph":"Σ🜂✓","note":""}},"surfaceSchemaVersion":"26.9.13"}',
  },
  {
    name: "F6 per-action authority overrides (CONSTRUCT, refusals, safe-int ceiling)",
    elixirDigest: "303e36c9c7185801dc1babab55f223eb4dcccd6c454197b9c861acf1322745a9",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.13","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"},{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"af93be319ad1444518422a97f02f345dfba8e076445ec77d18e69e530d3e477a","marketplaceIdentity":"ggen-marketplace:v26.9.13","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"},{"action":"record","authorityBoundary":"CONSTRUCT","doAuthority":false,"evidenceRequired":true,"id":"AshSurface.Fixtures.VolunteerMilestone#record","possibleRefusals":["REFUSED_NO_AUTHORITY"],"profile":{"authorityBoundary":"CONSTRUCT","doAuthority":false,"evidenceRequired":true,"possibleRefusals":["REFUSED_NO_AUTHORITY"],"quota":9007199254740991,"receiptRequired":false},"receiptRequired":false,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"profile":{"tier":"v43"}},"surfaceSchemaVersion":"26.9.13"}',
  },
];

/** t26's pinned digests; the v2 fixtures must deepen, never re-pin them. */
const T26_DIGESTS = new Set([
  "1de44c2c6399cc7daa815c2e546b1611e8f7d3e2dad2a3cd22c72b940c72514d",
  "6c615209816759096e63becb2750adc736d785f3b8dfdac952779af57b342d18",
  "1ccea7fb0ae0190c7d18a9da30f5da38843917111d1c67ba8a955f511445de47",
]);

/** Marker for map entries, which canonical_term/1 turns into 2-tuples. */
class EtfTuple {
  constructor(elements) {
    this.elements = elements;
  }
}

function byUtf8Bytes(a, b) {
  return Buffer.compare(Buffer.from(a, "utf8"), Buffer.from(b, "utf8"));
}

/** Mirrors AshSurface.canonical_term/1: lists map element-wise, maps become
 * key-sorted lists of {string_key, value} tuples, leaves pass through. */
function canonicalTerm(value) {
  if (Array.isArray(value)) return value.map(canonicalTerm);
  if (value !== null && typeof value === "object") {
    return Object.keys(value)
      .sort(byUtf8Bytes)
      .map((key) => new EtfTuple([key, canonicalTerm(value[key])]));
  }
  return value;
}

function encodeBinary(value, chunks) {
  const bytes = Buffer.from(value, "utf8");
  const length = Buffer.alloc(4);
  length.writeUInt32BE(bytes.length);
  chunks.push(Buffer.from([0x6d]), length, bytes);
}

function encodeSmallAtomUtf8(name, chunks) {
  const bytes = Buffer.from(name, "utf8");
  if (bytes.length > 255) throw new Error(`atom too long for SMALL_ATOM_UTF8: ${name}`);
  chunks.push(Buffer.from([0x77, bytes.length]), bytes);
}

function encodeInteger(value, chunks) {
  if (value >= 0 && value <= 255) {
    chunks.push(Buffer.from([0x61, value]));
  } else if (value >= -2147483648 && value <= 2147483647) {
    const buffer = Buffer.alloc(5);
    buffer[0] = 0x62;
    buffer.writeInt32BE(value, 1);
    chunks.push(buffer);
  } else {
    const magnitude = BigInt(value < 0 ? -value : value);
    const digits = [];
    for (let mag = magnitude; mag > 0n; mag >>= 8n) digits.push(Number(mag & 0xffn));
    chunks.push(Buffer.from([0x6e, digits.length, value < 0 ? 1 : 0]), Buffer.from(digits));
  }
}

function encodeTerm(value, chunks) {
  if (value === null) return encodeSmallAtomUtf8("nil", chunks);
  if (value === true) return encodeSmallAtomUtf8("true", chunks);
  if (value === false) return encodeSmallAtomUtf8("false", chunks);
  if (typeof value === "string") return encodeBinary(value, chunks);
  if (typeof value === "number") {
    if (Number.isInteger(value) && Number.isSafeInteger(value)) return encodeInteger(value, chunks);
    const buffer = Buffer.alloc(9);
    buffer[0] = 0x46;
    buffer.writeDoubleBE(value, 1);
    chunks.push(buffer);
    return;
  }
  if (value instanceof EtfTuple) {
    chunks.push(Buffer.from([0x68, value.elements.length]));
    for (const element of value.elements) encodeTerm(element, chunks);
    return;
  }
  if (Array.isArray(value)) {
    if (value.length === 0) {
      chunks.push(Buffer.from([0x6a]));
      return;
    }
    const length = Buffer.alloc(4);
    length.writeUInt32BE(value.length);
    chunks.push(Buffer.from([0x6c]), length);
    for (const element of value) encodeTerm(element, chunks);
    chunks.push(Buffer.from([0x6a]));
    return;
  }
  throw new Error(`value is not part of the canonical contract term space: ${typeof value}`);
}

/** SHA-256 over :erlang.term_to_binary/1 encoding of the canonical term. */
function contractDigest(contract) {
  const chunks = [Buffer.from([0x83])];
  encodeTerm(canonicalTerm(contract), chunks);
  return crypto.createHash("sha256").update(Buffer.concat(chunks)).digest("hex");
}

/** Reverses key insertion order at every object depth (arrays mapped through). */
function reverseKeyOrder(value) {
  if (Array.isArray(value)) return value.map(reverseKeyOrder);
  if (value !== null && typeof value === "object") {
    const reversed = {};
    for (const key of Object.keys(value).reverse()) reversed[key] = reverseKeyOrder(value[key]);
    return reversed;
  }
  return value;
}

function clientFor(fixture, transform = (contract) => contract) {
  return createClient({ contract: transform(JSON.parse(fixture.contractJson)) });
}

test("runtime-held contract digest equals the Elixir-computed golden for every fixture", () => {
  for (const fixture of GOLDENS) {
    const client = clientFor(fixture);
    assert.equal(client.runtimeVersion, "26.9.13", `${fixture.name}: runtime version`);
    assert.equal(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});

test("golden digests are 64-character lowercase hex, pairwise distinct, and none re-pins t26", () => {
  const seen = new Set();
  for (const fixture of GOLDENS) {
    assert.match(fixture.elixirDigest, /^[0-9a-f]{64}$/, fixture.name);
    assert.equal(T26_DIGESTS.has(fixture.elixirDigest), false, `${fixture.name}: duplicates t26`);
    assert.equal(seen.has(fixture.elixirDigest), false, `${fixture.name}: duplicates another v2 fixture`);
    seen.add(fixture.elixirDigest);
  }
});

test("F4: the digest subject is the runtime-normalized contract, not the raw JSON", () => {
  const fixture = GOLDENS[0];
  // Strip every action/surface field the Zod schema defaults; the runtime
  // must re-materialize exactly the values Elixir emitted (the fields whose
  // Elixir defaults equal the Zod defaults), leaving the digest untouched.
  const stripped = (contract) => {
    delete contract.surface.profile;
    for (const action of contract.surface.actions) {
      delete action.authorityBoundary;
      delete action.doAuthority;
      delete action.receiptRequired;
      delete action.evidenceRequired;
      delete action.possibleRefusals;
      delete action.profile;
    }
    return contract;
  };

  const client = clientFor(fixture, stripped);
  assert.equal(
    contractDigest(client.contract),
    fixture.elixirDigest,
    "stripped contract re-normalized by the runtime must digest to the golden",
  );
  // Normalization is a fixpoint here: the complete JSON digests identically.
  assert.equal(contractDigest(clientFor(fixture).contract), fixture.elixirDigest);
});

test("F5: IR-era envelope extensions survive passthrough and participate in the digest", () => {
  const fixture = GOLDENS[1];
  const client = clientFor(fixture);

  assert.equal(client.contract.ontologyDigest, JSON.parse(fixture.contractJson).ontologyDigest);
  assert.equal(
    client.contract.applicationReleaseIdentity,
    "ash-surface-wt/v43@282f3ca",
    "optional envelope identity key kept by passthrough",
  );
  assert.deepEqual(client.contract.surface.presentation, {
    irRef: "ir:26.9.16:surface",
    sections: ["identity", "authority"],
  });
  assert.equal(
    client.contract.surface.actions.find((a) => a.action === "record").irRef,
    "ir:26.9.16:record",
    "per-action passthrough key kept in the digested contract",
  );

  // Removing one envelope extension flips the digest: it was inside the term.
  const withoutOntology = clientFor(fixture, (contract) => {
    delete contract.ontologyDigest;
    return contract;
  });
  assert.notEqual(contractDigest(withoutOntology.contract), fixture.elixirDigest);
});

test("digest is stable under deep key-order permutation for every fixture", () => {
  for (const fixture of GOLDENS) {
    const client = clientFor(fixture, reverseKeyOrder);
    assert.equal(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});

test("a single field mutation flips the digest for every fixture", () => {
  const mutations = [
    (contract) => {
      const digest = contract.manifestDigest;
      contract.manifestDigest = digest.slice(0, -1) + (digest.endsWith("a") ? "b" : "a");
    },
    (contract) => {
      contract.surface.profile.glyph = "Σ🜂✗";
    },
    (contract) => {
      const record = contract.surface.actions.find((a) => a.action === "record");
      record.doAuthority = true;
    },
  ];

  for (const [index, fixture] of GOLDENS.entries()) {
    const client = clientFor(fixture, (contract) => {
      mutations[index](contract);
      return contract;
    });
    assert.notEqual(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});
