import React, { useEffect, useMemo, useRef, useState } from "react";
import { MarkerType } from "@xyflow/react";
import { Canvas } from "./canvas.jsx";
import { Controls } from "./controls.jsx";
import { Panel } from "./panel.jsx";
import { Connection } from "./connection.jsx";
import { edgeTypes } from "./edge.jsx";
import { nodeTypes } from "./step_node.jsx";
import { edgeKind, layout, statusesAt } from "./layout.js";
import { workflowApi } from "./api.js";
import { api } from "../api.js";
import { useAdmin } from "../context.jsx";
import { Button } from "../../ui/button.jsx";
import { Input } from "../../ui/input.jsx";
import { Label } from "../../ui/label.jsx";
import { Badge } from "../../ui/badge.jsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../ui/card.jsx";

const STEP_MS = 450;

export default function WorkflowPage() {
  const { ctx } = useAdmin();
  const [mounted, setMounted] = useState(false);
  const [workflows, setWorkflows] = useState([]);
  const [selected, setSelected] = useState(null);
  const [graph, setGraph] = useState(null);
  const [inputs, setInputs] = useState({});
  const [posts, setPosts] = useState([]);
  const [run, setRun] = useState(null);
  const [shown, setShown] = useState(0);
  const [running, setRunning] = useState(false);
  const [error, setError] = useState(null);
  const timer = useRef(null);

  useEffect(() => {
    setMounted(true);
    workflowApi.list().then((d) => {
      setWorkflows(d.workflows);
      if (d.workflows[0]) setSelected(d.workflows[0].name);
    }).catch((e) => setError(e.message));
    api.records("Playground.Blog.Post", { limit: 50 }).then((d) => setPosts(d.records ?? [])).catch(() => {});
    return () => clearTimeout(timer.current);
  }, []);

  useEffect(() => {
    if (!selected) return;
    setRun(null); setShown(0); setGraph(null);
    workflowApi.graph(selected).then((d) => {
      setGraph(d.graph);
      setInputs(Object.fromEntries(d.workflow.inputs.map((i) => [i.name, i.default ?? ""])));
    }).catch((e) => setError(e.message));
  }, [selected]);

  const events = run?.events ?? [];
  const statuses = useMemo(() => statusesAt(events, shown), [run, shown]);
  const active = running || (run !== null && shown > 0);

  const { nodes, edges } = useMemo(() => {
    if (!graph) return { nodes: [], edges: [] };
    const pos = layout(graph.nodes, graph.edges);
    const errors = {};
    for (const e of events.slice(0, shown)) if (e.error) errors[e.step] = e.error;
    return {
      nodes: graph.nodes.map((n) => ({
        id: n.id,
        type: n.type,
        position: pos[n.id],
        data: { ...n, status: n.type === "step" ? (statuses[n.id] ?? "pending") : undefined, error: errors[n.id], isReturn: n.return },
      })),
      edges: graph.edges.map((e) => ({
        ...e,
        type: edgeKind(e, statuses, active),
        markerEnd: { type: MarkerType.ArrowClosed },
      })),
    };
  }, [graph, statuses, active]);

  const play = (r) => {
    setRun(r); setShown(0); setRunning(true);
    const tick = (i) => {
      setShown(i);
      if (i < r.events.length) timer.current = setTimeout(() => tick(i + 1), STEP_MS);
      else setRunning(false);
    };
    tick(1);
  };

  const onRun = async () => {
    clearTimeout(timer.current);
    setError(null);
    try {
      play(await workflowApi.run(selected, inputs, ctx));
    } catch (e) {
      setError(e.message);
    }
  };

  const current = workflows.find((w) => w.name === selected);

  return (
    <div className="flex h-[calc(100vh-6rem)] flex-col gap-3" data-testid="workflow-page">
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="mr-4 text-xl font-semibold">Workflows</h1>
        {workflows.map((w) => (
          <Button key={w.name} size="sm" variant={w.name === selected ? "default" : "outline"} onClick={() => setSelected(w.name)}>
            {w.title}
          </Button>
        ))}
        {error && <Badge variant="destructive">{error}</Badge>}
      </div>
      <div className="relative min-h-0 flex-1 overflow-hidden rounded-xl border">
        {mounted && graph && (
          <Canvas nodes={nodes} edges={edges} nodeTypes={nodeTypes} edgeTypes={edgeTypes} connectionLineComponent={Connection} nodesConnectable={false}>
            <Controls />
            <Panel position="top-left" className="flex items-center gap-1">
              <Button size="sm" onClick={onRun} disabled={running} data-testid="wf-run">{running ? "Running…" : "Run"}</Button>
              <Button size="sm" variant="ghost" onClick={() => { clearTimeout(timer.current); setRun(null); setShown(0); setRunning(false); }}>Reset</Button>
            </Panel>
            <Panel position="top-right" className="max-h-[calc(100%-2rem)] w-80 overflow-auto p-0">
              <Card className="border-0 shadow-none">
                <CardHeader className="p-4 pb-2">
                  <CardTitle className="text-base">{current?.title}</CardTitle>
                  <CardDescription>{current?.description}</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3 p-4 pt-2">
                  {(current?.inputs ?? []).map((i) => (
                    <div key={i.name} className="space-y-1">
                      <Label htmlFor={`wf-in-${i.name}`}>{i.label}</Label>
                      {i.name === "post_id" ? (
                        <select
                          id={`wf-in-${i.name}`}
                          className="h-9 w-full rounded-md border bg-background px-2 text-sm"
                          value={inputs[i.name] ?? ""}
                          onChange={(e) => setInputs({ ...inputs, [i.name]: e.target.value })}
                        >
                          <option value="">select a post…</option>
                          {posts.map((p) => <option key={p.id} value={p.id}>{p.title} ({p.status})</option>)}
                        </select>
                      ) : (
                        <Input id={`wf-in-${i.name}`} value={inputs[i.name] ?? ""} onChange={(e) => setInputs({ ...inputs, [i.name]: e.target.value })} />
                      )}
                    </div>
                  ))}
                  <div data-testid="wf-log" className="space-y-1 border-t pt-2 text-xs">
                    <div className="font-semibold">Run log</div>
                    {events.slice(0, shown).map((e, i) => (
                      <div key={i} className="flex justify-between gap-2">
                        <span>{e.step}</span>
                        <span className={e.status === "error" ? "text-red-600" : e.status === "undone" ? "text-amber-600" : ""}>{e.status}</span>
                      </div>
                    ))}
                    {run && !running && (
                      <div className="mt-2 rounded-md border p-2" data-testid="wf-result">
                        <Badge variant={run.status === "ok" ? "secondary" : "destructive"}>{run.status}</Badge>
                        {run.error && <div className="mt-1 text-red-600">{run.error}</div>}
                        {run.result && <pre className="mt-1 whitespace-pre-wrap break-all">{JSON.stringify(run.result, null, 2).slice(0, 600)}</pre>}
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>
            </Panel>
          </Canvas>
        )}
      </div>
    </div>
  );
}
