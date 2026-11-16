import React, { useEffect, useState } from "react";
import { useAdmin } from "../context.jsx";
import { api } from "../api.js";
import { Badge } from "../../ui/badge.jsx";
import { Button } from "../../ui/button.jsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../ui/card.jsx";
import { RecordPicker, historyApi } from "./shared.jsx";
import { StateMachineDiagram } from "./state_machine_diagram.jsx";

export function StateMachineTab({ meta }) {
  const { ctx } = useAdmin();
  const [graph, setGraph] = useState(null);
  const [id, setId] = useState("");
  const [current, setCurrent] = useState(null);
  const [tick, setTick] = useState(0);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => { historyApi.stateMachine(meta.module, ctx).then(setGraph).catch((e) => setError(e.message)); }, [meta.module]);
  useEffect(() => {
    if (!id || !graph) return setCurrent(null);
    api.record(meta.module, id, ctx).then((r) => setCurrent(String(r[graph.state_attribute]))).catch((e) => setError(e.message));
  }, [id, graph, tick, ctx.actor_id, ctx.tenant, ctx.authorize]);

  async function fire(action) {
    setBusy(true); setError(null);
    try {
      const res = await api.submit(meta.module, { action, id, params: {} }, ctx);
      if (res.errors?.length) setError(res.errors.map((e) => e.message).join("; "));
      else setTick((t) => t + 1);
    } catch (e) { setError(e.message); } finally { setBusy(false); }
  }

  if (!graph) return <p className="text-sm text-muted-foreground">{error ?? "Loading…"}</p>;
  const nexts = current ? graph.transitions.filter((t) => t.from === current) : [];
  return (
    <div className="grid gap-4">
      <RecordPicker meta={meta} value={id} onChange={setId} reloadKey={tick} />
      <Card>
        <CardHeader><CardTitle className="text-sm">States and transitions</CardTitle></CardHeader>
        <CardContent className="grid gap-4">
          <StateMachineDiagram graph={graph} current={current} />
          {current && (
            <div className="flex flex-wrap items-center gap-2" data-testid="next-transitions">
              <span className="text-sm text-muted-foreground">Current</span>
              <Badge>{current}</Badge>
              {nexts.length === 0 && <span className="text-sm text-muted-foreground">terminal state</span>}
              {nexts.map((t) => (
                <Button key={`${t.action}-${t.to}`} size="sm" variant="outline" disabled={busy} onClick={() => fire(t.action)}>
                  {t.action} → {t.to}
                </Button>
              ))}
            </div>
          )}
          {error && <p className="text-sm text-destructive">{error}</p>}
        </CardContent>
      </Card>
    </div>
  );
}
