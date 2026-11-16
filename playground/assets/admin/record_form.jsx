import React, { useEffect, useMemo, useRef, useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { api } from "./api.js";
import { useAdmin } from "./context.jsx";
import { FieldControl, encodeValue } from "./fields.jsx";
import { Button } from "../ui/button.jsx";
import { Label } from "../ui/label.jsx";
import { Badge } from "../ui/badge.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../ui/select.jsx";

const labelOf = (r) => r.name || r.title || r.display_name || r.label || r.id;

// Create / update / destroy form driven entirely by the Ash action's accept list and
// arguments; validation and submit round-trip through AshPhoenix.Form on the server. Arguments
// backed by `manage_relationship` render as nested forms (AshPhoenix auto nested forms).
export function RecordForm({ meta, record, onDone, onCancel }) {
  const { ctx } = useAdmin();
  const types = record ? ["update", "destroy"] : ["create"];
  const candidates = meta.actions.filter((a) => types.includes(a.type));
  const [actionName, setActionName] = useState((candidates.find((a) => a.primary) ?? candidates[0])?.name);
  const action = candidates.find((a) => a.name === actionName);
  const [values, setValues] = useState(() => ({ ...(record ?? {}) }));
  const [errors, setErrors] = useState([]);
  const [busy, setBusy] = useState(false);
  const [relOptions, setRelOptions] = useState({});
  const [destMetas, setDestMetas] = useState({});

  const managed = action?.managed_relationships ?? [];
  const managedArgs = managed.map((m) => m.argument);

  const fields = useMemo(() => {
    if (!action || action.type === "destroy") return [];
    const attrs = meta.attributes.filter((a) => action.accept.includes(a.name));
    const args = action.arguments.filter((a) => !attrs.some((x) => x.name === a.name) && !managedArgs.includes(a.name));
    return [...attrs, ...args];
  }, [action, meta]);

  // belongs_to selects: source attribute -> destination records
  useEffect(() => {
    for (const rel of meta.relationships.filter((r) => r.type === "belongs_to")) {
      if (!fields.some((f) => f.name === rel.source_attribute)) continue;
      api.records(rel.destination_module, { limit: 100, ...ctx }).then((d) =>
        setRelOptions((o) => ({ ...o, [rel.source_attribute]: d.records.map((r) => ({ value: r.id, label: labelOf(r) })) })),
      ).catch(() => {});
    }
  }, [fields.length, meta.name]);

  // nested forms need the destination resource's accept list; and existing children on update
  useEffect(() => {
    for (const m of managed) {
      if (destMetas[m.destination_module]) continue;
      api.resource(m.destination_module).then((d) => setDestMetas((x) => ({ ...x, [m.destination_module]: d }))).catch(() => {});
    }
    if (record && managed.length > 0) {
      const names = managed.map((m) => m.relationship).join(",");
      api.record(meta.module, record.id, { load: names, ...ctx }).then((full) =>
        setValues((v) => {
          const next = { ...v };
          for (const m of managed) if (next[m.argument] === undefined) next[m.argument] = full[m.relationship] ?? (m.cardinality === "many" ? [] : null);
          return next;
        }),
      ).catch(() => {});
    }
  }, [actionName]);

  const timer = useRef();
  function change(name, v) {
    const next = { ...values, [name]: v };
    setValues(next);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => validate(next), 250);
  }
  useEffect(() => () => clearTimeout(timer.current), []);

  const childFields = (m) => {
    const dm = destMetas[m.destination_module];
    if (!dm) return [];
    const create = dm.actions.find((a) => a.type === "create" && a.primary) ?? dm.actions.find((a) => a.type === "create");
    return dm.attributes.filter((a) => create?.accept.includes(a.name) && a.name !== (dm.relationships.find((r) => r.destination_module === meta.module)?.source_attribute));
  };
  const encodeChild = (m, item) => {
    const out = {};
    if (item.id !== undefined && item.id !== null) out.id = item.id;
    for (const f of childFields(m)) if (item[f.name] !== undefined) out[f.name] = encodeValue(f, item[f.name]);
    return out;
  };

  const pick = (vals) => {
    const out = Object.fromEntries(fields.map((f) => [f.name, encodeValue(f, vals[f.name])]).filter(([, v]) => v !== undefined));
    for (const m of managed) {
      const v = vals[m.argument];
      if (v === undefined) continue;
      out[m.argument] = Array.isArray(v) ? v.map((i) => encodeChild(m, i)) : v === null ? null : encodeChild(m, v);
    }
    return out;
  };
  const body = (vals) => ({ action: actionName, id: record?.id, params: pick(vals) });

  async function validate(vals) {
    try {
      const r = await api.validate(meta.module, body(vals), ctx);
      setErrors(r.errors);
    } catch (e) {
      setErrors([{ field: "", message: e.message }]);
    }
  }

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    try {
      const r = await api.submit(meta.module, body(values), ctx);
      if (r.errors?.length) setErrors(r.errors);
      else onDone(r.record);
    } catch (err) {
      setErrors([{ field: "", message: err.message }]);
    } finally {
      setBusy(false);
    }
  }

  const err = (f) => errors.filter((x) => x.field === f);
  const known = [...fields.map((f) => f.name), ...managedArgs];
  const general = errors.filter((x) => !known.includes(x.field));

  return (
    <form onSubmit={submit} className="grid gap-4">
      {candidates.length > 1 && (
        <div className="grid gap-1.5">
          <Label>Action</Label>
          <Select value={actionName} onValueChange={setActionName}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              {candidates.map((a) => <SelectItem key={a.name} value={a.name}>{a.name} <span className="text-muted-foreground">({a.type})</span></SelectItem>)}
            </SelectContent>
          </Select>
        </div>
      )}
      {action?.type === "destroy" && <p className="text-sm text-destructive">This will run the <b>{action.name}</b> destroy action.</p>}
      {fields.map((f) => (
        <div key={f.name} className="grid gap-1.5">
          <Label htmlFor={`f-${f.name}`}>
            {f.name} {f.allow_nil === false && <span className="text-destructive">*</span>}{" "}
            <Badge variant="outline">{f.type}</Badge>
          </Label>
          <FieldControl id={`f-${f.name}`} field={f} value={values[f.name]} options={relOptions[f.name]} onChange={(v) => change(f.name, v)} />
          {err(f.name).map((x, i) => <p key={i} className="text-xs text-destructive">{x.message}</p>)}
        </div>
      ))}
      {managed.map((m) => (
        <ManagedSection key={m.argument} m={m} fields={childFields(m)} value={values[m.argument]} onChange={(v) => change(m.argument, v)} errors={err(m.argument)} />
      ))}
      {general.map((x, i) => <p key={i} className="text-sm text-destructive">{x.field ? `${x.field}: ` : ""}{x.message}</p>)}
      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={onCancel}>Cancel</Button>
        <Button type="submit" disabled={busy} variant={action?.type === "destroy" ? "destructive" : "default"}>
          {busy ? "…" : action?.type === "destroy" ? "Destroy" : record ? "Save" : "Create"}
        </Button>
      </div>
    </form>
  );
}

// Nested form for one manage_relationship argument (many -> list of rows, one -> single row).
function ManagedSection({ m, fields, value, onChange, errors }) {
  const many = m.cardinality === "many";
  const rows = many ? (Array.isArray(value) ? value : []) : value ? [value] : [];
  const setRow = (i, next) => onChange(many ? rows.map((r, j) => (j === i ? next : r)) : next);
  return (
    <fieldset className="grid gap-3 rounded-md border p-3" aria-label={m.argument}>
      <legend className="px-1 text-sm font-medium">
        {m.relationship} <Badge variant="outline">{m.destination} · {m.type ?? "managed"}</Badge>
      </legend>
      {rows.map((row, i) => (
        <div key={row.id ?? i} className="grid gap-2 rounded-md bg-muted/40 p-3">
          {fields.map((f) => (
            <div key={f.name} className="grid gap-1.5">
              <Label htmlFor={`m-${m.argument}-${i}-${f.name}`}>{f.name} {f.allow_nil === false && <span className="text-destructive">*</span>}</Label>
              <FieldControl id={`m-${m.argument}-${i}-${f.name}`} field={f} value={row[f.name]} onChange={(v) => setRow(i, { ...row, [f.name]: v })} />
            </div>
          ))}
          <div className="flex justify-end">
            <Button type="button" size="sm" variant="ghost" aria-label={`remove ${m.relationship} ${i + 1}`} onClick={() => onChange(many ? rows.filter((_, j) => j !== i) : null)}>
              <Trash2 /> Remove
            </Button>
          </div>
        </div>
      ))}
      {(many || rows.length === 0) && (
        <div>
          <Button type="button" size="sm" variant="outline" onClick={() => onChange(many ? [...rows, {}] : {})}><Plus /> Add {m.relationship}</Button>
        </div>
      )}
      {errors.map((x, i) => <p key={i} className="text-xs text-destructive">{x.message}</p>)}
    </fieldset>
  );
}
