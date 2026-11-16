// Longest-path layered layout (left to right) for the introspected graph.
export function layout(nodes, edges, { dx = 420, dy = 190 } = {}) {
  const preds = new Map(nodes.map((n) => [n.id, []]));
  for (const e of edges) preds.get(e.target)?.push(e.source);
  const depth = new Map();
  const visit = (id, seen = new Set()) => {
    if (depth.has(id)) return depth.get(id);
    if (seen.has(id)) return 0;
    seen.add(id);
    const d = Math.max(-1, ...(preds.get(id) ?? []).map((p) => visit(p, seen))) + 1;
    depth.set(id, d);
    return d;
  };
  nodes.forEach((n) => visit(n.id));
  const cols = new Map();
  const pos = {};
  for (const n of nodes) {
    const d = depth.get(n.id);
    const row = cols.get(d) ?? 0;
    cols.set(d, row + 1);
    pos[n.id] = { x: d * dx, y: row * dy };
  }
  // center each column vertically
  const maxRows = Math.max(...cols.values(), 1);
  for (const n of nodes) {
    const d = depth.get(n.id);
    pos[n.id].y += ((maxRows - cols.get(d)) * dy) / 2;
  }
  return pos;
}

// Fold run events (in order) into {steps, running edges} state.
export function statusesAt(events, upto) {
  const s = {};
  for (const e of events.slice(0, upto)) s[e.step] = e.status;
  return s;
}

export function edgeKind(edge, statuses, active) {
  if (!active) return "plain";
  const t = statuses[edge.target];
  const src = statuses[edge.source];
  if (t === "running") return "animated";
  if (t === "ok" || t === "error" || t === "undone" || t === "undoing") return t === "ok" ? "done" : "plain";
  if (edge.source.startsWith("input:") || src === "ok") return "temporary";
  return "temporary";
}
