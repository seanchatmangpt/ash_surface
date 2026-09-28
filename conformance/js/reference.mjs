// Reference JavaScript implementation of the AshSurface digest laws, for use by
// the conformance replay and by any JavaScript-family projection that wants to
// self-certify. Ordinary ESM JavaScript: no TypeScript, no build step.
//
// These are TWINS of the Elixir laws (AshSurface.CanonicalJSON,
// AshSurface.IR.Codec.digest/1, AshSurface.IR.EventProjection receipt binding).
// The priv/static runtime exports none of them (it holds contracts, it does not
// mint digests), so a projection must bring its own; this file is the one the
// corpus is certified against.
//
// Known limit (recorded, not hidden): JavaScript numbers cannot carry the
// int/float distinction or the Erlang float spelling, so vectors of level
// PENDING_DECISION cannot pass here (see conformance/js/known_divergences.mjs).

import crypto from "node:crypto";

export function sha256Hex(input) {
  return crypto.createHash("sha256").update(input).digest("hex");
}

export function byUtf8Bytes(a, b) {
  return Buffer.compare(Buffer.from(a, "utf8"), Buffer.from(b, "utf8"));
}

// Jason (the Elixir encoder) writes control characters other than \b \t \n \f \r
// as \u00XX with UPPERCASE hex; JSON.stringify writes lowercase. The Elixir
// spelling is the corpus law.
function jsonString(text) {
  return JSON.stringify(text).replace(/\\u00([0-9a-f]{2})/g, (_m, hex) => `\\u00${hex.toUpperCase()}`);
}

export function canonicalJson(value) {
  if (value === null || typeof value !== "object") {
    return typeof value === "string" ? jsonString(value) : JSON.stringify(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  const keys = Object.keys(value).sort(byUtf8Bytes);
  return `{${keys.map((key) => `${jsonString(key)}:${canonicalJson(value[key])}`).join(",")}}`;
}

// The naive minting law found in test/js/consumer_e2e_runner.mjs
// (`canonicalStringify`), copied verbatim so the corpus can pin exactly where the
// shipped runner disagrees with the Elixir law.
export function naiveCanonicalStringify(obj) {
  if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(naiveCanonicalStringify).join(",")}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${naiveCanonicalStringify(obj[k])}`).join(",")}}`;
}

// ---- ETF twin of the frozen canonical-term digest (AshSurface.digest/1, IR.Codec.digest/1)

class EtfTuple {
  constructor(elements) {
    this.elements = elements;
  }
}

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

function encodeAtom(name, chunks) {
  const bytes = Buffer.from(name, "utf8");
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
    const digits = [];
    for (let mag = BigInt(value < 0 ? -value : value); mag > 0n; mag >>= 8n) digits.push(Number(mag & 0xffn));
    chunks.push(Buffer.from([0x6e, digits.length, value < 0 ? 1 : 0]), Buffer.from(digits));
  }
}

function encodeTerm(value, chunks) {
  if (value === null) return encodeAtom("nil", chunks);
  if (value === true) return encodeAtom("true", chunks);
  if (value === false) return encodeAtom("false", chunks);
  if (typeof value === "string") return encodeBinary(value, chunks);
  if (typeof value === "number") {
    if (Number.isSafeInteger(value)) return encodeInteger(value, chunks);
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
  throw new Error(`value is not part of the canonical term space: ${typeof value}`);
}

export function canonicalTermDigest(value) {
  const chunks = [Buffer.from([0x83])];
  encodeTerm(canonicalTerm(value), chunks);
  return sha256Hex(Buffer.concat(chunks));
}

// ---- receipt law (AshSurface.IR.EventProjection.bind_receipt_digest/1)

export const RECEIPT_COVERED_SECTIONS = Object.freeze([
  "actionId",
  "input",
  "consequence",
  "dispatchState",
  "selectedTransport",
  "timestamp",
]);

export function receiptCoveredPayload(receipt) {
  return Object.fromEntries(RECEIPT_COVERED_SECTIONS.map((key) => [key, receipt[key] ?? null]));
}

export function receiptHash(receipt) {
  return sha256Hex(canonicalJson(receiptCoveredPayload(receipt)));
}

/**
 * Digest-binding verdict of a receipt: "mismatch" when any slot that can become
 * the event receipt_ref (receiptHash, receiptRef) is exactly 64 bytes yet does not
 * equal the recomputed hash; otherwise "no_mismatch" (bound, opaque, or absent).
 */
export function receiptBinding(receipt) {
  const actual = receiptHash(receipt);
  for (const slot of [receipt.receiptHash, receipt.receiptRef]) {
    if (typeof slot === "string" && Buffer.byteLength(slot, "utf8") === 64 && slot !== actual) {
      return "mismatch";
    }
  }
  return "no_mismatch";
}

/** Event state digest law (AshSurface.Event.create/4). */
export function eventStateDigest(subjectRef, sequence, eventType, payload) {
  return sha256Hex(`${subjectRef}:${sequence}:${eventType}:${canonicalJson(payload)}`);
}
