// Port of AI Elements `Panel`.
import * as React from "react";
import { Panel as PanelPrimitive } from "@xyflow/react";
import { cn } from "../../lib/utils.js";

export const Panel = ({ className, ...props }) => (
  <PanelPrimitive className={cn("m-4 overflow-hidden rounded-md border bg-card p-1", className)} {...props} />
);
