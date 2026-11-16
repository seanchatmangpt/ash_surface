import * as React from "react";
import { Node, NodeContent, NodeDescription, NodeFooter, NodeHeader, NodeTitle } from "./node.jsx";
import { Toolbar } from "./toolbar.jsx";
import { Badge } from "../../ui/badge.jsx";
import { cn } from "../../lib/utils.js";

export const STATUS_STYLE = {
  pending: "border-border",
  running: "border-blue-500 ring-2 ring-blue-500/40",
  undoing: "border-amber-500 ring-2 ring-amber-500/40",
  ok: "border-green-600 bg-green-50 dark:bg-green-950/30",
  error: "border-red-600 bg-red-50 dark:bg-red-950/30",
  undone: "border-amber-500 bg-amber-50 dark:bg-amber-950/30",
};

const BADGE = { ok: "secondary", error: "destructive", running: "default", undoing: "default", undone: "outline", pending: "outline" };

export function StepNode({ data, selected }) {
  const status = data.status ?? "pending";
  return (
    <>
      <Toolbar isVisible={selected}>
        <div className="max-w-xs text-xs">
          <div className="font-semibold">{data.kind}</div>
          {(data.arguments ?? []).map((a) => (
            <div key={a.name} className="text-muted-foreground">
              {a.name} &larr; {a.from}
              {a.ref ? `:${a.ref}` : ""}
            </div>
          ))}
        </div>
      </Toolbar>
      <Node handles={{ target: true, source: !data.isReturn }} className={cn("w-72", STATUS_STYLE[status])} data-testid={`wf-node-${data.label}`} data-status={status}>
        <NodeHeader>
          <NodeTitle className="flex items-center justify-between gap-2 text-sm">
            <span>{data.label}</span>
            <Badge variant={BADGE[status]} data-testid="wf-status">{status}</Badge>
          </NodeTitle>
          <NodeDescription>{data.kind}</NodeDescription>
        </NodeHeader>
        <NodeContent className="text-xs text-muted-foreground">
          {data.description || (data.undoable ? "Compensating step (has undo)" : "Reactor step")}
          {data.error && <div className="mt-1 text-red-600">{data.error}</div>}
        </NodeContent>
        <NodeFooter className="text-xs text-muted-foreground">
          {data.undoable ? "undo: yes" : "undo: no"}
          {data.isReturn ? " · return" : ""}
        </NodeFooter>
      </Node>
    </>
  );
}

export function InputNode({ data }) {
  return (
    <Node handles={{ source: true }} className="w-40 border-dashed">
      <NodeHeader>
        <NodeTitle className="text-sm">{data.label}</NodeTitle>
        <NodeDescription>input</NodeDescription>
      </NodeHeader>
    </Node>
  );
}

export const nodeTypes = { step: StepNode, input: InputNode };
