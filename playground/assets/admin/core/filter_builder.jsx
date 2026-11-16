import React, { useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { Button } from "../../ui/button.jsx";
import { Input } from "../../ui/input.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../ui/select.jsx";

export const OPS = {
  string: ["contains", "eq", "not_eq", "in", "is_nil"],
  uuid: ["eq", "not_eq", "in", "is_nil"],
  atom: ["eq", "not_eq", "in", "is_nil"],
  integer: ["eq", "not_eq", "gt", "gte", "lt", "lte", "in", "is_nil"],
  number: ["eq", "not_eq", "gt", "gte", "lt", "lte", "is_nil"],
  date: ["eq", "gt", "gte", "lt", "lte", "is_nil"],
  datetime: ["gt", "gte", "lt", "lte", "eq", "is_nil"],
  boolean: ["eq", "is_nil"],
};
const FALLBACK = ["eq", "not_eq", "is_nil"];
export const opsFor = (kind) => OPS[kind] ?? FALLBACK;

// Rows [{field, op, value}] -> Ash.Query.filter_input map. Blank values are skipped; `in`
// splits on commas; `is_nil` takes "true"/"false". The server validates every value.
export function buildFilter(rows, join = "and") {
  const terms = [];
  for (const r of rows) {
    if (!r.field || !r.op) continue;
    let v = r.value;
    if (r.op === "is_nil") v = v !== "false";
    else if (r.op === "in") v = String(v ?? "").split(",").map((s) => s.trim()).filter(Boolean);
    else if (v === undefined || v === null || v === "") continue;
    if (r.op === "in" && v.length === 0) continue;
    terms.push({ [r.field]: { [r.op]: v } });
  }
  if (terms.length === 0) return null;
  return join === "or" && terms.length > 1 ? { or: terms } : terms.length === 1 ? terms[0] : { and: terms };
}

let rid = 0;
const blank = (fields) => ({ id: ++rid, field: fields[0]?.name ?? "", op: opsFor(fields[0]?.kind)[0], value: "" });

// Multi-field filter builder. `onApply(rows, join)` is called with the committed state;
// `errors` are the server's `invalid_filter` entries ([{field, message}]) shown inline.
export function FilterBuilder({ fields, onApply, errors = [], initial }) {
  const [rows, setRows] = useState(initial?.rows ?? []);
  const [join, setJoin] = useState(initial?.join ?? "and");
  const set = (id, patch) => setRows((rs) => rs.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  const kindOf = (name) => fields.find((f) => f.name === name)?.kind;

  return (
    <div className="grid gap-2" data-testid="filter-builder">
      {rows.map((r) => (
        <div key={r.id} className="flex flex-wrap items-center gap-2">
          <Select value={r.field} onValueChange={(f) => set(r.id, { field: f, op: opsFor(kindOf(f))[0], value: "" })}>
            <SelectTrigger className="w-40" aria-label="filter field"><SelectValue /></SelectTrigger>
            <SelectContent>{fields.map((f) => <SelectItem key={f.name} value={f.name}>{f.name}</SelectItem>)}</SelectContent>
          </Select>
          <Select value={r.op} onValueChange={(op) => set(r.id, { op })}>
            <SelectTrigger className="w-32" aria-label="filter operator"><SelectValue /></SelectTrigger>
            <SelectContent>{opsFor(kindOf(r.field)).map((o) => <SelectItem key={o} value={o}>{o}</SelectItem>)}</SelectContent>
          </Select>
          {r.op === "is_nil" ? (
            <Select value={String(r.value || "true")} onValueChange={(v) => set(r.id, { value: v })}>
              <SelectTrigger className="w-24" aria-label="filter value"><SelectValue /></SelectTrigger>
              <SelectContent><SelectItem value="true">true</SelectItem><SelectItem value="false">false</SelectItem></SelectContent>
            </Select>
          ) : (
            <Input
              className="w-48"
              aria-label="filter value"
              placeholder={r.op === "in" ? "a, b, c" : "value"}
              type={["integer", "number"].includes(kindOf(r.field)) && r.op !== "in" ? "number" : kindOf(r.field) === "date" ? "date" : "text"}
              value={r.value}
              onChange={(e) => set(r.id, { value: e.target.value })}
            />
          )}
          <Button type="button" size="icon" variant="ghost" aria-label="remove filter" onClick={() => setRows((rs) => rs.filter((x) => x.id !== r.id))}><Trash2 /></Button>
        </div>
      ))}
      {errors.map((e, i) => (
        <p key={i} role="alert" className="text-xs text-destructive">{e.field ? `${e.field}: ` : ""}{e.message}</p>
      ))}
      <div className="flex flex-wrap items-center gap-2">
        <Button type="button" size="sm" variant="outline" onClick={() => setRows((rs) => [...rs, blank(fields)])}><Plus /> Add filter</Button>
        {rows.length > 1 && (
          <Select value={join} onValueChange={setJoin}>
            <SelectTrigger className="w-28" aria-label="filter join"><SelectValue /></SelectTrigger>
            <SelectContent><SelectItem value="and">match all</SelectItem><SelectItem value="or">match any</SelectItem></SelectContent>
          </Select>
        )}
        <Button type="button" size="sm" onClick={() => onApply(rows, join)}>Apply</Button>
        {rows.length > 0 && <Button type="button" size="sm" variant="ghost" onClick={() => { setRows([]); onApply([], join); }}>Clear</Button>}
      </div>
    </div>
  );
}
