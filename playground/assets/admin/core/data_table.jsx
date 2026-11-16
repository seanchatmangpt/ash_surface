import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowDown, ArrowUp, Columns3, Download, Eye, EyeOff, Filter, Pencil, Plus, Search, Trash2 } from "lucide-react";
import { api } from "../api.js";
import { useAdmin } from "../context.jsx";
import { RecordForm } from "../record_form.jsx";
import { FieldControl, formatCell } from "../fields.jsx";
import { bus } from "../bus.js";
import { Link, recordPath } from "./link.jsx";
import { FilterBuilder, buildFilter } from "./filter_builder.jsx";
import { Button } from "../../ui/button.jsx";
import { Input } from "../../ui/input.jsx";
import { Badge } from "../../ui/badge.jsx";
import { Label } from "../../ui/label.jsx";
import { Switch } from "../../ui/switch.jsx";
import { Checkbox } from "../../ui/checkbox.jsx";
import { Card, CardContent, CardHeader } from "../../ui/card.jsx";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../ui/table.jsx";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "../../ui/dialog.jsx";
import { Popover, PopoverContent, PopoverTrigger } from "../../ui/popover.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../ui/select.jsx";
import { useToast } from "../../ui/toast.jsx";

export const PAGE_SIZES = [10, 25, 50, 100];
const colsKey = (module) => `ash_admin_cols:${module}`;

export function DataTable({ meta, pageSize = 10 }) {
  const { ctx, authorize, actorId, tenant } = useAdmin();
  const { toast } = useToast();
  const pk = meta.primary_key[0];
  const readActions = meta.actions.filter((a) => a.type === "read");
  const [action, setAction] = useState((readActions.find((a) => a.primary) ?? readActions[0])?.name);
  const pag = readActions.find((a) => a.name === action)?.pagination;
  const keyset = !!(pag?.keyset && !pag?.offset);

  const [sorts, setSorts] = useState([]); // [{field, dir}]
  const [size, setSize] = useState(pageSize);
  const [offset, setOffset] = useState(0);
  const [cursors, setCursors] = useState([]); // keyset: stack of `after` cursors
  const [q, setQ] = useState("");
  const [filterState, setFilterState] = useState({ rows: [], join: "and" });
  const [filterOpen, setFilterOpen] = useState(false);
  const [filterErrors, setFilterErrors] = useState([]);
  const [reveal, setReveal] = useState(false);
  const [hidden, setHidden] = useState(() => new Set());
  const [calcState, setCalcState] = useState({}); // name -> {on, args}
  const [selected, setSelected] = useState(() => new Set());
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [editing, setEditing] = useState(null); // {record} | {} for create
  const [bulk, setBulk] = useState(null); // "destroy" | "update"
  const [tick, setTick] = useState(0);

  const search = meta.attributes.find((a) => a.kind === "string" && !a.sensitive);
  const hasSensitive = meta.attributes.some((a) => a.sensitive);
  const plainCalcs = meta.calculations.filter((c) => c.arguments.length === 0);
  const argCalcs = meta.calculations.filter((c) => c.arguments.length > 0);
  const activeArgCalcs = argCalcs.filter((c) => calcState[c.name]?.on && c.arguments.every((a) => a.allow_nil || calcState[c.name].args?.[a.name]));

  // column visibility persists per resource (read in an effect: SSR-safe)
  useEffect(() => {
    try {
      const saved = JSON.parse(window.localStorage.getItem(colsKey(meta.module)) ?? "null");
      if (Array.isArray(saved)) setHidden(new Set(saved));
    } catch {}
  }, [meta.module]);
  const toggleCol = (name) =>
    setHidden((h) => {
      const next = new Set(h);
      next.has(name) ? next.delete(name) : next.add(name);
      try { window.localStorage.setItem(colsKey(meta.module), JSON.stringify([...next])); } catch {}
      return next;
    });

  const allCols = [
    ...meta.attributes.filter((a) => reveal || !a.sensitive),
    ...plainCalcs,
    ...activeArgCalcs,
    ...meta.aggregates,
  ];
  const cols = allCols.filter((c) => !hidden.has(c.name));
  const filterFields = [...meta.attributes.filter((a) => !a.sensitive), ...plainCalcs, ...meta.aggregates];

  const query = useMemo(() => {
    const quick = q && search ? { [search.name]: { contains: q } } : null;
    const built = buildFilter(filterState.rows, filterState.join);
    const filter = quick && built ? { and: [quick, built] } : quick ?? built;
    const calc_args = Object.fromEntries(activeArgCalcs.map((c) => [c.name, calcState[c.name].args]));
    return {
      action,
      sort: sorts.map((s) => (s.dir === "desc" ? `-${s.field}` : s.field)).join(","),
      load: [...plainCalcs, ...activeArgCalcs, ...meta.aggregates].map((f) => f.name).join(","),
      calc_args: Object.keys(calc_args).length ? calc_args : undefined,
      filter: filter ? JSON.stringify(filter) : undefined,
      reveal: reveal ? "true" : undefined,
      ...ctx,
    };
  }, [action, sorts, q, filterState, reveal, JSON.stringify(activeArgCalcs.map((c) => [c.name, calcState[c.name].args])), meta.module, authorize, actorId, tenant]);

  // plugins (realtime lane) emit `changed:<module>` on the bus
  useEffect(() => bus.on(`changed:${meta.module}`, () => setTick((t) => t + 1)), [meta.module]);

  const after = keyset ? cursors[cursors.length - 1] : undefined;
  useEffect(() => {
    let live = true;
    setError(null);
    api
      .records(meta.module, { ...query, limit: size, offset: keyset ? undefined : offset, mode: keyset ? "keyset" : undefined, after })
      .then((d) => { if (live) { setData(d); setFilterErrors([]); } })
      .catch((e) => {
        if (!live) return;
        if (e.data?.error === "invalid_filter") setFilterErrors(e.data.errors ?? [{ message: e.message }]);
        else { setError(e.message); setData(null); }
      });
    return () => { live = false; };
  }, [query, size, offset, after, tick]);

  // any change of the query shape resets paging and selection
  const resetPaging = () => { setOffset(0); setCursors([]); setSelected(new Set()); };
  useEffect(resetPaging, [query, size]);

  function toggleSort(name, multi) {
    setSorts((cur) => {
      const i = cur.findIndex((s) => s.field === name);
      const next = i === -1 ? { field: name, dir: "asc" } : cur[i].dir === "asc" ? { field: name, dir: "desc" } : null;
      if (!multi) return next ? [next] : [];
      if (i === -1) return [...cur, next];
      return next ? cur.map((s, j) => (j === i ? next : s)) : cur.filter((_, j) => j !== i);
    });
  }

  const records = data?.records ?? [];
  const ids = records.map((r) => String(r[pk]));
  const allSelected = ids.length > 0 && ids.every((id) => selected.has(id));
  const toggleAll = () => setSelected(allSelected ? new Set() : new Set(ids));
  const toggleOne = (id) => setSelected((s) => { const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const canWrite = meta.actions.some((a) => ["create", "update", "destroy"].includes(a.type));
  const refresh = () => setTick((t) => t + 1);

  const exportUrl = (format) => {
    const { action: a, sort, load, calc_args, filter, reveal: rv, ...rest } = query;
    return api.exportUrl(meta.module, { action: a, sort, load, calc_args, filter, reveal: rv, ...rest, format, columns: cols.filter((c) => !c.sensitive).map((c) => c.name).join(",") });
  };

  async function runBulk(op, action, params) {
    try {
      const r = await api.bulk(meta.module, { op, action, ids: [...selected], params }, ctx);
      const ok = r.errors.length === 0 && r.affected === r.requested;
      toast({
        variant: ok ? "success" : "destructive",
        title: ok ? `${op === "destroy" ? "Destroyed" : "Updated"} ${r.affected} record${r.affected === 1 ? "" : "s"}` : `${r.affected} of ${r.requested} ${op === "destroy" ? "destroyed" : "updated"}`,
        description: r.errors.slice(0, 3).join("; ") || undefined,
      });
      setBulk(null);
      setSelected(new Set());
      refresh();
    } catch (e) {
      toast({ variant: "destructive", title: "Bulk action failed", description: e.message });
    }
  }

  const linkCol = (cols.find((c) => c.name === search?.name) ?? cols[0])?.name;
  const pageNo = keyset ? cursors.length + 1 : Math.floor(offset / size) + 1;
  const hasNext = keyset ? !!data?.more : !!data && offset + size < (data.count ?? 0);
  const hasPrev = keyset ? cursors.length > 0 : offset > 0;
  const nextPage = () => (keyset ? setCursors((c) => [...c, data.next_cursor]) : setOffset(offset + size));
  const prevPage = () => (keyset ? setCursors((c) => c.slice(0, -1)) : setOffset(Math.max(0, offset - size)));

  const updateActions = meta.actions.filter((a) => a.type === "update");
  const destroyAction = meta.actions.find((a) => a.type === "destroy" && a.primary) ?? meta.actions.find((a) => a.type === "destroy");

  return (
    <Card>
      <CardHeader className="gap-3 space-y-0">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2">
            {search && (
              <div className="relative">
                <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
                <Input className="w-56 pl-8" aria-label="search" placeholder={`Filter ${search.name}…`} value={q} onChange={(e) => setQ(e.target.value)} />
              </div>
            )}
            {readActions.length > 1 && (
              <Select value={action} onValueChange={(v) => { setAction(v); }}>
                <SelectTrigger className="w-40" aria-label="read action"><SelectValue /></SelectTrigger>
                <SelectContent>{readActions.map((a) => <SelectItem key={a.name} value={a.name}>{a.name}</SelectItem>)}</SelectContent>
              </Select>
            )}
            <Button variant={filterOpen ? "secondary" : "outline"} onClick={() => setFilterOpen((o) => !o)}>
              <Filter /> Filters{filterState.rows.length > 0 && <Badge variant="secondary">{filterState.rows.length}</Badge>}
            </Button>
            <ColumnsMenu allCols={allCols} hidden={hidden} toggle={toggleCol} argCalcs={argCalcs} calcState={calcState} setCalcState={setCalcState} />
            <div className="flex items-center gap-1">
              <Button asChild variant="outline" size="sm"><a href={exportUrl("csv")} download aria-label="export csv"><Download /> CSV</a></Button>
              <Button asChild variant="outline" size="sm"><a href={exportUrl("json")} download aria-label="export json"><Download /> JSON</a></Button>
            </div>
            {hasSensitive && (
              <label className="flex items-center gap-2 text-sm text-muted-foreground">
                {reveal ? <Eye className="size-4" /> : <EyeOff className="size-4" />} Sensitive
                <Switch checked={reveal} onCheckedChange={setReveal} aria-label="show sensitive" />
              </label>
            )}
          </div>
          {meta.actions.some((a) => a.type === "create") && <Button onClick={() => setEditing({})}><Plus /> New</Button>}
        </div>
        {filterOpen && (
          <div className="rounded-md border p-3">
            <FilterBuilder fields={filterFields} errors={filterErrors} initial={filterState} onApply={(rows, join) => setFilterState({ rows, join })} />
          </div>
        )}
        {selected.size > 0 && (
          <div className="flex flex-wrap items-center gap-2 rounded-md bg-muted px-3 py-2 text-sm" role="toolbar" aria-label="bulk actions">
            <span>{selected.size} selected</span>
            {updateActions.length > 0 && <Button size="sm" variant="outline" onClick={() => setBulk("update")}><Pencil /> Update…</Button>}
            {destroyAction && <Button size="sm" variant="destructive" onClick={() => setBulk("destroy")}><Trash2 /> Destroy</Button>}
            <Button size="sm" variant="ghost" onClick={() => setSelected(new Set())}>Clear</Button>
          </div>
        )}
      </CardHeader>
      <CardContent>
        {error && <p role="alert" className="mb-2 text-sm text-destructive">{error}</p>}
        <Table>
          <TableHeader>
            <TableRow>
              {canWrite && <TableHead className="w-8"><Checkbox aria-label="select all" checked={allSelected ? true : selected.size > 0 ? "indeterminate" : false} onCheckedChange={toggleAll} /></TableHead>}
              {cols.map((c) => {
                const i = sorts.findIndex((s) => s.field === c.name);
                return (
                  <TableHead key={c.name} aria-sort={i === -1 ? "none" : sorts[i].dir === "asc" ? "ascending" : "descending"}>
                    <button type="button" className="inline-flex items-center gap-1 hover:text-foreground" title="Click to sort, shift-click to add a sort" onClick={(e) => toggleSort(c.name, e.shiftKey)}>
                      {c.name}
                      {i !== -1 && (sorts[i].dir === "asc" ? <ArrowUp className="size-3" /> : <ArrowDown className="size-3" />)}
                      {i !== -1 && sorts.length > 1 && <span className="text-[10px]">{i + 1}</span>}
                    </button>
                  </TableHead>
                );
              })}
              {canWrite && <TableHead />}
            </TableRow>
          </TableHeader>
          <TableBody>
            {records.map((r) => {
              const id = String(r[pk]);
              return (
                <TableRow key={id} data-state={selected.has(id) ? "selected" : undefined}>
                  {canWrite && <TableCell><Checkbox aria-label={`select ${id}`} checked={selected.has(id)} onCheckedChange={() => toggleOne(id)} /></TableCell>}
                  {cols.map((c) => (
                    <TableCell key={c.name}>
                      {c.name === linkCol ? <Link to={recordPath(meta.module, id)} className="font-medium underline-offset-4 hover:underline">{formatCell(r[c.name])}</Link> : formatCell(r[c.name])}
                    </TableCell>
                  ))}
                  {canWrite && (
                    <TableCell className="text-right">
                      <Button size="icon" variant="ghost" aria-label="edit" onClick={() => setEditing({ record: r })}><Pencil /></Button>
                    </TableCell>
                  )}
                </TableRow>
              );
            })}
            {data && records.length === 0 && (
              <TableRow><TableCell colSpan={cols.length + 2} className="text-center text-muted-foreground">No records</TableCell></TableRow>
            )}
          </TableBody>
        </Table>
        <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-sm text-muted-foreground">
          <span>{data ? `${data.count ?? records.length} total` : ""}</span>
          <div className="flex items-center gap-2">
            <Select value={String(size)} onValueChange={(v) => setSize(Number(v))}>
              <SelectTrigger className="h-8 w-24" aria-label="page size"><SelectValue /></SelectTrigger>
              <SelectContent>{PAGE_SIZES.map((n) => <SelectItem key={n} value={String(n)}>{n} / page</SelectItem>)}</SelectContent>
            </Select>
            <Button size="sm" variant="outline" disabled={!hasPrev} onClick={prevPage}>Previous</Button>
            <Badge variant="secondary" aria-label="page number">{pageNo}</Badge>
            <Button size="sm" variant="outline" disabled={!hasNext} onClick={nextPage}>Next</Button>
          </div>
        </div>
      </CardContent>

      <Dialog open={!!editing} onOpenChange={(o) => !o && setEditing(null)}>
        <DialogContent className="max-h-[85vh] overflow-auto">
          <DialogHeader>
            <DialogTitle>{editing?.record ? `Edit ${meta.name}` : `New ${meta.name}`}</DialogTitle>
            <DialogDescription>Validated live by AshPhoenix.Form; policies apply to the selected actor.</DialogDescription>
          </DialogHeader>
          {editing && (
            <RecordForm meta={meta} record={editing.record} onCancel={() => setEditing(null)}
              onDone={() => { toast({ variant: "success", title: editing.record ? `${meta.name} saved` : `${meta.name} created` }); setEditing(null); refresh(); }} />
          )}
        </DialogContent>
      </Dialog>

      <Dialog open={bulk === "destroy"} onOpenChange={(o) => !o && setBulk(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Destroy {selected.size} record{selected.size === 1 ? "" : "s"}?</DialogTitle>
            <DialogDescription>Runs <b>{destroyAction?.name}</b> on each selected record; policies apply per record.</DialogDescription>
          </DialogHeader>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setBulk(null)}>Cancel</Button>
            <Button variant="destructive" onClick={() => runBulk("destroy", destroyAction?.name)}>Destroy</Button>
          </div>
        </DialogContent>
      </Dialog>

      <Dialog open={bulk === "update"} onOpenChange={(o) => !o && setBulk(null)}>
        <DialogContent className="max-h-[85vh] overflow-auto">
          <DialogHeader>
            <DialogTitle>Update {selected.size} record{selected.size === 1 ? "" : "s"}</DialogTitle>
            <DialogDescription>Only filled fields are sent.</DialogDescription>
          </DialogHeader>
          {bulk === "update" && <BulkUpdateForm meta={meta} actions={updateActions} onCancel={() => setBulk(null)} onRun={(a, p) => runBulk("update", a, p)} />}
        </DialogContent>
      </Dialog>
    </Card>
  );
}

function ColumnsMenu({ allCols, hidden, toggle, argCalcs, calcState, setCalcState }) {
  const patch = (name, p) => setCalcState((s) => ({ ...s, [name]: { on: false, args: {}, ...s[name], ...p } }));
  return (
    <Popover>
      <PopoverTrigger asChild><Button variant="outline"><Columns3 /> Columns</Button></PopoverTrigger>
      <PopoverContent className="max-h-96 w-80 overflow-auto">
        <div className="grid gap-2" aria-label="column visibility">
          {allCols.map((c) => (
            <label key={c.name} className="flex items-center gap-2 text-sm">
              <Checkbox aria-label={`column ${c.name}`} checked={!hidden.has(c.name)} onCheckedChange={() => toggle(c.name)} /> {c.name}
            </label>
          ))}
          {argCalcs.length > 0 && <div className="mt-2 border-t pt-2 text-xs font-semibold uppercase text-muted-foreground">Calculations with arguments</div>}
          {argCalcs.map((c) => (
            <div key={c.name} className="grid gap-1.5 rounded-md border p-2">
              <label className="flex items-center justify-between gap-2 text-sm font-medium">
                {c.name}
                <Switch aria-label={`load ${c.name}`} checked={!!calcState[c.name]?.on} onCheckedChange={(on) => patch(c.name, { on })} />
              </label>
              {c.arguments.map((a) => (
                <div key={a.name} className="grid gap-1">
                  <Label htmlFor={`ca-${c.name}-${a.name}`} className="text-xs">{a.name} {!a.allow_nil && <span className="text-destructive">*</span>}</Label>
                  <FieldControl id={`ca-${c.name}-${a.name}`} field={a} value={calcState[c.name]?.args?.[a.name]} onChange={(v) => patch(c.name, { args: { ...calcState[c.name]?.args, [a.name]: v } })} />
                </div>
              ))}
            </div>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
}

function BulkUpdateForm({ meta, actions, onCancel, onRun }) {
  const [name, setName] = useState((actions.find((a) => a.primary) ?? actions[0]).name);
  const [values, setValues] = useState({});
  const action = actions.find((a) => a.name === name);
  const fields = [
    ...meta.attributes.filter((a) => action.accept.includes(a.name)),
    ...action.arguments.filter((a) => !action.accept.includes(a.name) && !(action.managed_relationships ?? []).some((m) => m.argument === a.name)),
  ];
  const params = Object.fromEntries(Object.entries(values).filter(([, v]) => v !== "" && v !== undefined && v !== null));
  return (
    <div className="grid gap-3">
      <Select value={name} onValueChange={(v) => { setName(v); setValues({}); }}>
        <SelectTrigger aria-label="bulk update action"><SelectValue /></SelectTrigger>
        <SelectContent>{actions.map((a) => <SelectItem key={a.name} value={a.name}>{a.name}</SelectItem>)}</SelectContent>
      </Select>
      {fields.length === 0 && <p className="text-sm text-muted-foreground">This action takes no input.</p>}
      {fields.map((f) => (
        <div key={f.name} className="grid gap-1.5">
          <Label htmlFor={`bu-${f.name}`}>{f.name}</Label>
          <FieldControl id={`bu-${f.name}`} field={f} value={values[f.name]} onChange={(v) => setValues((x) => ({ ...x, [f.name]: v }))} />
        </div>
      ))}
      <div className="flex justify-end gap-2">
        <Button variant="outline" onClick={onCancel}>Cancel</Button>
        <Button onClick={() => onRun(name, params)}>Update</Button>
      </div>
    </div>
  );
}
