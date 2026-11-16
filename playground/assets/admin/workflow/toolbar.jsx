// Port of AI Elements `Toolbar` (xyflow NodeToolbar below the node).
import * as React from "react";
import { NodeToolbar, Position } from "@xyflow/react";
import { cn } from "../../lib/utils.js";

export const Toolbar = ({ className, ...props }) => (
  <NodeToolbar className={cn("flex items-center gap-1 rounded-sm border bg-background p-1.5", className)} position={Position.Bottom} {...props} />
);
