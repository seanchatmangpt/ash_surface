// Port of AI Elements `Canvas`: ReactFlow preconfigured for workflow viewing.
import * as React from "react";
import { Background, ReactFlow } from "@xyflow/react";

export const Canvas = ({ children, ...props }) => (
  <ReactFlow
    deleteKeyCode={["Backspace", "Delete"]}
    fitView
    nodesDraggable
    panOnDrag={false}
    panOnScroll
    selectionOnDrag={true}
    zoomOnDoubleClick={false}
    {...props}
  >
    <Background bgColor="var(--sidebar, var(--muted))" />
    {children}
  </ReactFlow>
);
