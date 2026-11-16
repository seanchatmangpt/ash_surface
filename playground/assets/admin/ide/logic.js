// Pure client logic for Ash Studio (no DOM, no fetch) -- unit-tested with bun.

// Split on top-level commas, respecting quotes and brackets.
export function splitArgs(s) {
  const out = [];
  let depth = 0, quote = null, cur = "";
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quote) {
      cur += c;
      if (c === "\\") cur += s[++i] ?? "";
      else if (c === quote) quote = null;
    } else if (c === '"' || c === "'") { quote = c; cur += c; }
    else if ("[{(".includes(c)) { depth++; cur += c; }
    else if ("]})".includes(c)) { depth--; cur += c; }
    else if (c === "," && depth === 0) { out.push(cur); cur = ""; }
    else cur += c;
  }
  if (cur.trim()) out.push(cur);
  return out.map((x) => x.trim()).filter(Boolean);
}

function parseValue(raw) {
  try { return JSON.parse(raw); } catch { /* fall through */ }
  if (raw.startsWith(":")) return raw.slice(1);
  if (raw === "nil") return null;
  return raw;
}

// `Post.create(title: "x", points: 3)` -> { resource, action, id?, params }
export function parseCommand(src) {
  const m = /^\s*([A-Za-z_][\w.]*)\.([a-z_][\w?!]*)\s*(?:\(([\s\S]*)\))?\s*$/.exec(src ?? "");
  if (!m) return { error: "expected Resource.action(key: value, ...)" };
  const [, resource, action, inner = ""] = m;
  const params = {};
  let id;
  for (const part of splitArgs(inner)) {
    const k = /^"?([A-Za-z_]\w*)"?\s*:\s*([\s\S]+)$/.exec(part);
    if (!k) return { error: `bad argument: ${part}` };
    if (k[1] === "id") id = parseValue(k[2]);
    else params[k[1]] = parseValue(k[2]);
  }
  return { resource, action, ...(id !== undefined ? { id } : {}), params };
}

// Resolve a short/full resource name against [{name,module}].
export function resolveResource(name, resources) {
  return resources.find((r) => r.module === name || r.name === name || r.module.endsWith(`.${name}`));
}

export function toRunBody(cmd, resources, ctx = {}) {
  const res = resolveResource(cmd.resource, resources);
  if (!res) return { error: `unknown resource ${cmd.resource}` };
  return { module: res.module, body: { ...ctx, resource: res.module, action: cmd.action, ...(cmd.id !== undefined ? { id: cmd.id } : {}), params: cmd.params } };
}

export function flattenTree(nodes) {
  return nodes.flatMap((n) => (n.children ? flattenTree(n.children) : [n]));
}

// Sequential queue: runs every item in order (an error does not stop the rest); each result is reported.
export async function runQueue(items, runFn, onResult = () => {}) {
  const results = [];
  for (let i = 0; i < items.length; i++) {
    let r;
    try { r = await runFn(items[i], i); }
    catch (e) { r = { command: items[i].command, status: "error", duration_ms: 0, lines: [String(e.message ?? e)], result: null }; }
    results.push(r);
    onResult(r, i);
  }
  return results;
}
