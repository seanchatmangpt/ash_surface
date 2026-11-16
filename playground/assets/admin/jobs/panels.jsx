import React, { useCallback, useEffect, useState } from "react";
import { Play, RotateCcw, Ban, RefreshCw } from "lucide-react";
import { jobsApi } from "./api.js";
import { Button } from "../../ui/button.jsx";
import { Badge } from "../../ui/badge.jsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../ui/card.jsx";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../ui/table.jsx";

const STATES = ["available", "scheduled", "executing", "retryable", "completed", "discarded", "cancelled"];
const variant = (s) =>
  ({ completed: "default", executing: "secondary", discarded: "destructive", cancelled: "outline", retryable: "destructive" })[s] ??
  "secondary";

export function StateBadge({ state }) {
  return <Badge variant={variant(state)} data-state={state}>{state}</Badge>;
}

export function TriggersTable({ resource, onRan }) {
  const [rows, setRows] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const load = useCallback(() => {
    jobsApi.triggers().then((d) => setRows(d.triggers.filter((t) => !resource || t.resource === resource))).catch((e) => setError(e.message));
  }, [resource]);
  useEffect(load, [load]);

  const run = async (t) => {
    setBusy(`${t.resource}/${t.name}`);
    try {
      await jobsApi.run(t.resource, t.name);
      onRan?.();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(null);
    }
  };

  if (error) return <p className="text-destructive">{error}</p>;
  if (!rows) return <p className="text-muted-foreground">Loading…</p>;
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Name</TableHead><TableHead>Kind</TableHead><TableHead>Resource</TableHead><TableHead>Action</TableHead>
          <TableHead>Queue</TableHead><TableHead>Cron</TableHead><TableHead>State</TableHead><TableHead />
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.length === 0 && <TableRow><TableCell colSpan={8} className="text-muted-foreground">No triggers.</TableCell></TableRow>}
        {rows.map((t) => (
          <TableRow key={`${t.resource}/${t.name}`}>
            <TableCell className="font-medium">{t.name}</TableCell>
            <TableCell><Badge variant="outline">{t.kind}</Badge></TableCell>
            <TableCell>{t.resource}</TableCell>
            <TableCell>{t.action}</TableCell>
            <TableCell>{t.queue}</TableCell>
            <TableCell><code>{t.scheduler_cron ?? "-"}</code></TableCell>
            <TableCell><Badge variant={t.state === "active" ? "default" : "secondary"}>{t.state}</Badge></TableCell>
            <TableCell>
              <Button size="sm" variant="outline" disabled={busy === `${t.resource}/${t.name}`} onClick={() => run(t)}>
                <Play className="size-3" /> Run now
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

export function JobsTable({ refreshKey, worker }) {
  const [state, setState] = useState("");
  const [page, setPage] = useState(1);
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const load = useCallback(() => {
    jobsApi.jobs({ state, page, per_page: 20, worker }).then(setData).catch((e) => setError(e.message));
  }, [state, page, worker]);
  useEffect(load, [load, refreshKey]);

  const act = async (fn, id) => {
    try { await fn(id); load(); } catch (e) { setError(e.message); }
  };

  if (error) return <p className="text-destructive">{error}</p>;
  if (!data) return <p className="text-muted-foreground">Loading…</p>;
  const pages = Math.max(1, Math.ceil(data.total / data.per_page));
  return (
    <div className="grid gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <Button size="sm" variant={state === "" ? "default" : "outline"} onClick={() => { setState(""); setPage(1); }}>all</Button>
        {STATES.map((s) => (
          <Button key={s} size="sm" variant={state === s ? "default" : "outline"} onClick={() => { setState(s); setPage(1); }}>
            {s} <Badge variant="secondary" className="ml-1">{data.counts[s] ?? 0}</Badge>
          </Button>
        ))}
        <Button size="sm" variant="ghost" onClick={load}><RefreshCw className="size-3" /></Button>
      </div>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>ID</TableHead><TableHead>State</TableHead><TableHead>Queue</TableHead><TableHead>Worker</TableHead>
            <TableHead>Attempt</TableHead><TableHead>Inserted</TableHead><TableHead />
          </TableRow>
        </TableHeader>
        <TableBody>
          {data.jobs.length === 0 && <TableRow><TableCell colSpan={7} className="text-muted-foreground">No jobs.</TableCell></TableRow>}
          {data.jobs.map((j) => (
            <TableRow key={j.id}>
              <TableCell>{j.id}</TableCell>
              <TableCell><StateBadge state={j.state} /></TableCell>
              <TableCell>{j.queue}</TableCell>
              <TableCell className="max-w-64 truncate" title={j.worker}>{j.worker}</TableCell>
              <TableCell>{j.attempt}/{j.max_attempts}</TableCell>
              <TableCell>{j.inserted_at}</TableCell>
              <TableCell className="flex gap-1">
                {["available", "scheduled", "executing", "retryable"].includes(j.state) && (
                  <Button size="sm" variant="outline" onClick={() => act(jobsApi.cancel, j.id)}><Ban className="size-3" /> Cancel</Button>
                )}
                {["discarded", "cancelled", "completed", "retryable", "scheduled"].includes(j.state) && (
                  <Button size="sm" variant="outline" onClick={() => act(jobsApi.retry, j.id)}><RotateCcw className="size-3" /> Retry</Button>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
      <div className="flex items-center justify-between text-sm text-muted-foreground">
        <span>{data.total} jobs</span>
        <div className="flex items-center gap-2">
          <Button size="sm" variant="outline" disabled={page <= 1} onClick={() => setPage(page - 1)}>Prev</Button>
          <span>{page} / {pages}</span>
          <Button size="sm" variant="outline" disabled={page >= pages} onClick={() => setPage(page + 1)}>Next</Button>
        </div>
      </div>
    </div>
  );
}

export function ResourceJobs({ resource }) {
  const [key, setKey] = useState(0);
  return (
    <Card>
      <CardHeader><CardTitle>Triggers for {resource}</CardTitle></CardHeader>
      <CardContent className="grid gap-6">
        <TriggersTable resource={resource} onRan={() => setKey((k) => k + 1)} />
        <JobsTable refreshKey={key} />
      </CardContent>
    </Card>
  );
}
