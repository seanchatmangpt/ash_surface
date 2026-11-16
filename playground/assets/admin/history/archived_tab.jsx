import React, { useCallback, useEffect, useState } from "react";
import { useAdmin } from "../context.jsx";
import { Button } from "../../ui/button.jsx";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../ui/table.jsx";
import { historyApi } from "./shared.jsx";

export function ArchivedTab({ meta }) {
  const { ctx } = useAdmin();
  const [rows, setRows] = useState(null);
  const [error, setError] = useState(null);
  const load = useCallback(() => {
    historyApi.archived(meta.module, ctx).then((d) => setRows(d.records)).catch((e) => setError(e.message));
  }, [meta.module, ctx.actor_id, ctx.tenant, ctx.authorize]);
  useEffect(load, [load]);
  const cols = meta.attributes.filter((a) => !a.sensitive && !a.primary_key).slice(0, 4);
  async function restore(id) {
    setError(null);
    try { await historyApi.restore(meta.module, id, ctx); load(); } catch (e) { setError(e.message); }
  }
  if (!rows) return <p className="text-sm text-muted-foreground">{error ?? "Loading…"}</p>;
  return (
    <div className="grid gap-3">
      {error && <p className="text-sm text-destructive">{error}</p>}
      {rows.length === 0 ? <p className="text-sm text-muted-foreground">No archived records.</p> : (
        <Table>
          <TableHeader>
            <TableRow>
              {cols.map((c) => <TableHead key={c.name}>{c.name}</TableHead>)}
              <TableHead>archived_at</TableHead><TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((r) => (
              <TableRow key={r.id}>
                {cols.map((c) => <TableCell key={c.name}>{String(r[c.name] ?? "")}</TableCell>)}
                <TableCell>{r.archived_at}</TableCell>
                <TableCell><Button size="sm" variant="outline" onClick={() => restore(r.id)}>Restore</Button></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
