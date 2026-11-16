import React, { useEffect, useState } from "react";
import { useAdmin } from "../context.jsx";
import { Badge } from "../../ui/badge.jsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../ui/card.jsx";
import { RecordPicker, historyApi } from "./shared.jsx";

const show = (v) => (v === null || v === undefined ? "∅" : typeof v === "object" ? JSON.stringify(v) : String(v));

export function FieldDiff({ diff }) {
  const rows = diff.filter((d) => !d.unchanged);
  if (rows.length === 0) return <p className="text-sm text-muted-foreground">No field changes.</p>;
  return (
    <div className="grid gap-1 text-sm" data-testid="field-diff">
      {rows.map((d) => (
        <div key={d.field} className="grid grid-cols-[10rem_1fr_1fr] items-baseline gap-2">
          <span className="font-mono text-xs text-muted-foreground">{d.field}</span>
          <span className="rounded bg-destructive/10 px-2 py-0.5 line-through decoration-destructive/40">{show(d.from)}</span>
          <span className="rounded bg-emerald-500/10 px-2 py-0.5">{show(d.to)}</span>
        </div>
      ))}
    </div>
  );
}

const variant = { create: "default", update: "secondary", destroy: "destructive" };

export function HistoryTab({ meta }) {
  const { ctx } = useAdmin();
  const [id, setId] = useState("");
  const [versions, setVersions] = useState(null);
  const [error, setError] = useState(null);
  useEffect(() => {
    if (!id) return setVersions(null);
    setError(null);
    historyApi.versions(meta.module, id, ctx).then((d) => setVersions(d.versions)).catch((e) => setError(e.message));
  }, [id, meta.module, ctx.actor_id, ctx.tenant, ctx.authorize]);
  return (
    <div className="grid gap-4">
      <RecordPicker meta={meta} value={id} onChange={setId} />
      {error && <p className="text-sm text-destructive">{error}</p>}
      {id && versions && versions.length === 0 && <p className="text-sm text-muted-foreground">No versions yet.</p>}
      {!id && <p className="text-sm text-muted-foreground">Pick a record to see its version timeline.</p>}
      <ol className="grid gap-3 border-l pl-4">
        {(versions ?? []).map((v) => (
          <li key={v.id}>
            <Card>
              <CardHeader className="flex-row items-center justify-between gap-2 p-4">
                <div className="flex items-center gap-2">
                  <Badge variant={variant[v.action_type] ?? "outline"}>{v.action}</Badge>
                  <CardTitle className="text-sm">{v.action_type}</CardTitle>
                </div>
                <CardDescription>{v.actor_id ? `actor ${v.actor_id.slice(0, 8)}` : "no actor"} · {v.inserted_at}</CardDescription>
              </CardHeader>
              <CardContent className="p-4 pt-0"><FieldDiff diff={v.diff} /></CardContent>
            </Card>
          </li>
        ))}
      </ol>
    </div>
  );
}
