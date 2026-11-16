import React, { useEffect, useState } from "react";
import { ArrowLeft, ChevronDown, ChevronRight, Eye, EyeOff, Pencil, Trash2 } from "lucide-react";
import { api } from "../api.js";
import { useAdmin } from "../context.jsx";
import { RecordForm } from "../record_form.jsx";
import { FieldControl, ValueView, formatCell } from "../fields.jsx";
import { Link, recordPath, resourcePath } from "./link.jsx";
import { ApiErrorPage } from "./error_page.jsx";
import { Button } from "../../ui/button.jsx";
import { Badge } from "../../ui/badge.jsx";
import { Label } from "../../ui/label.jsx";
import { Switch } from "../../ui/switch.jsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../ui/card.jsx";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../ui/table.jsx";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "../../ui/dialog.jsx";
import { useToast } from "../../ui/toast.jsx";

const labelOf = (r) => r?.name || r?.title || r?.display_name || r?.label || r?.id;

// /admin/r/<module>/<id>: attributes (embedded/union/array aware), sensitive toggle, calculations
// (with argument inputs), aggregates, belongs_to/has_one links, lazily-loaded has_many tables.
export function RecordShow({ meta, id }) {
  const { ctx, navigate, authorize, actorId, tenant } = useAdmin();
  const { toast } = useToast();
  const [rec, setRec] = useState(null);
  const [error, setError] = useState(null);
  const [reveal, setReveal] = useState(false);
  const [calcState, setCalcState] = useState({});
  const [editing, setEditing] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [tick, setTick] = useState(0);

  const toOne = meta.relationships.filter((r) => r.cardinality === "one");
  const toMany = meta.relationships.filter((r) => r.cardinality === "many");
  const plainCalcs = meta.calculations.filter((c) => c.arguments.length === 0);
  const argCalcs = meta.calculations.filter((c) => c.arguments.length > 0);
  const hasSensitive = meta.attributes.some((a) => a.sensitive);
  const active = argCalcs.filter((c) => calcState[c.name]?.loaded);

  useEffect(() => {
    let live = true;
    setError(null);
    const calc_args = Object.fromEntries(active.map((c) => [c.name, calcState[c.name].args]));
    api
      .record(meta.module, id, {
        load: [...toOne, ...plainCalcs, ...active, ...meta.aggregates].map((x) => x.name).join(","),
        calc_args: active.length ? calc_args : undefined,
        reveal: reveal ? "true" : undefined,
        ...ctx,
      })
      .then((d) => live && setRec(d))
      .catch((e) => live && (setError(e), setRec(null)));
    return () => { live = false; };
  }, [meta.module, id, reveal, tick, authorize, actorId, tenant, JSON.stringify(active.map((c) => [c.name, calcState[c.name].args]))]);

  const home = () => navigate(resourcePath(meta.module));
  if (error) return <ApiErrorPage error={error} onHome={home} />;
  if (!rec) return <p className="text-muted-foreground">Loading…</p>;

  const destroyAction = meta.actions.find((a) => a.type === "destroy");
  const canEdit = meta.actions.some((a) => a.type === "update");
  const relFor = (attr) => toOne.find((r) => r.type === "belongs_to" && r.source_attribute === attr.name);

  async function destroy() {
    try {
      const r = await api.submit(meta.module, { action: destroyAction.name, id, params: {} }, ctx);
      if (r.errors?.length) return toast({ variant: "destructive", title: "Could not destroy", description: r.errors.map((e) => e.message).join("; ") });
      toast({ variant: "success", title: `${meta.name} destroyed` });
      home();
    } catch (e) {
      toast({ variant: "destructive", title: "Could not destroy", description: e.message });
    }
  }

  return (
    <div className="grid gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <Link to={resourcePath(meta.module)} className="mb-1 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"><ArrowLeft className="size-3" /> {meta.name}</Link>
          <h1 className="text-2xl font-semibold tracking-tight">{meta.name} <span className="text-base font-normal text-muted-foreground">{String(labelOf(rec))}</span></h1>
        </div>
        <div className="flex items-center gap-3">
          {hasSensitive && (
            <label className="flex items-center gap-2 text-sm text-muted-foreground">
              {reveal ? <Eye className="size-4" /> : <EyeOff className="size-4" />} Sensitive
              <Switch aria-label="show sensitive" checked={reveal} onCheckedChange={setReveal} />
            </label>
          )}
          {canEdit && <Button variant="outline" onClick={() => setEditing(true)}><Pencil /> Edit</Button>}
          {destroyAction && <Button variant="destructive" onClick={() => setDeleting(true)}><Trash2 /> Delete</Button>}
        </div>
      </div>

      <Card>
        <CardHeader><CardTitle>Attributes</CardTitle></CardHeader>
        <CardContent>
          <dl className="grid gap-x-6 gap-y-3 md:grid-cols-[minmax(8rem,12rem)_1fr]">
            {meta.attributes.filter((a) => reveal || !a.sensitive).map((a) => {
              const rel = relFor(a);
              return (
                <React.Fragment key={a.name}>
                  <dt className="text-sm text-muted-foreground">{a.name} <Badge variant="outline">{a.type}</Badge>{a.sensitive && <Badge variant="destructive" className="ml-1">sensitive</Badge>}</dt>
                  <dd className="text-sm" data-testid={`attr-${a.name}`}>
                    {rel && rec[a.name] ? (
                      <Link to={recordPath(rel.destination_module, rec[a.name])} className="underline underline-offset-4">
                        {String(labelOf(rec[rel.name]) ?? rec[a.name])}
                      </Link>
                    ) : (
                      <ValueView field={a} value={rec[a.name]} />
                    )}
                  </dd>
                </React.Fragment>
              );
            })}
            {plainCalcs.map((c) => (
              <React.Fragment key={c.name}>
                <dt className="text-sm text-muted-foreground">{c.name} <Badge variant="outline">calculation</Badge></dt>
                <dd className="text-sm" data-testid={`calc-${c.name}`}><ValueView field={c} value={rec[c.name]} /></dd>
              </React.Fragment>
            ))}
            {toOne.filter((r) => r.type !== "belongs_to").map((r) => (
              <React.Fragment key={r.name}>
                <dt className="text-sm text-muted-foreground">{r.name} <Badge variant="outline">{r.type}</Badge></dt>
                <dd className="text-sm" data-testid={`rel-${r.name}`}>
                  {rec[r.name] ? <Link to={recordPath(r.destination_module, rec[r.name].id)} className="underline underline-offset-4">{String(labelOf(rec[r.name]))}</Link> : <span className="text-muted-foreground">—</span>}
                </dd>
              </React.Fragment>
            ))}
            {meta.aggregates.map((c) => (
              <React.Fragment key={c.name}>
                <dt className="text-sm text-muted-foreground">{c.name} <Badge variant="outline">aggregate</Badge></dt>
                <dd className="text-sm" data-testid={`agg-${c.name}`}><ValueView field={c} value={rec[c.name]} /></dd>
              </React.Fragment>
            ))}
          </dl>
        </CardContent>
      </Card>

      {argCalcs.length > 0 && (
        <Card>
          <CardHeader><CardTitle>Calculations with arguments</CardTitle></CardHeader>
          <CardContent className="grid gap-4">
            {argCalcs.map((c) => {
              const st = calcState[c.name] ?? { args: {} };
              const ready = c.arguments.every((a) => a.allow_nil || st.args?.[a.name]);
              return (
                <div key={c.name} className="grid gap-2 rounded-md border p-3">
                  <div className="font-medium">{c.name} <Badge variant="outline">{c.type}</Badge></div>
                  {c.arguments.map((a) => (
                    <div key={a.name} className="grid gap-1.5">
                      <Label htmlFor={`arg-${c.name}-${a.name}`}>{a.name} {!a.allow_nil && <span className="text-destructive">*</span>}</Label>
                      <FieldControl id={`arg-${c.name}-${a.name}`} field={a} value={st.args?.[a.name]} onChange={(v) => setCalcState((s) => ({ ...s, [c.name]: { ...st, loaded: false, args: { ...st.args, [a.name]: v } } }))} />
                    </div>
                  ))}
                  <div className="flex items-center gap-3">
                    <Button size="sm" disabled={!ready} onClick={() => setCalcState((s) => ({ ...s, [c.name]: { ...st, loaded: true } }))}>Load</Button>
                    {st.loaded && <span data-testid={`calc-${c.name}`} className="text-sm"><ValueView field={c} value={rec[c.name]} /></span>}
                  </div>
                </div>
              );
            })}
          </CardContent>
        </Card>
      )}

      {toMany.map((r) => <RelatedMany key={r.name} meta={meta} rel={r} id={id} />)}

      <Dialog open={editing} onOpenChange={setEditing}>
        <DialogContent className="max-h-[85vh] overflow-auto">
          <DialogHeader><DialogTitle>Edit {meta.name}</DialogTitle><DialogDescription>Validated live by AshPhoenix.Form.</DialogDescription></DialogHeader>
          {editing && <RecordForm meta={meta} record={rec} onCancel={() => setEditing(false)} onDone={() => { toast({ variant: "success", title: `${meta.name} saved` }); setEditing(false); setTick((t) => t + 1); }} />}
        </DialogContent>
      </Dialog>
      <Dialog open={deleting} onOpenChange={setDeleting}>
        <DialogContent>
          <DialogHeader><DialogTitle>Delete this {meta.name}?</DialogTitle><DialogDescription>Runs <b>{destroyAction?.name}</b>; policies apply to the selected actor.</DialogDescription></DialogHeader>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setDeleting(false)}>Cancel</Button>
            <Button variant="destructive" onClick={() => { setDeleting(false); destroy(); }}>Delete</Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

const SMALL = 10;

// Lazy has_many (and other to-many) relationship: nothing is fetched until the section opens.
// has_many pages through the destination resource filtered by its foreign key; other to-many
// kinds load the relationship through the record read.
export function RelatedMany({ meta, rel, id }) {
  const { ctx } = useAdmin();
  const [open, setOpen] = useState(false);
  const [dest, setDest] = useState(null);
  const [data, setData] = useState(null);
  const [offset, setOffset] = useState(0);
  const [error, setError] = useState(null);
  const paged = rel.type === "has_many";

  useEffect(() => {
    if (!open) return;
    let live = true;
    setError(null);
    (async () => {
      const dm = dest ?? (await api.resource(rel.destination_module));
      if (!live) return;
      setDest(dm);
      if (paged) {
        const d = await api.records(rel.destination_module, {
          limit: SMALL, offset, ...ctx,
          filter: JSON.stringify({ [rel.destination_attribute]: { eq: id } }),
          load: dm.aggregates.map((a) => a.name).join(","),
        });
        live && setData(d);
      } else {
        const full = await api.record(meta.module, id, { load: rel.name, ...ctx });
        const list = full[rel.name] ?? [];
        live && setData({ records: list, count: list.length });
      }
    })().catch((e) => live && setError(e.message));
    return () => { live = false; };
  }, [open, offset, id]);

  const cols = dest ? dest.attributes.filter((a) => !a.sensitive && a.name !== rel.destination_attribute && !a.primary_key).slice(0, 5) : [];
  const dpk = dest?.primary_key?.[0] ?? "id";
  return (
    <Card>
      <CardHeader className="py-3">
        <button type="button" aria-expanded={open} className="flex items-center gap-2 text-left" onClick={() => setOpen((o) => !o)}>
          {open ? <ChevronDown className="size-4" /> : <ChevronRight className="size-4" />}
          <CardTitle className="text-base">{rel.name}</CardTitle>
          <Badge variant="outline">{rel.type} → {rel.destination}</Badge>
          {data && <Badge variant="secondary">{data.count}</Badge>}
        </button>
      </CardHeader>
      {open && (
        <CardContent>
          {error && <p role="alert" className="text-sm text-destructive">{error}</p>}
          {!data && !error && <p className="text-sm text-muted-foreground">Loading…</p>}
          {data && (
            <>
              <Table>
                <TableHeader><TableRow>{cols.map((c) => <TableHead key={c.name}>{c.name}</TableHead>)}</TableRow></TableHeader>
                <TableBody>
                  {data.records.map((r, i) => (
                    <TableRow key={r[dpk] ?? i}>
                      {cols.map((c, ci) => (
                        <TableCell key={c.name}>
                          {ci === 0 && r[dpk] ? <Link to={recordPath(rel.destination_module, r[dpk])} className="underline underline-offset-4">{formatCell(r[c.name])}</Link> : formatCell(r[c.name])}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))}
                  {data.records.length === 0 && <TableRow><TableCell colSpan={Math.max(cols.length, 1)} className="text-center text-muted-foreground">None</TableCell></TableRow>}
                </TableBody>
              </Table>
              {paged && (
                <div className="mt-2 flex justify-end gap-2">
                  <Button size="sm" variant="outline" disabled={offset === 0} onClick={() => setOffset(Math.max(0, offset - SMALL))}>Previous</Button>
                  <Button size="sm" variant="outline" disabled={offset + SMALL >= data.count} onClick={() => setOffset(offset + SMALL)}>Next</Button>
                </div>
              )}
            </>
          )}
        </CardContent>
      )}
    </Card>
  );
}
