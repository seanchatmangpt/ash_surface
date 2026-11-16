// Lane `jsonapi`: OpenAPI explorer for the AshJsonApi surface (/admin/api-docs).
import React, { useEffect, useState } from "react";
import { Badge } from "../../ui/badge.jsx";
import { Button } from "../../ui/button.jsx";
import { Input, Textarea } from "../../ui/input.jsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../ui/card.jsx";
import { groupOperations, flattenSchema, buildUrl } from "../jsonapi/explorer_lib.js";

const colors = {
  GET: "bg-emerald-600 text-white", POST: "bg-blue-600 text-white", PATCH: "bg-amber-600 text-white",
  PUT: "bg-amber-600 text-white", DELETE: "bg-red-600 text-white",
};
const MethodBadge = ({ m }) => <Badge className={`border-transparent font-mono ${colors[m] || ""}`}>{m}</Badge>;

function SchemaTree({ spec, schema }) {
  if (!schema) return <p className="text-sm text-muted-foreground">No schema.</p>;
  const rows = flattenSchema(spec, schema);
  return (
    <table className="w-full text-xs">
      <tbody>
        {rows.map((r, i) => (
          <tr key={i} className="border-b last:border-0">
            <td className="py-1 font-mono" style={{ paddingLeft: (r.depth - 1) * 12 }}>
              {r.path.split(".").pop()}{r.required && <span className="text-destructive">*</span>}
            </td>
            <td className="py-1 text-muted-foreground">{r.type}</td>
            <td className="py-1 text-muted-foreground">{r.description}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function TryIt({ op, spec, base, actorId }) {
  const [values, setValues] = useState({});
  const [body, setBody] = useState(op.requestSchema ? '{\n  "data": {\n    "type": "",\n    "attributes": {}\n  }\n}' : "");
  const [out, setOut] = useState(null);
  const [busy, setBusy] = useState(false);

  const run = async () => {
    setBusy(true);
    try {
      const url = base + buildUrl(op.path.replace(/^\/admin\/api\/json/, ""), op.parameters, values);
      const headers = { accept: "application/vnd.api+json" };
      if (body && op.method !== "GET") headers["content-type"] = "application/vnd.api+json";
      if (actorId) headers["x-actor-id"] = actorId;
      const res = await fetch(url, { method: op.method, headers, body: body && op.method !== "GET" && op.method !== "DELETE" ? body : undefined });
      const text = await res.text();
      let pretty = text;
      try { pretty = JSON.stringify(JSON.parse(text), null, 2); } catch {}
      setOut({ status: res.status, headers: [...res.headers.entries()], body: pretty, url });
    } catch (e) {
      setOut({ status: 0, headers: [], body: String(e), url: "" });
    } finally { setBusy(false); }
  };

  return (
    <div className="mt-3 space-y-2 rounded-md border p-3">
      <div className="text-sm font-medium">Try it</div>
      {op.parameters.map((p) => (
        <div key={p.name + p.in} className="flex items-center gap-2">
          <span className="w-40 font-mono text-xs">{p.name} <span className="text-muted-foreground">({p.in})</span></span>
          <Input className="h-8" placeholder={p.in === "path" ? "required" : "optional"} value={values[p.name] ?? ""}
                 onChange={(e) => setValues({ ...values, [p.name]: e.target.value })} />
        </div>
      ))}
      {op.requestSchema && <Textarea className="font-mono text-xs" rows={6} value={body} onChange={(e) => setBody(e.target.value)} />}
      <Button size="sm" onClick={run} disabled={busy}>{busy ? "Sending…" : "Send request"}</Button>
      {out && (
        <div className="space-y-1 text-xs">
          <div><Badge variant={out.status >= 400 || out.status === 0 ? "destructive" : "secondary"}>{out.status}</Badge> <span className="font-mono">{out.url}</span></div>
          <details><summary className="cursor-pointer">Headers</summary>
            <pre className="overflow-auto">{out.headers.map(([k, v]) => `${k}: ${v}`).join("\n")}</pre></details>
          <pre className="max-h-80 overflow-auto rounded bg-muted p-2">{out.body}</pre>
        </div>
      )}
    </div>
  );
}

function Operation({ op, spec, base, actorId }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="rounded-md border">
      <button className="flex w-full items-center gap-2 p-2 text-left" onClick={() => setOpen(!open)}>
        <MethodBadge m={op.method} /><span className="font-mono text-sm">{op.path}</span>
        <span className="ml-2 truncate text-xs text-muted-foreground">{op.summary}</span>
      </button>
      {open && (
        <div className="space-y-3 border-t p-3">
          {op.parameters.length > 0 && (
            <div><div className="text-sm font-medium">Parameters</div>
              {op.parameters.map((p) => (
                <div key={p.name + p.in} className="text-xs"><span className="font-mono">{p.name}</span> <Badge variant="outline">{p.in}</Badge>
                  {p.required && <span className="text-destructive"> required</span>} <span className="text-muted-foreground">{p.description}</span></div>
              ))}</div>
          )}
          {op.requestSchema && <div><div className="text-sm font-medium">Request body</div><SchemaTree spec={spec} schema={op.requestSchema} /></div>}
          {op.responses.map((r) => (
            <div key={r.status}><div className="text-sm font-medium">Response {r.status} <span className="text-muted-foreground">{r.description}</span></div>
              {r.schema && <SchemaTree spec={spec} schema={r.schema} />}</div>
          ))}
          <TryIt op={op} spec={spec} base={base} actorId={actorId} />
        </div>
      )}
    </div>
  );
}

function ApiDocsPage() {
  const [spec, setSpec] = useState(null);
  const [err, setErr] = useState(null);
  const [actorId, setActorId] = useState("");
  const base = "/admin/api/json";

  useEffect(() => {
    fetch("/admin/api/openapi").then((r) => r.json()).then(setSpec).catch((e) => setErr(String(e)));
  }, []);

  if (err) return <p className="p-6 text-destructive">{err}</p>;
  if (!spec) return <p className="p-6 text-muted-foreground">Loading OpenAPI spec…</p>;
  const groups = groupOperations(spec);
  return (
    <div className="space-y-4 p-6">
      <div><h1 className="text-2xl font-semibold">{spec.info?.title || "API"}</h1>
        <p className="text-sm text-muted-foreground">OpenAPI {spec.openapi} — {groups.reduce((n, g) => n + g.operations.length, 0)} operations</p></div>
      <div className="flex items-center gap-2"><span className="text-sm">x-actor-id</span>
        <Input className="h-8 max-w-sm font-mono" placeholder="author id (demo actor header)" value={actorId} onChange={(e) => setActorId(e.target.value)} /></div>
      {groups.map((g) => (
        <Card key={g.tag}><CardHeader><CardTitle className="capitalize">{g.tag}</CardTitle></CardHeader>
          <CardContent className="space-y-2">{g.operations.map((op) => <Operation key={op.id} op={op} spec={spec} base={base} actorId={actorId} />)}</CardContent></Card>
      ))}
    </div>
  );
}

export default { id: "jsonapi", pages: [{ path: "api-docs", label: "API docs", Page: ApiDocsPage }], tabs: [] };
