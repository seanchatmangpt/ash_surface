import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Cross-language digest contract (π_JS/π_Elixir).
 *
 * `AshSurface.from_manifest/2` (lib/ash_surface.ex) defines the contract digest as
 *
 *     digest(contract) =
 *       contract
 *       |> canonical_term/1()          # map -> sorted list of {string_key, value} tuples
 *       |> :erlang.term_to_binary()
 *       |> :crypto.hash(:sha256)
 *       |> Base.encode16(case: :lower)
 *
 * The contract that reaches this JS runtime is exactly the map Elixir digested
 * (the manifest serializer is JSON-pure; the only atoms are nil/true/false).
 * Reproducing the digest in JS therefore requires encoding the canonical term
 * in the Erlang external term format. The golden hex constants below were
 * produced by the real Elixir pipeline (OTP 28 / stdlib 7.2, ash 3.33.x) on
 * 2026-09-15 via, in this worktree:
 *
 *     MIX_ENV=test mix run -e '
 *       alias Ash.Info.Manifest
 *       alias Ash.Info.Manifest.{Action, Entrypoint}
 *       r = AshSurface.Fixtures.VolunteerMilestone
 *       full = %Manifest{entrypoints: [
 *         %Entrypoint{resource: r, action: %Action{name: :read, type: :read, custom: %{}}},
 *         %Entrypoint{resource: r, action: %Action{name: :record, type: :create, custom: %{}}}]}
 *       read_only = %Manifest{entrypoints: [
 *         %Entrypoint{resource: r, action: %Action{name: :read, type: :read, custom: %{}}}]}
 *       {:ok, s} = AshSurface.from_manifest(manifest, profile: profile)
 *       IO.puts(s.digest); IO.puts(Jason.encode!(s.contract))
 *       '
 *
 * F1 = full manifest, empty profile. F2 = full manifest, rich profile (strings
 * incl. UTF-8, nil, float 1.5, small/int32/negative/big ints, nested maps,
 * lists, per-action profiles). F3 = read-only manifest with a per-action
 * transport profile. The exact contract JSON Elixir digested is embedded with
 * each golden, so these tests pin, byte-for-byte: canonical map->tuple-list
 * sorting, BIT_BINARY (0x6d), SMALL_ATOM_UTF8 (0x77, nil/true/false),
 * SMALL_INTEGER (0x61), INTEGER (0x62), SMALL_BIG (0x6e), NEW_FLOAT (0x46),
 * NIL (0x6a), LIST (0x6c), and SMALL_TUPLE (0x68) exactly as emitted by
 * :erlang.term_to_binary/1 on the golden-generating build.
 */

const GOLDENS = [
  {
    name: "F1 minimal contract (read + record, empty profile)",
    elixirDigest: "1de44c2c6399cc7daa815c2e546b1611e8f7d3e2dad2a3cd22c72b940c72514d",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.13","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"},{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"af93be319ad1444518422a97f02f345dfba8e076445ec77d18e69e530d3e477a","marketplaceIdentity":"ggen-marketplace:v26.9.13","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"},{"action":"record","authorityBoundary":"DO","doAuthority":true,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#record","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"profile":{}},"surfaceSchemaVersion":"26.9.13"}',
  },
  {
    name: "F2 rich profile (full type coverage on the projection metadata)",
    elixirDigest: "6c615209816759096e63becb2750adc736d785f3b8dfdac952779af57b342d18",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.13","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"},{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"af93be319ad1444518422a97f02f345dfba8e076445ec77d18e69e530d3e477a","marketplaceIdentity":"ggen-marketplace:v26.9.13","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{"consumer":"web","transport":"http"},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"},{"action":"record","authorityBoundary":"DO","doAuthority":true,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#record","possibleRefusals":["REFUSED_NO_AUTHORITY","REFUSED_GENERATOR_OWNED"],"profile":{"consumer":"mobile","possibleRefusals":["REFUSED_NO_AUTHORITY","REFUSED_GENERATOR_OWNED"],"quota":42},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"profile":{"audience":"operators","limits":{"hard":-7,"soft":300,"tiny":42},"note":null,"observed_at_ms":1730000000000,"rating":1.5,"region":"eu-west","tags":["web","mobile","héllo ✓"]}},"surfaceSchemaVersion":"26.9.13"}',
  },
  {
    name: "F3 read-only contract with per-action transport profile",
    elixirDigest: "1ccea7fb0ae0190c7d18a9da30f5da38843917111d1c67ba8a955f511445de47",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.13","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"c40b103081fb6909366d75fdfe06453a4e13ab625ea3829b3c4e16b8bb9f3c09","marketplaceIdentity":"ggen-marketplace:v26.9.13","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{"consumer":"web","transport":"phoenix_channel"},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"}],"profile":{}},"surfaceSchemaVersion":"26.9.13"}',
  },
];

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

function reverseKeyOrder(value) {
  if (Array.isArray(value)) return value.map(reverseKeyOrder);
  if (value !== null && typeof value === "object") {
    const reversed = {};
    for (const key of Object.keys(value).reverse()) reversed[key] = reverseKeyOrder(value[key]);
    return reversed;
  }
  return value;
}

function clientFor(fixture) {
  return createClient({ contract: JSON.parse(fixture.contractJson) });
}

test("runtime-held contract digest equals the Elixir-computed golden for every fixture", () => {
  for (const fixture of GOLDENS) {
    const client = clientFor(fixture);
    assert.equal(client.runtimeVersion, "26.9.13", `${fixture.name}: runtime version`);
    assert.equal(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});

test("golden digests are 64-character lowercase hex", () => {
  for (const fixture of GOLDENS) {
    assert.match(fixture.elixirDigest, /^[0-9a-f]{64}$/, fixture.name);
  }
});

test("digest is stable across contract key insertion order (canonical sort, not JSON order)", () => {
  const rich = GOLDENS[1];
  const client = createClient({ contract: reverseKeyOrder(JSON.parse(rich.contractJson)) });
  assert.equal(contractDigest(client.contract), rich.elixirDigest);
});

test("projection profile metadata participates in the digest", () => {
  const minimal = contractDigest(clientFor(GOLDENS[0]).contract);
  const rich = contractDigest(clientFor(GOLDENS[1]).contract);
  assert.notEqual(minimal, rich);
});

test("a one-character profile mutation changes the digest", () => {
  const rich = GOLDENS[1];
  const contract = JSON.parse(rich.contractJson);
  contract.surface.profile.audience = "operatorz";
  const client = createClient({ contract });
  assert.notEqual(contractDigest(client.contract), rich.elixirDigest);
});
