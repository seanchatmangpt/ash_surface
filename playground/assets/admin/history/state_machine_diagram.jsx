import React from "react";

// Plain SVG state diagram: states on a circle, quadratic-curved arrows per transition.
export function layout(states, w = 520, h = 340) {
  const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 48;
  return Object.fromEntries(
    states.map((s, i) => {
      const a = (2 * Math.PI * i) / states.length - Math.PI / 2;
      return [s, { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) }];
    }),
  );
}

export function StateMachineDiagram({ graph, current }) {
  const w = 520, h = 340, bw = 86, bh = 32;
  const pos = layout(graph.states, w, h);
  const next = new Set(graph.transitions.filter((t) => t.from === current).map((t) => `${t.action}:${t.to}`));
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="w-full max-w-xl" role="img" aria-label="state machine" data-testid="sm-diagram">
      <defs>
        <marker id="sm-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" className="fill-muted-foreground" />
        </marker>
      </defs>
      {graph.transitions.map((t, i) => {
        const a = pos[t.from], b = pos[t.to];
        if (!a || !b) return null;
        const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy) || 1;
        const nx = -dy / len, ny = dx / len, bend = 22;
        const mx = (a.x + b.x) / 2 + nx * bend, my = (a.y + b.y) / 2 + ny * bend;
        const trim = (p, q) => {
          const ex = q.x - p.x, ey = q.y - p.y, l = Math.hypot(ex, ey) || 1;
          const k = Math.min(bw / 2 / Math.abs(ex / l || 1e-9), bh / 2 / Math.abs(ey / l || 1e-9)) + 4;
          return { x: p.x + (ex / l) * k, y: p.y + (ey / l) * k };
        };
        const s = trim(a, { x: mx, y: my }), e = trim(b, { x: mx, y: my });
        const active = t.from === current;
        return (
          <g key={i} data-transition={`${t.from}->${t.to}`}>
            <path d={`M${s.x},${s.y} Q${mx},${my} ${e.x},${e.y}`} fill="none" markerEnd="url(#sm-arrow)"
              className={active ? "stroke-primary" : "stroke-muted-foreground/60"} strokeWidth={active ? 2 : 1} />
            <text x={mx} y={my - 4} textAnchor="middle" className="fill-muted-foreground text-[10px]">{t.action}</text>
          </g>
        );
      })}
      {graph.states.map((s) => (
        <g key={s} data-state={s} data-current={s === current ? "true" : "false"}>
          <rect x={pos[s].x - bw / 2} y={pos[s].y - bh / 2} width={bw} height={bh} rx={8}
            className={s === current ? "fill-primary stroke-primary" : "fill-card stroke-border"} />
          <text x={pos[s].x} y={pos[s].y + 4} textAnchor="middle"
            className={`text-xs font-medium ${s === current ? "fill-primary-foreground" : "fill-foreground"}`}>{s}</text>
        </g>
      ))}
    </svg>
  );
}
