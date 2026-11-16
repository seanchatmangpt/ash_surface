// Port of AI Elements `Controls`.
import * as React from "react";
import { Controls as ControlsPrimitive } from "@xyflow/react";
import { cn } from "../../lib/utils.js";

export const Controls = ({ className, ...props }) => (
  <ControlsPrimitive
    className={cn("gap-px overflow-hidden rounded-md border bg-card p-1 shadow-none!", className)}
    {...props}
  />
);
