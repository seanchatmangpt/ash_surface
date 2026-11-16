import React, { useEffect, useMemo, useRef, useState } from "react";
import { nanoid } from "nanoid";
import { useAdmin } from "../context.jsx";
import { api } from "../api.js";
import { Input } from "../../ui/input.jsx";
import { Button } from "../../ui/button.jsx";
import { Checkpoint, CodeBlock, FileTree, Plan, Queue, Terminal } from "./elements.jsx";
import { flattenTree, parseCommand, runQueue, toRunBody } from "./logic.js";

const get = async (path, query) => {
  const res = await fetch(`/admin/api${path}${query ? `?${new URLSearchParams(query)}` : ""}`);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || res.statusText);
  return data;
};
const postRun = async (body) => {
  const res = await fetch("/admin/api/ide/run", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || res.statusText);
  return data;
};

export function Studio() {
  const { ctx } = useAdmin();
  const [tree, setTree] = useState([]);
  const [resources, setResources] = useState([]);
  const [selected, setSelected] = useState(null);
  const [source, setSource] = useState({ path: null, content: "# Select a file from the tree", error: null });
  const [draft, setDraft] = useState("");
  const [draftError, setDraftError] = useState(null);
  const [plan, setPlan] = useState([]);
  const [queue, setQueue] = useState([]);
  const [running, setRunning] = useState(false);
  const [entries, setEntries] = useState([]);
  const runCount = useRef(0);

  useEffect(() => {
    get("/ide/tree").then((d) => setTree(d.tree)).catch(() => {});
    api.domains().then((d) => setResources(d.domains.flatMap((x) => x.resources))).catch(() => {});
  }, []);

  const select = (node) => {
    setSelected(node.path);
    get("/ide/file", { path: node.path })
      .then((d) => setSource({ path: d.path, content: d.content, error: null }))
      .catch((e) => setSource({ path: node.path, content: `# ${e.message}`, error: e.message }));
    const short = node.module?.split(".").pop();
    if (short && !draft) setDraft(`${short}.read()`);
  };

  const addToPlan = () => {
    const cmd = parseCommand(draft);
    const built = cmd.error ? cmd : toRunBody(cmd, resources, ctx);
    if (built.error) return setDraftError(built.error);
    setDraftError(null);
    setPlan((p) => [...p, { id: nanoid(8), command: draft.trim(), body: built.body }]);
  };

  const enqueue = (it) => {
    setPlan((p) => p.filter((x) => x.id !== it.id));
    setQueue((q) => [...q, { ...it, state: "pending" }]);
  };

  const runAll = async () => {
    const pending = queue.filter((q) => q.state === "pending");
    if (!pending.length) return;
    setRunning(true);
    const n = ++runCount.current;
    setEntries((e) => [...e, { checkpoint: true, label: `Checkpoint ${n}` }]);
    const mark = (id, state) => setQueue((q) => q.map((x) => (x.id === id ? { ...x, state } : x)));
    await runQueue(
      pending,
      async (it) => { mark(it.id, "running"); return postRun({ ...it.body, ...ctx }); },
      (r, i) => { mark(pending[i].id, r.status === "ok" ? "ok" : "error"); setEntries((e) => [...e, r]); },
    );
    setRunning(false);
  };

  return (
    <div className="grid gap-3">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Ash Studio</h1>
        <p className="text-sm text-muted-foreground">Browse resource source, plan action runs, queue them and watch the terminal.</p>
      </div>
      <div className="grid h-[70vh] grid-cols-[14rem_minmax(0,1fr)_20rem] gap-3">
        <div className="overflow-auto rounded-lg border bg-card p-2">
          <FileTree nodes={tree} selected={selected} onSelect={select} />
        </div>
        <div className="flex min-h-0 flex-col gap-3">
          <div className="min-h-0 flex-1 overflow-auto rounded-lg border">
            <div className="border-b px-3 py-1.5 text-xs text-muted-foreground">{source.path ?? "no file"}</div>
            <CodeBlock code={source.content} language="elixir" className="rounded-none" />
          </div>
          <Terminal className="h-56" entries={entries} onClear={() => setEntries([])} />
        </div>
        <div className="flex min-h-0 flex-col gap-3 overflow-auto">
          <div className="grid gap-1">
            <div className="flex gap-2">
              <Input aria-label="command" value={draft} placeholder='Post.create(title: "x")' onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && addToPlan()} />
              <Button type="button" onClick={addToPlan}>Plan</Button>
            </div>
            {draftError && <div className="text-xs text-destructive">{draftError}</div>}
          </div>
          <Plan items={plan} onRemove={(it) => setPlan((p) => p.filter((x) => x.id !== it.id))} onRun={enqueue} />
          <Queue items={queue} running={running} onRun={runAll} onClear={() => setQueue([])} />
          {entries.filter((e) => e.checkpoint).map((e) => <Checkpoint key={e.label} label={e.label} />)}
        </div>
      </div>
    </div>
  );
}
