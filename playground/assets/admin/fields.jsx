import React, { useEffect, useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { Input, Textarea } from "../ui/input.jsx";
import { Switch } from "../ui/switch.jsx";
import { Button } from "../ui/button.jsx";
import { Badge } from "../ui/badge.jsx";
import { Label } from "../ui/label.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../ui/select.jsx";

const LONG = /body|bio|description|content|notes|text/i;

const emptyFor = (f) => {
  if (!f) return "";
  if (f.kind === "boolean") return false;
  if (f.kind?.startsWith("array:")) return [];
  if (f.kind === "embedded") return {};
  if (f.kind === "union") return f.types?.[0] ? { type: f.types[0].name, value: emptyFor(f.types[0]) } : null;
  return "";
};

// One control per Ash type kind (see AshShadcn.Introspect.kind/1 and detail/2): scalars, arrays
// of any inner type, embedded resources (nested fields), unions (member select + control),
// maps/json, and `options` for relationship selects.
export function FieldControl({ field, value, onChange, options, id }) {
  const { kind, constraints = {} } = field;
  const set = (v) => onChange(v);

  if (options) {
    return (
      <Select value={value ? String(value) : ""} onValueChange={set}>
        <SelectTrigger id={id}><SelectValue placeholder="Select…" /></SelectTrigger>
        <SelectContent>
          {options.map((o) => <SelectItem key={o.value} value={String(o.value)}>{o.label}</SelectItem>)}
        </SelectContent>
      </Select>
    );
  }
  if (kind === "boolean") return <Switch id={id} checked={!!value} onCheckedChange={set} />;
  if (kind === "atom" && constraints.one_of) {
    return (
      <Select value={value ? String(value) : ""} onValueChange={set}>
        <SelectTrigger id={id}><SelectValue placeholder="Select…" /></SelectTrigger>
        <SelectContent>
          {constraints.one_of.map((o) => <SelectItem key={o} value={String(o)}>{String(o)}</SelectItem>)}
        </SelectContent>
      </Select>
    );
  }
  if (kind === "integer" || kind === "number")
    return <Input id={id} type="number" step={kind === "integer" ? 1 : "any"} value={value ?? ""} onChange={(e) => set(e.target.value)} />;
  if (kind === "date") return <Input id={id} type="date" value={(value ?? "").slice(0, 10)} onChange={(e) => set(e.target.value)} />;
  if (kind === "datetime")
    return <Input id={id} type="datetime-local" value={(value ?? "").slice(0, 16)} onChange={(e) => set(e.target.value ? new Date(e.target.value).toISOString() : "")} />;
  if (kind.startsWith("array:")) return <ArrayControl id={id} field={field} value={value} onChange={set} />;
  if (kind === "embedded") return <EmbeddedControl id={id} field={field} value={value} onChange={set} />;
  if (kind === "union") return <UnionControl id={id} field={field} value={value} onChange={set} />;
  if (kind === "json") return <JsonControl id={id} value={value} onChange={set} />;
  if (kind === "file")
    return <Input id={id} type="file" disabled title="File arguments are not supported by this admin" />;
  if (LONG.test(field.name ?? "") || constraints.max_length > 255) return <Textarea id={id} value={value ?? ""} onChange={(e) => set(e.target.value)} />;
  return <Input id={id} type={field.sensitive ? "password" : "text"} value={value ?? ""} onChange={(e) => set(e.target.value)} />;
}

function ArrayControl({ id, field, value, onChange }) {
  const items = Array.isArray(value) ? value : [];
  const inner = field.items ?? { kind: field.kind.slice(6), constraints: {} };
  return (
    <div className="grid gap-2" data-testid={`array-${id}`}>
      {items.map((item, i) => (
        <div key={i} className="flex items-start gap-2">
          <div className="min-w-0 flex-1">
            <FieldControl id={`${id}-${i}`} field={inner} value={item} onChange={(v) => onChange(items.map((x, j) => (j === i ? v : x)))} />
          </div>
          <Button type="button" size="icon" variant="ghost" aria-label={`remove item ${i + 1}`} onClick={() => onChange(items.filter((_, j) => j !== i))}>
            <Trash2 />
          </Button>
        </div>
      ))}
      <div>
        <Button type="button" size="sm" variant="outline" onClick={() => onChange([...items, emptyFor(inner)])}><Plus /> Add</Button>
      </div>
    </div>
  );
}

function EmbeddedControl({ id, field, value, onChange }) {
  const obj = value && typeof value === "object" ? value : {};
  const fields = field.fields ?? [];
  if (fields.length === 0) return <JsonControl id={id} value={value} onChange={onChange} />;
  return (
    <div className="grid gap-3 rounded-md border p-3">
      {fields.filter((f) => !f.primary_key || obj[f.name] !== undefined).map((f) => (
        <div key={f.name} className="grid gap-1.5">
          <Label htmlFor={`${id}-${f.name}`}>{f.name} <Badge variant="outline">{f.type}</Badge></Label>
          <FieldControl id={`${id}-${f.name}`} field={f} value={obj[f.name]} onChange={(v) => onChange({ ...obj, [f.name]: v })} />
        </div>
      ))}
    </div>
  );
}

function UnionControl({ id, field, value, onChange }) {
  const types = field.types ?? [];
  const current = types.find((t) => t.name === value?.type);
  return (
    <div className="grid gap-2 rounded-md border p-3">
      <Select value={current?.name ?? ""} onValueChange={(name) => { const t = types.find((x) => x.name === name); onChange({ type: name, value: emptyFor(t) }); }}>
        <SelectTrigger id={id} aria-label="union type"><SelectValue placeholder="Select type…" /></SelectTrigger>
        <SelectContent>{types.map((t) => <SelectItem key={t.name} value={t.name}>{t.name} ({t.type})</SelectItem>)}</SelectContent>
      </Select>
      {current && <FieldControl id={`${id}-value`} field={current} value={value?.value} onChange={(v) => onChange({ type: current.name, value: v })} />}
    </div>
  );
}

// Keeps the raw text locally so half-typed JSON never clobbers the value; reports invalid JSON.
export function JsonControl({ id, value, onChange }) {
  const show = (v) => (typeof v === "string" ? v : JSON.stringify(v ?? {}, null, 2));
  const [text, setText] = useState(() => show(value));
  const [bad, setBad] = useState(false);
  useEffect(() => {
    // external reset (e.g. switching records) — only when the parsed text differs
    try { if (JSON.stringify(JSON.parse(text)) === JSON.stringify(value)) return; } catch {}
    if (typeof value !== "string") setText(show(value));
  }, [value]);
  return (
    <div className="grid gap-1">
      <Textarea
        id={id}
        className="font-mono text-xs"
        aria-invalid={bad}
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          try { onChange(JSON.parse(e.target.value)); setBad(false); } catch { setBad(true); }
        }}
      />
      {bad && <p className="text-xs text-destructive">Invalid JSON</p>}
    </div>
  );
}

// Turns form state into the params AshPhoenix.Form expects: union values become
// `%{"_union_type" => name, "value" => v}`; embedded/array recurse; blank scalars stay as-is.
export function encodeValue(field, v) {
  if (v === undefined || v === null) return v;
  const kind = field?.kind ?? "";
  if (kind === "union") {
    const t = (field.types ?? []).find((x) => x.name === v.type);
    return t ? { _union_type: t.name, value: encodeValue(t, v.value) } : v;
  }
  if (kind === "embedded" && field.fields) {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encodeValue(field.fields.find((f) => f.name === k), x)]));
  }
  if (kind.startsWith("array:") && Array.isArray(v)) return v.map((x) => encodeValue(field.items, x));
  return v;
}

// ---- display ---------------------------------------------------------------------------------

export function formatCell(v) {
  if (v === null || v === undefined) return <span className="text-muted-foreground">—</span>;
  if (typeof v === "boolean") return v ? "✓" : "✗";
  if (Array.isArray(v)) return v.map((x) => (typeof x === "object" ? JSON.stringify(x) : String(x))).join(", ");
  if (typeof v === "object") return <code className="text-xs">{JSON.stringify(v)}</code>;
  return String(v);
}

// Rich read-only rendering for the record show page: embedded -> definition list, union -> typed
// badge + value, arrays -> stacked items, maps -> pretty JSON.
export function ValueView({ field, value }) {
  const kind = field?.kind ?? "";
  if (value === null || value === undefined) return <span className="text-muted-foreground">—</span>;
  if (kind === "union" && typeof value === "object")
    return (
      <span className="inline-flex items-center gap-2">
        <Badge variant="secondary">{String(value.type)}</Badge>
        <ValueView field={(field.types ?? []).find((t) => t.name === value.type)} value={value.value} />
      </span>
    );
  if (kind === "embedded" && typeof value === "object" && !Array.isArray(value))
    return (
      <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 rounded-md border p-2 text-sm">
        {Object.entries(value).map(([k, x]) => (
          <React.Fragment key={k}>
            <dt className="text-muted-foreground">{k}</dt>
            <dd><ValueView field={(field.fields ?? []).find((f) => f.name === k)} value={x} /></dd>
          </React.Fragment>
        ))}
      </dl>
    );
  if (kind.startsWith("array:") && Array.isArray(value))
    return value.length === 0 ? <span className="text-muted-foreground">empty</span> : (
      <ul className="grid gap-1">{value.map((x, i) => <li key={i}><ValueView field={field.items} value={x} /></li>)}</ul>
    );
  if (kind === "json" || (typeof value === "object" && !Array.isArray(value)))
    return <pre className="overflow-auto rounded-md bg-muted p-2 text-xs">{JSON.stringify(value, null, 2)}</pre>;
  if (typeof value === "boolean") return <span>{value ? "true" : "false"}</span>;
  if (Array.isArray(value)) return <span>{value.map(String).join(", ")}</span>;
  return <span className="break-words">{String(value)}</span>;
}
