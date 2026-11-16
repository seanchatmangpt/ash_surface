import React, { useEffect, useState } from "react";
import { useAdmin } from "../context.jsx";
import { api } from "../api.js";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../ui/select.jsx";

const base = "/admin/api";
const qs = (o) => new URLSearchParams(Object.entries(o).filter(([, v]) => v !== "" && v != null)).toString();
const enc = encodeURIComponent;

export async function hget(path, ctx) {
  const res = await fetch(`${base}${path}${path.includes("?") ? "&" : "?"}${qs(ctx)}`);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.message || res.statusText), { data });
  return data;
}

export async function hpost(path, body) {
  const res = await fetch(`${base}${path}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.message || res.statusText), { data });
  return data;
}

export const historyApi = {
  versions: (r, id, ctx) => hget(`/resources/${enc(r)}/records/${enc(id)}/versions`, ctx),
  stateMachine: (r, ctx) => hget(`/resources/${enc(r)}/state_machine`, ctx),
  archived: (r, ctx) => hget(`/resources/${enc(r)}/archived`, ctx),
  restore: (r, id, ctx) => hpost(`/resources/${enc(r)}/archived/${enc(id)}/restore`, ctx),
  records: (r, ctx) => api.records(r, { limit: 100, ...ctx }),
};

export function recordLabel(rec, meta) {
  const field = meta.attributes.find((a) => a.kind === "string" && !a.sensitive && !a.primary_key);
  return `${field ? rec[field.name] : ""} (${String(rec.id ?? "").slice(0, 8)})`;
}

// Record picker built inside the tab (tabs only receive `meta`). Live records only.
export function RecordPicker({ meta, value, onChange, reloadKey }) {
  const { ctx } = useAdmin();
  const [records, setRecords] = useState([]);
  useEffect(() => {
    let live = true;
    historyApi.records(meta.module, ctx).then((d) => live && setRecords(d.records)).catch(() => live && setRecords([]));
    return () => { live = false; };
  }, [meta.module, reloadKey, ctx.actor_id, ctx.tenant, ctx.authorize]);
  return (
    <Select value={value || undefined} onValueChange={(v) => onChange(v, records.find((r) => r.id === v))}>
      <SelectTrigger className="w-72"><SelectValue placeholder="Select a record" /></SelectTrigger>
      <SelectContent>
        {records.map((r) => <SelectItem key={r.id} value={r.id}>{recordLabel(r, meta)}</SelectItem>)}
      </SelectContent>
    </Select>
  );
}
