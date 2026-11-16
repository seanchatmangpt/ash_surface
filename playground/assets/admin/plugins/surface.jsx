import React, { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "../../ui/card.jsx";
import { Badge } from "../../ui/badge.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../ui/select.jsx";
import { Textarea } from "../../ui/input.jsx";
import { fetchSurfaceModule, validateText } from "../surface/validator.js";

const enc = encodeURIComponent;

function SurfaceTab({ meta }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [mod, setMod] = useState(null);
  const [sel, setSel] = useState(null);
  const [payload, setPayload] = useState("{}");

  useEffect(() => {
    let live = true;
    fetch(`/admin/api/surface/resources/${enc(meta.module)}`)
      .then(async (r) => {
        const body = await r.json().catch(() => ({}));
        if (!r.ok) throw new Error(body.message || body.error || r.statusText);
        return body;
      })
      .then((b) => {
        if (!live) return;
        setData(b);
        setSel((s) => s ?? b.entries[0]?.id ?? null);
      })
      .catch((e) => live && setError(e.message));
    fetchSurfaceModule().then((m) => live && setMod(m), (e) => live && setError(e.message));
    return () => {
      live = false;
    };
  }, [meta.module]);

  if (error) return <p className="text-sm text-destructive" data-testid="surface-error">Surface unavailable: {error}</p>;
  if (!data) return <p className="text-muted-foreground">Loading…</p>;
  if (data.entries.length === 0)
    return <p className="text-sm text-muted-foreground">No compiled surface actions for {meta.module}.</p>;

  const current = data.entries.find((e) => e.id === sel) ?? data.entries[0];
  const result = mod ? validateText(mod, current.id, payload) : null;

  return (
    <div className="grid gap-4" data-testid="surface-tab">
      <div className="flex items-center gap-3">
        <div className="w-64">
          <Select value={current.id} onValueChange={setSel}>
            <SelectTrigger data-testid="surface-action"><SelectValue /></SelectTrigger>
            <SelectContent>
              {data.entries.map((e) => (
                <SelectItem key={e.id} value={e.id}>{e.action} ({e.type})</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <Badge variant="secondary">{current.type}</Badge>
        <code className="text-xs text-muted-foreground">digest {current.digest}</code>
      </div>
      {data.failures.length > 0 && (
        <p className="text-xs text-destructive">
          {data.failures.length} action(s) failed to project: {data.failures.map((f) => f.actionId).join(", ")}
        </p>
      )}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader><CardTitle>IR contract</CardTitle><CardDescription>{current.id}</CardDescription></CardHeader>
          <CardContent>
            <pre data-testid="surface-contract" className="max-h-96 overflow-auto rounded-md bg-muted p-3 text-xs">
              {JSON.stringify(current.contract, null, 2)}
            </pre>
          </CardContent>
        </Card>
        <Card>
          <CardHeader><CardTitle>Emitted Zod</CardTitle><CardDescription>input and response schemas</CardDescription></CardHeader>
          <CardContent>
            <pre data-testid="surface-zod" className="max-h-96 overflow-auto rounded-md bg-muted p-3 text-xs">
              {[current.zod.input, current.zod.response].filter(Boolean).join("\n\n") || "(no schema emitted)"}
            </pre>
          </CardContent>
        </Card>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Payload validator</CardTitle>
          <CardDescription>Validated in-browser by the emitted schema for {current.id}</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3">
          <Textarea
            data-testid="surface-payload"
            className="font-mono text-xs"
            rows={6}
            value={payload}
            onChange={(ev) => setPayload(ev.target.value)}
          />
          <div data-testid="surface-result" className="text-sm">
            {result === null ? (
              <span className="text-muted-foreground">loading schema…</span>
            ) : result.ok ? (
              <span className="text-green-600">VALID</span>
            ) : (
              <ul className="grid gap-1 text-destructive">
                {result.issues.map((i, n) => (
                  <li key={n}><code>{i.path || "(root)"}</code> [{i.code}] {i.message}</li>
                ))}
              </ul>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default {
  id: "surface",
  pages: [],
  tabs: [{ id: "surface", label: "Surface", render: (meta) => (meta?.module ? <SurfaceTab meta={meta} /> : null) }],
};
