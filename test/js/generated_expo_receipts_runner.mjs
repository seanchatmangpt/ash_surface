import assert from "node:assert/strict";
import crypto from "node:crypto";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for a manufactured `<prefix>.receipts.mjs`.
// The module is verification-only: it validates envelopes and exposes the
// canonical preimage; it never constructs, signs or assigns a receipt.
// spec: { prefix, receipt } - `receipt` is a content-complete envelope whose
// receiptHash was computed OUTSIDE the module (Elixir CanonicalJSON sha256).

const [targetDir, specPath] = process.argv.slice(2);
if (!targetDir || !specPath) {
  throw new Error("usage: node generated_expo_receipts_runner.mjs <targetDir> <specPath>");
}

const spec = JSON.parse(await readFile(specPath, "utf8"));

// Purity: no entropy, clock, or I/O anywhere in the module.
const trap = (name) => () => { throw new Error(`receipts module touched ${name}`); };
globalThis.fetch = trap("fetch");
globalThis.WebSocket = trap("WebSocket");
globalThis.XMLHttpRequest = trap("XMLHttpRequest");
Math.random = trap("Math.random");
Date.now = trap("Date.now");

const mod = await import(pathToFileURL(join(targetDir, `${spec.prefix}.receipts.mjs`)).href);

// Verification-only export surface: no constructor of any kind.
assert.deepEqual(Object.keys(mod).sort(), ["canonicalStringify", "mxReceiptSchema", "receiptHashPreimage"]);

const sha256 = (s) => crypto.createHash("sha256").update(s).digest("hex");
const good = spec.receipt;
const rejects = (patch, label) => {
  const r = { ...good, ...patch };
  for (const [k, v] of Object.entries(patch)) if (v === undefined) delete r[k];
  assert.equal(mod.mxReceiptSchema.safeParse(r).success, false, `must reject ${label}`);
};

// A good envelope validates and its hash verifies against the preimage.
const parsed = mod.mxReceiptSchema.parse(good);
assert.equal(parsed.receiptHash, good.receiptHash);
assert.equal(sha256(mod.receiptHashPreimage(good)), good.receiptHash, "good receipt hash must verify");

// The preimage excludes the receiptHash slot and is reorder-invariant.
assert.ok(!mod.receiptHashPreimage(good).includes("receiptHash"));
const reversed = Object.fromEntries(Object.entries(good).reverse());
assert.equal(mod.receiptHashPreimage(reversed), mod.receiptHashPreimage(good));
assert.equal(mod.canonicalStringify({ b: [2, { d: 1, c: 0 }], a: null }), '{"a":null,"b":[2,{"c":0,"d":1}]}');

// A tampered envelope no longer verifies: any content change moves the hash.
for (const patch of [{ outcome: "REFUSED" }, { postStateDigest: "sd_forged" }, { evidenceRefs: [] }, { transportReceipt: { selected: "ws" } }]) {
  const tampered = { ...good, ...patch };
  assert.notEqual(sha256(mod.receiptHashPreimage(tampered)), tampered.receiptHash, `tamper ${Object.keys(patch)[0]}`);
}

// Envelope schema: required / enumerated slots.
rejects({ transportReceipt: undefined }, "missing transport evidence");
rejects({ correlationId: "" }, "empty correlationId");
rejects({ replayKey: "" }, "empty replayKey");
rejects({ outcome: "SUCCESS" }, "bare-success outcome");
rejects({ outcome: "PENDING" }, "client-side PENDING");
rejects({ authorityBoundary: "ROOT" }, "unknown boundary");
rejects({ receiptHash: "abc" }, "short receiptHash");
rejects({ receiptHash: undefined }, "missing receiptHash (nothing mints one)");
for (const boundary of ["OBSERVE", "SELECT", "CONSTRUCT", "DO"]) {
  assert.ok(mod.mxReceiptSchema.safeParse({ ...good, authorityBoundary: boundary }).success, boundary);
}
for (const outcome of ["COMPLETED", "REFUSED", "UNKNOWN_AFTER_DISPATCH"]) {
  assert.ok(mod.mxReceiptSchema.safeParse({ ...good, outcome }).success, outcome);
}

// The server ref is never invented: an absent domainReceiptRef stays absent;
// evidence defaults to empty, not to fabrication.
const bare = { ...good };
delete bare.domainReceiptRef;
delete bare.evidenceRefs;
const bareParsed = mod.mxReceiptSchema.parse(bare);
assert.equal(bareParsed.domainReceiptRef, undefined);
assert.deepEqual(bareParsed.evidenceRefs, []);

// Non-envelope subjects are refused by the preimage formula.
for (const subject of [null, 42, "receipt", [good]]) {
  assert.throws(() => mod.receiptHashPreimage(subject), TypeError);
}

console.log(JSON.stringify({ receipt: "GENERATED_EXPO_RECEIPTS_PASS", verified: true, tamperRefused: true }));
