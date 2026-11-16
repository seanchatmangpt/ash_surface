import React, { useCallback, useEffect, useState } from "react";
import { Play } from "lucide-react";
import { api } from "./api.js";
import { useAdmin } from "./context.jsx";
import { FieldControl, encodeValue } from "./fields.jsx";
import { DataTable } from "./core/data_table.jsx";
import { RecordShow } from "./core/record_show.jsx";
import { ApiErrorPage } from "./core/error_page.jsx";
import { Button } from "../ui/button.jsx";
import { Badge } from "../ui/badge.jsx";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "../ui/card.jsx";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../ui/table.jsx";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../ui/tabs.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../ui/select.jsx";
import { Label } from "../ui/label.jsx";
import { pluginTabs } from "./plugins/index.js";

export function ResourceView({ resource, recordId }) {
  const [meta, setMeta] = useState(null);
  const [error, setError] = useState(null);
  const { navigate } = useAdmin();
  useEffect(() => {
    setMeta(null);
    setError(null);
    api.resource(resource).then(setMeta).catch((e) => setError(e));
  }, [resource]);

  if (error) return <ApiErrorPage error={error} onHome={() => navigate("/admin")} />;
  if (!meta) return <p className="text-muted-foreground">Loading…</p>;
  if (recordId) return <RecordShow meta={meta} id={recordId} />;
  const generic = meta.actions.filter((a) => a.type === "action");
  const extraTabs = pluginTabs.filter((t) => t.render(meta) != null);
  return (
    <div className="grid gap-4">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">{meta.name}</h1>
        <p className="text-sm text-muted-foreground">{meta.module}</p>
      </div>
      <Tabs defaultValue="data">
        <TabsList>
          <TabsTrigger value="data">Data</TabsTrigger>
          <TabsTrigger value="schema">Schema</TabsTrigger>
          {generic.length > 0 && <TabsTrigger value="actions">Actions</TabsTrigger>}
          {extraTabs.map((t) => <TabsTrigger key={t.id} value={t.id}>{t.label}</TabsTrigger>)}
        </TabsList>
        <TabsContent value="data"><DataTable meta={meta} /></TabsContent>
        <TabsContent value="schema"><Schema meta={meta} /></TabsContent>
        {generic.length > 0 && <TabsContent value="actions"><GenericActions meta={meta} actions={generic} /></TabsContent>}
        {extraTabs.map((t) => <TabsContent key={t.id} value={t.id}>{t.render(meta)}</TabsContent>)}
      </Tabs>
    </div>
  );
}

function Schema({ meta }) {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <Card><CardHeader><CardTitle>Attributes</CardTitle></CardHeader><CardContent>
        <Table><TableHeader><TableRow><TableHead>name</TableHead><TableHead>type</TableHead><TableHead>flags</TableHead></TableRow></TableHeader>
          <TableBody>{meta.attributes.map((a) => (
            <TableRow key={a.name}><TableCell>{a.name}</TableCell><TableCell>{a.type}</TableCell>
              <TableCell className="space-x-1">
                {a.primary_key && <Badge>pk</Badge>}{a.allow_nil === false && <Badge variant="secondary">required</Badge>}{a.sensitive && <Badge variant="destructive">sensitive</Badge>}
              </TableCell></TableRow>))}</TableBody></Table>
      </CardContent></Card>
      <Card><CardHeader><CardTitle>Relationships, calculations, aggregates</CardTitle></CardHeader><CardContent className="grid gap-1 text-sm">
        {meta.relationships.map((r) => <div key={r.name}><b>{r.name}</b> <Badge variant="outline">{r.type}</Badge> → {r.destination}</div>)}
        {meta.calculations.map((c) => <div key={c.name}><b>{c.name}</b> <Badge variant="outline">calculation</Badge> {c.type}</div>)}
        {meta.aggregates.map((c) => <div key={c.name}><b>{c.name}</b> <Badge variant="outline">aggregate</Badge> {c.type}</div>)}
      </CardContent></Card>
      <Card className="md:col-span-2"><CardHeader><CardTitle>Actions</CardTitle></CardHeader><CardContent className="flex flex-wrap gap-2">
        {meta.actions.map((a) => <Badge key={a.name} variant={a.primary ? "default" : "secondary"}>{a.name} · {a.type}</Badge>)}
      </CardContent></Card>
    </div>
  );
}

function GenericActions({ meta, actions }) {
  const { ctx } = useAdmin();
  const [name, setName] = useState(actions[0].name);
  const action = actions.find((a) => a.name === name);
  const [params, setParams] = useState({});
  const [result, setResult] = useState(null);
  async function run() {
    try { setResult(await api.run(meta.module, { action: name, params }, ctx)); }
    catch (e) { setResult({ error: e.message }); }
  }
  return (
    <Card><CardHeader><CardTitle>Generic actions</CardTitle><CardDescription>Runs through Ash.ActionInput with the selected actor.</CardDescription></CardHeader>
      <CardContent className="grid gap-3">
        <Select value={name} onValueChange={(v) => { setName(v); setParams({}); setResult(null); }}>
          <SelectTrigger className="w-60"><SelectValue /></SelectTrigger>
          <SelectContent>{actions.map((a) => <SelectItem key={a.name} value={a.name}>{a.name}</SelectItem>)}</SelectContent>
        </Select>
        {action.arguments.map((a) => (
          <div key={a.name} className="grid gap-1.5"><Label>{a.name}</Label>
            <FieldControl id={`ga-${a.name}`} field={a} value={params[a.name]} onChange={(v) => setParams({ ...params, [a.name]: encodeValue(a, v) })} /></div>
        ))}
        <div><Button onClick={run}><Play /> Run</Button></div>
        {result && <pre className="rounded-md bg-muted p-3 text-xs">{JSON.stringify(result, null, 2)}</pre>}
      </CardContent></Card>
  );
}
