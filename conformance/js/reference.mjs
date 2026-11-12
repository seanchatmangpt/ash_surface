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

// ---- zod projection twin (AshSurface.Compiler.Schema + ZodType, lanes L14/w3-04) ------
//
// JS twin of the schema section's zod projection and of the shared
// `AshSurface.Compiler.ZodType` fragment table: base kind table, constraint
// chain in the frozen order one_of -> min/max -> gt/lt -> min_length (with
// allow_empty?) -> max_length -> match, bounds only on numeric kinds, string
// length only on string kinds (array cardinality on arrays), regex only on
// string kinds, constraints riding on the ARGUMENT definition (not inside
// `type`), allow_nil? -> .nullable() then omittable -> .optional(),
// NewType subtype_of/subtype_constraints, quoted keys for non-identifier names.
//
// Regex law (current Elixir): the source is translated PCRE -> JS (see
// translateRegex: PCRE-only syntax is DROPPED, no .regex emitted; a trailing `$`
// becomes `(?=\n?$)` unless flag m); then only an UNESCAPED `/` is escaped
// (`a/b` -> `a\/b`) and backslash pairs pass through untouched (`\d+` stays `\d+`);
// flags are the sorted unique subset of i/m/s.

const ZOD_KINDS = Object.freeze({
  string: "z.string()", ci_string: "z.string()", integer: "z.number().int()",
  boolean: "z.boolean()", uuid: "z.guid()", float: "z.number()", decimal: "z.string()",
  date: "z.iso.date()", time: "z.iso.time()", utc_datetime: "z.iso.datetime()",
  utc_datetime_usec: "z.iso.datetime()", datetime: "z.iso.datetime()",
  naive_datetime: "z.iso.datetime({local: true})", duration: "z.iso.duration()", binary: "z.string()",
  atom: "z.string()", term: "z.any()", map: "z.record(z.string(), z.unknown())",
  array: "z.array(z.unknown())", vector: "z.array(z.number())",
  uuid_v7: "z.uuid()", time_usec: "z.iso.time()", duration_name: "z.string()",
  url_encoded_binary: "z.string()", module: "z.string()", file: "z.any()",
  function: "z.any()", any: "z.any()", keyword: "z.record(z.string(), z.unknown())",
  tuple: "z.record(z.string(), z.unknown())", struct: "z.record(z.string(), z.unknown())",
  enum: "z.string()",
});

const NUMERIC_KINDS = new Set(["integer", "float"]);
const STRING_KINDS = new Set(["string", "ci_string", "uuid", "uuid_v7", "date", "time", "time_usec",
  "utc_datetime", "utc_datetime_usec", "datetime", "naive_datetime", "duration", "binary", "atom", "decimal"]);
const LENGTH_KINDS = new Set(["string", "ci_string", "binary", "array"]);
const STRING_LENGTH_KINDS = new Set(["string", "ci_string", "binary"]);

// PCRE -> JS regex translation (twin of ZodType.translate_regex/2, S1-F). Returns
// {ok: body} or {error: reason}: the source is scanned honouring escapes and
// character classes; PCRE-only syntax, raw line terminators, unbalanced groups and
// nothing-to-repeat quantifiers are typed refusals (the constraint is DROPPED, never
// emitted); an unescaped `$` outside a class becomes `(?=\n?$)` (PCRE `$` also
// matches before one final newline) unless the `m` flag is on.
const PCRE_ESCAPES = new Set(Array.from("pPzZhHRKQEAGXg"));

function translateRegex(source, flags) {
  if (source === "") return { error: "empty_pattern" };
  if (/[\n\r\u2028\u2029]/.test(source)) return { error: "raw_line_terminator" };
  const multiline = flags.includes("m");
  const cs = Array.from(source);
  let inClass = false;
  let depth = 0;
  let prev = "start";
  let out = "";
  for (let i = 0; i < cs.length; i += 1) {
    const ch = cs[i];
    const rest = cs.slice(i + 1);
    if (ch === "\\") {
      if (rest.length === 0) return { error: "trailing_backslash" };
      if (PCRE_ESCAPES.has(rest[0])) return { error: "pcre_only" };
      out += ch + rest[0];
      prev = "atom";
      i += 1;
      continue;
    }
    if (inClass) {
      if (ch === "[" && /^:\^?[a-z]+:\]/.test(rest.join(""))) return { error: "pcre_only" };
      if (ch === "]") {
        inClass = false;
        prev = "atom";
      }
      out += ch;
      continue;
    }
    if (ch === "[") { inClass = true; prev = "atom"; out += ch; continue; }
    if (ch === "(") {
      if (rest[0] === "?") {
        const x = rest[1];
        if (x === ":" || x === "=" || x === "!") {
          depth += 1; prev = "open"; out += `(?${x}`; i += 2; continue;
        }
        if (x === "<") {
          const y = rest[2];
          if (y === "=" || y === "!") return { error: "pcre_only" };
          if (y !== undefined) { depth += 1; prev = "open"; out += `(?<${y}`; i += 3; continue; }
        }
        return { error: "pcre_only" };
      }
      depth += 1; prev = "open"; out += ch; continue;
    }
    if (ch === ")") {
      if (depth === 0) return { error: "unbalanced_parens" };
      depth -= 1; prev = "atom"; out += ch; continue;
    }
    if (ch === "|") { prev = "open"; out += ch; continue; }
    if (ch === "*" || ch === "+" || ch === "?") {
      if (prev === "start" || prev === "open") return { error: "nothing_to_repeat" };
      if (ch === "+" && (prev === "quant" || prev === "lazy")) return { error: "pcre_only" };
      prev = ch === "?" && prev === "quant" ? "lazy" : "quant";
      out += ch;
      continue;
    }
    if (ch === "$" && !multiline) { out += "(?=\\n?$)"; prev = "atom"; continue; }
    out += ch;
    prev = "atom";
  }
  if (inClass) return { error: "unterminated_class" };
  if (depth !== 0) return { error: "unbalanced_parens" };
  return { ok: out };
}

export const regexSafeForJs = (source) => translateRegex(source, "").ok !== undefined;

// Escape only unescaped `/`; backslash pairs pass through untouched.
function escapeSlashes(source) {
  const chars = Array.from(source);
  let out = "";
  for (let i = 0; i < chars.length; i += 1) {
    if (chars[i] === "\\" && i + 1 < chars.length) {
      out += chars[i] + chars[i + 1];
      i += 1;
    } else if (chars[i] === "/") {
      out += "\\/";
    } else {
      out += chars[i];
    }
  }
  return out;
}

const jsFlags = (flags) =>
  typeof flags === "string"
    ? [...new Set(Array.from(flags).filter((f) => "ims".includes(f)))].sort().join("")
    : "";

const asMap = (v) => (v !== null && typeof v === "object" && !Array.isArray(v) ? v : {});
const present = (v) => v !== undefined && v !== null && v !== false;

// Canonical numeric literal: ECMAScript Number::toString, -0 -> "0" (twin of
// AshSurface.Compiler.NumberLiteral.render!/1).
export const numberLiteral = (n) => (Object.is(n, -0) ? "0" : String(n));

function numericBound(c, kind, key, zod) {
  return NUMERIC_KINDS.has(kind) && typeof c[key] === "number" ? `.${zod}(${numberLiteral(c[key])})` : "";
}

function lengthBound(c, kind, key, zod) {
  return LENGTH_KINDS.has(kind) && Number.isInteger(c[key]) ? `.${zod}(${c[key]})` : "";
}

function minLengthBound(c, kind) {
  if (!STRING_LENGTH_KINDS.has(kind)) return lengthBound(c, kind, "min_length", "min");
  const explicit = Number.isInteger(c.min_length) ? c.min_length : null;
  if (c["allow_empty?"] === false) return `.min(${Math.max(explicit ?? 1, 1)})`;
  return explicit !== null ? `.min(${explicit})` : "";
}

function constraintChain(kind, constraints) {
  const c = asMap(constraints);
  let out = numericBound(c, kind, "min", "min") + numericBound(c, kind, "max", "max") +
    numericBound(c, kind, "greater_than", "gt") + numericBound(c, kind, "less_than", "lt") +
    minLengthBound(c, kind) + lengthBound(c, kind, "max_length", "max");
  if (STRING_KINDS.has(kind) && typeof c.match === "string") {
    const flags = jsFlags(c.match_flags);
    const translated = translateRegex(c.match, flags);
    if (translated.ok !== undefined) out += `.regex(/${escapeSlashes(translated.ok)}/${flags})`;
  }
  return out;
}

const byBinary = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

function enumFragment(kind, values) {
  if (NUMERIC_KINDS.has(kind)) {
    const lits = [...new Set(values)].sort((a, b) => a - b).map((v) => `z.literal(${JSON.stringify(v)})`);
    return lits.length === 1 ? lits[0] : `z.union([${lits.join(", ")}])`;
  }
  const strs = [...new Set(values.map(String))].sort(byBinary).map((v) => JSON.stringify(v));
  return `z.enum([${strs.join(", ")}])`;
}

function itemsOf(definition) {
  const type = asMap(definition.type);
  const item = [type.items, type.item_type, definition.items, definition.item_type].find(present);
  if (item && typeof item === "object" && !Array.isArray(item)) {
    if ("kind" in item) return { type: item };
    if (Object.keys(item).length > 0) return item;
  }
  return null;
}

function baseFor(kind, definition) {
  if (kind === "enum") {
    const values = [asMap(definition.type).values, definition.values].find(present);
    return Array.isArray(values) && values.length > 0 ? enumFragment("string", values) : "z.string()";
  }
  if (kind === "array") {
    const item = itemsOf(definition);
    return item ? `z.array(${zodFragment(item)})` : ZOD_KINDS.array;
  }
  return ZOD_KINDS[kind] ?? "z.unknown()";
}

function valueFragment(kind, definition, constraints) {
  const c = asMap(constraints);
  if (Array.isArray(c.one_of) && c.one_of.length > 0) return enumFragment(kind, c.one_of);
  return baseFor(kind, definition) + constraintChain(kind, c);
}

function wrap(expr, d) {
  let out = expr;
  if (d["allow_nil?"] === true || d.allow_nil === true) out += ".nullable()";
  if (d.optional === true || d["required?"] === false || d.has_default === true || "default" in d) {
    out += ".optional()";
  }
  return out;
}

export function zodFragment(definition) {
  const d = asMap(definition);
  const type = d.type;
  if (type !== null && typeof type === "object" && typeof type.kind === "string") {
    return wrap(valueFragment(type.kind, d, d.constraints), d);
  }
  if (typeof d.subtype_of === "string") {
    return wrap(valueFragment(d.subtype_of, d, d.subtype_constraints), d);
  }
  return "z.unknown()";
}

function zodKey(name) {
  return /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name) ? name : JSON.stringify(name);
}

const sanitizeIdentifier = (id) => id.replace(/[^a-zA-Z0-9_]/g, "_");

export function zodProjection(action) {
  const safe = sanitizeIdentifier(action.id);
  const args = action.arguments ?? [];
  const fields = args.map((a) => `  ${zodKey(a.name)}: ${zodFragment(a)}`).join(",\n");
  const output = action.returns === undefined || action.returns === null
    ? "z.undefined()"
    : zodFragment(action.returns);
  return `export const ${safe}_inputSchema = z.object({\n${fields}\n}).passthrough();\n\nexport const ${safe}_outputSchema = ${output};\n`;
}

// Twin of Schema.build/2's admission half (id/arguments shape); fragment
// rendering happens per surviving action. Error `detail` is diagnostic, so the
// handler compares `kind` only.
export function schemaProjection(discovery) {
  if (discovery === null || typeof discovery !== "object" || Array.isArray(discovery)) {
    return { error: { kind: "discovery_must_be_a_map" } };
  }
  const actions = discovery.actions ?? [];
  if (!Array.isArray(actions)) return { error: { kind: "actions_must_be_a_list" } };
  for (const action of actions) {
    if (typeof action?.id !== "string") return { error: { kind: "action_without_id" } };
  }
  const zod = {};
  let argumentCount = 0;
  for (const action of actions) {
    const args = action.arguments ?? [];
    if (!Array.isArray(args)) return { error: { kind: "arguments_must_be_a_list" } };
    if (!args.every((a) => typeof a?.name === "string")) {
      return { error: { kind: "argument_without_name" } };
    }
    if (action.returns !== undefined && action.returns !== null &&
        (typeof action.returns !== "object" || Array.isArray(action.returns))) {
      return { error: { kind: "invalid_returns" } };
    }
    zod[action.id] = zodProjection(action);
    argumentCount += args.length;
  }
  return { zod, actionCount: Object.keys(zod).length, argumentCount };
}

// ---- error vocabulary twin (AshSurface.IR.ErrorShape, lane w3-04) ---------------------
//
// The closed error-type enum is a LAW both languages carry; the corpus mints the
// Elixir list (`error_envelope` render "types") and this twin must equal it.
export const ERROR_TYPES = Object.freeze([
  "invalid_changes", "invalid_query", "not_found", "required", "forbidden", "forbidden_field",
  "invalid_attribute", "invalid_argument", "invalid_keyset", "invalid_page", "tenant_required",
  "invalid_primary_key", "unknown_error", "authentication_failed", "invalid_token",
  "invalid_identity", "missing_identity", "sort_not_supported", "pagination_not_supported",
  "invalid_pagination",
]);

export const normalizeErrorType = (type) =>
  typeof type === "string" && ERROR_TYPES.includes(type) ? type : "unknown_error";

// ---- field-name emission twin (lane RBV) ------------------------------------------------
//
// Independent re-derivation from the reference rule (ash_typescript helpers.ex:25-30,
// Macro.camelize then lowercase-first) plus KD-13 (leading underscores preserved). Never
// reads corpus expectations. Macro.camelize is ASCII-only and byte-oriented: only a-z are
// upcased; `__` collapses; `_` + [a-z0-9] drops the underscore; a trailing `_` is dropped;
// `/` becomes `.`; leading `_` are stripped (recursively).
const isLower = (c) => c >= "a" && c <= "z";
const isDigit = (c) => c >= "0" && c <= "9";
const upAscii = (c) => (isLower(c) ? c.toUpperCase() : c);

export function macroCamelize(input) {
  const s = Array.from(input);
  let i = 0;
  while (i < s.length && s[i] === "_") i += 1;
  if (i >= s.length) return "";
  let out = upAscii(s[i]);
  i += 1;
  while (i < s.length) {
    const c = s[i];
    if (c === "_") {
      if (s[i + 1] === "_") { i += 1; continue; } // `__` -> `_`
      const n = s[i + 1];
      if (n === undefined) { i += 1; continue; } // trailing `_`
      if (isLower(n)) { out += n.toUpperCase(); i += 2; continue; }
      if (isDigit(n)) { out += n; i += 2; continue; }
      out += c; i += 1; continue;
    }
    if (c === "/") {
      // `/` -> `.` then the rest is camelized afresh (leading `_` stripped, first upcased)
      out += "." + macroCamelize(s.slice(i + 1).join(""));
      return out;
    }
    out += c; i += 1;
  }
  return out;
}

export function emittedFieldName(name, formatter) {
  if (formatter === "snake_case") return name;
  const rest = name.replace(/^_+/, "");
  const lead = "_".repeat(Array.from(name).length - Array.from(rest).length);
  const camel = macroCamelize(rest);
  if (formatter === "pascal_case") return lead + camel;
  const [head, ...tail] = Array.from(camel);
  return lead + (head === undefined ? "" : head.toLowerCase() + tail.join(""));
}

// Built-in inverse spelling (client key -> internal name), used by the invertibility check.
export const clientToInternalName = (s, formatter) =>
  formatter === "snake_case"
    ? s
    : s
        .replace(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
        .replace(/([a-z\d])([A-Z])/g, "$1_$2")
        .toLowerCase();

export function emittedKeyCollision(names, formatter) {
  const groups = new Map();
  for (const name of new Set(names)) {
    const key = emittedFieldName(name, formatter);
    groups.set(key, [...(groups.get(key) ?? []), name]);
  }
  for (const key of [...groups.keys()].sort(byUtf8Bytes)) {
    if (groups.get(key).length > 1) return { key, names: groups.get(key).sort(byUtf8Bytes) };
  }
  return null;
}

export function admittedInverse(client, formatter, admitted) {
  if (client === "") return null;
  const hits = [...new Set(admitted.filter((n) => emittedFieldName(n, formatter) === client))];
  return hits.length === 1 ? hits[0] : null;
}
