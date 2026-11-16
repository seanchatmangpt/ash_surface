// Pure helpers for the OpenAPI explorer (unit-tested under bun test).
const METHODS = ["get", "post", "patch", "put", "delete"];

export function resolveRef(spec, node) {
  let n = node, guard = 0;
  while (n && n.$ref && guard++ < 20) {
    n = n.$ref.replace(/^#\//, "").split("/").reduce((a, k) => a?.[k.replace(/~1/g, "/").replace(/~0/g, "~")], spec);
  }
  return n;
}

// Flatten a JSON schema into rows [{path, type, required, description, depth}] (cycle-safe).
export function flattenSchema(spec, schema, opts = {}) {
  const { maxDepth = 6 } = opts;
  const rows = [];
  const seen = new Set();
  const walk = (node, path, depth, required) => {
    const refKey = node?.$ref;
    const s = resolveRef(spec, node);
    if (!s || typeof s !== "object") return;
    const variants = s.oneOf || s.anyOf;
    if (s.allOf) {
      s.allOf.forEach((p) => walk(p, path, depth, required));
      return;
    }
    let type = s.type;
    if (Array.isArray(type)) type = type.join("|");
    if (!type && s.properties) type = "object";
    if (!type && variants) type = variants.map((v) => resolveRef(spec, v)?.type || "any").join("|");
    if (type === "array") type = `array<${resolveRef(spec, s.items)?.type || "any"}>`;
    if (path) rows.push({ path, type: type || "any", required: !!required, description: s.description || "", depth, nullable: !!s.nullable });
    if (refKey) {
      if (seen.has(refKey)) return;
      seen.add(refKey);
    }
    if (depth >= maxDepth) return;
    if (s.properties) {
      const req = new Set(s.required || []);
      for (const [k, v] of Object.entries(s.properties)) walk(v, path ? `${path}.${k}` : k, depth + 1, req.has(k));
    }
    if (s.items) walk(s.items, path ? `${path}[]` : "[]", depth + 1, false);
    if (refKey) seen.delete(refKey);
  };
  walk(schema, "", 0, false);
  return rows;
}

function bodySchema(spec, content) {
  if (!content) return null;
  const c = content["application/vnd.api+json"] || content["application/json"] || Object.values(content)[0];
  return c?.schema || null;
}

// Group operations by first tag: [{tag, operations:[{method,path,summary,parameters,requestBody,responses,id}]}]
export function groupOperations(spec) {
  const groups = new Map();
  for (const [path, item] of Object.entries(spec?.paths || {})) {
    for (const method of METHODS) {
      const op = item?.[method];
      if (!op) continue;
      const tag = (op.tags && op.tags[0]) || "default";
      const common = (item.parameters || []).map((p) => resolveRef(spec, p));
      const operation = {
        id: `${method.toUpperCase()} ${path}`,
        method: method.toUpperCase(),
        path,
        summary: op.summary || op.description || "",
        parameters: [...common, ...(op.parameters || []).map((p) => resolveRef(spec, p))].filter(Boolean),
        requestSchema: bodySchema(spec, resolveRef(spec, op.requestBody)?.content),
        responses: Object.entries(op.responses || {}).map(([status, r]) => {
          const rr = resolveRef(spec, r);
          return { status, description: rr?.description || "", schema: bodySchema(spec, rr?.content) };
        }),
      };
      if (!groups.has(tag)) groups.set(tag, []);
      groups.get(tag).push(operation);
    }
  }
  return [...groups.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([tag, operations]) => ({ tag, operations }));
}

// Build the request URL: substitute {path} params, append query params.
export function buildUrl(path, params = {}, values = {}) {
  let url = path;
  const q = new URLSearchParams();
  for (const p of params) {
    const v = values[p.name];
    if (p.in === "path") url = url.replace(`{${p.name}}`, encodeURIComponent(v ?? ""));
    else if (p.in === "query" && v !== undefined && v !== "") q.append(p.name, v);
  }
  const s = q.toString();
  return s ? `${url}?${s}` : url;
}
