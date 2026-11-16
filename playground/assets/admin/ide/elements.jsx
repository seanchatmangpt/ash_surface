import React, { useEffect, useState } from "react";
import { ChevronRight, File, Folder, FolderOpen, Flag, Terminal as TermIcon, ListChecks, ListOrdered, X } from "lucide-react";
import { cn } from "../../lib/utils.js";

// Hand-ported, shadcn-style versions of the AI Elements pieces used by the IDE example.

// ---- FileTree ----
export function FileTree({ nodes, selected, onSelect, className }) {
  return (
    <div className={cn("text-sm", className)} role="tree">
      {nodes.map((n) => <TreeNode key={n.path ?? n.name} node={n} selected={selected} onSelect={onSelect} depth={0} />)}
    </div>
  );
}
function TreeNode({ node, selected, onSelect, depth }) {
  const [open, setOpen] = useState(true);
  const pad = { paddingLeft: 8 + depth * 14 };
  if (node.children) {
    return (
      <div role="treeitem" aria-expanded={open}>
        <button type="button" style={pad} className="flex w-full items-center gap-1.5 rounded px-2 py-1 text-left hover:bg-accent" onClick={() => setOpen(!open)}>
          <ChevronRight className={cn("size-3.5 transition-transform", open && "rotate-90")} />
          {open ? <FolderOpen className="size-4 text-muted-foreground" /> : <Folder className="size-4 text-muted-foreground" />}
          <span className="truncate font-medium">{node.name}</span>
        </button>
        {open && node.children.map((c) => <TreeNode key={c.path ?? c.name} node={c} selected={selected} onSelect={onSelect} depth={depth + 1} />)}
      </div>
    );
  }
  return (
    <button type="button" role="treeitem" aria-selected={selected === node.path} style={pad} onClick={() => onSelect(node)}
      className={cn("flex w-full items-center gap-1.5 rounded px-2 py-1 text-left hover:bg-accent", selected === node.path && "bg-accent font-medium")}>
      <File className="size-4 text-muted-foreground" /> <span className="truncate">{node.name}</span>
    </button>
  );
}

// ---- CodeBlock (shiki, lazily loaded in an effect: SSR-safe) ----
let highlighterPromise;
function getHighlighter() {
  highlighterPromise ??= (async () => {
    const [{ createHighlighterCore }, { createJavaScriptRegexEngine }, elixir, theme] = await Promise.all([
      import("shiki/core"), import("shiki/engine/javascript"), import("@shikijs/langs/elixir"), import("@shikijs/themes/github-dark"),
    ]);
    return createHighlighterCore({ themes: [theme.default], langs: [elixir.default], engine: createJavaScriptRegexEngine() });
  })();
  return highlighterPromise;
}

export function CodeBlock({ code, language = "elixir", className }) {
  const [html, setHtml] = useState(null);
  useEffect(() => {
    let live = true;
    setHtml(null);
    getHighlighter().then((h) => live && setHtml(h.codeToHtml(code, { lang: language, theme: "github-dark" }))).catch(() => {});
    return () => { live = false; };
  }, [code, language]);
  return html ? (
    <div className={cn("overflow-auto rounded-md text-xs [&_pre]:p-4", className)} data-testid="codeblock" dangerouslySetInnerHTML={{ __html: html }} />
  ) : (
    <pre className={cn("overflow-auto rounded-md bg-[#24292e] p-4 text-xs text-[#e1e4e8]", className)} data-testid="codeblock"><code>{code}</code></pre>
  );
}

// ---- Terminal ----
export function Terminal({ entries, onClear, className }) {
  return (
    <div className={cn("flex flex-col overflow-hidden rounded-md border bg-zinc-950 text-zinc-100", className)}>
      <div className="flex items-center justify-between border-b border-zinc-800 px-3 py-1.5 text-xs text-zinc-400">
        <span className="flex items-center gap-1.5"><TermIcon className="size-3.5" /> Terminal</span>
        {onClear && <button type="button" onClick={onClear} className="hover:text-zinc-100">Clear</button>}
      </div>
      <div className="min-h-0 flex-1 overflow-auto p-3 font-mono text-xs leading-5" data-testid="terminal">
        {entries.length === 0 && <div className="text-zinc-500">No runs yet.</div>}
        {entries.map((e, i) => <TerminalEntry key={i} entry={e} />)}
      </div>
    </div>
  );
}
function TerminalEntry({ entry }) {
  if (entry.checkpoint) return null;
  const ok = entry.status === "ok";
  return (
    <div className="mb-2">
      <div><span className="text-emerald-400">iex&gt;</span> {entry.command}</div>
      {entry.lines?.map((l, i) => <div key={i} className={ok ? "text-zinc-300" : "text-red-400"}>{l}</div>)}
      <div className="text-zinc-500">
        <span className={ok ? "text-emerald-400" : "text-red-400"}>{entry.status}</span> in {entry.duration_ms}ms
      </div>
      {entry.result != null && <pre className="mt-1 whitespace-pre-wrap text-zinc-400">{JSON.stringify(entry.result, null, 2)}</pre>}
    </div>
  );
}

// ---- Checkpoint ----
export function Checkpoint({ label, className }) {
  return (
    <div className={cn("flex items-center gap-2 py-1 text-xs text-muted-foreground", className)} role="separator">
      <Flag className="size-3.5" /><span>{label}</span><div className="h-px flex-1 bg-border" />
    </div>
  );
}

// ---- Plan ----
export function Plan({ items, onRemove, onRun, className }) {
  return (
    <div className={cn("rounded-lg border bg-card", className)}>
      <div className="flex items-center justify-between border-b px-3 py-2">
        <span className="flex items-center gap-1.5 text-sm font-semibold"><ListChecks className="size-4" /> Plan</span>
        <span className="text-xs text-muted-foreground">{items.length} planned</span>
      </div>
      <ul className="grid gap-1 p-2 text-xs">
        {items.length === 0 && <li className="p-2 text-muted-foreground">Plan an action run below.</li>}
        {items.map((it) => (
          <li key={it.id} className="flex items-center gap-2 rounded px-2 py-1 hover:bg-accent">
            <code className="min-w-0 flex-1 truncate" title={it.command}>{it.command}</code>
            <button type="button" className="rounded border px-1.5 py-0.5 hover:bg-background" onClick={() => onRun(it)}>Queue</button>
            <button type="button" aria-label="remove" onClick={() => onRemove(it)}><X className="size-3.5" /></button>
          </li>
        ))}
      </ul>
    </div>
  );
}

// ---- Queue ----
export function Queue({ items, running, onRun, onClear, className }) {
  return (
    <div className={cn("rounded-lg border bg-card", className)}>
      <div className="flex items-center justify-between border-b px-3 py-2">
        <span className="flex items-center gap-1.5 text-sm font-semibold"><ListOrdered className="size-4" /> Queue</span>
        <span className="flex gap-2">
          <button type="button" disabled={running || items.every((i) => i.state !== "pending")} onClick={onRun} className="rounded border px-2 py-0.5 text-xs hover:bg-accent disabled:opacity-50">Run all</button>
          <button type="button" disabled={running} onClick={onClear} className="rounded border px-2 py-0.5 text-xs hover:bg-accent disabled:opacity-50">Clear</button>
        </span>
      </div>
      <ul className="grid gap-1 p-2 text-xs">
        {items.length === 0 && <li className="p-2 text-muted-foreground">Queue is empty.</li>}
        {items.map((it) => (
          <li key={it.id} className="flex items-center gap-2 rounded px-2 py-1">
            <span className={cn("size-2 rounded-full", { pending: "bg-muted-foreground", running: "animate-pulse bg-amber-500", ok: "bg-emerald-500", error: "bg-red-500" }[it.state])} />
            <code className="min-w-0 flex-1 truncate" title={it.command}>{it.command}</code>
            <span className="text-muted-foreground">{it.state}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
