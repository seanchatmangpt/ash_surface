// Port of AI Elements `Edge`: Temporary (dashed, not yet run) and Animated (packet travels the path).
import * as React from "react";
import { BaseEdge, getBezierPath, getSimpleBezierPath, Position } from "@xyflow/react";

const Temporary = ({ id, sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, markerEnd, style }) => {
  const [edgePath] = getSimpleBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition });
  return (
    <BaseEdge
      id={id}
      markerEnd={markerEnd}
      path={edgePath}
      style={{ stroke: "var(--ring)", strokeDasharray: "5, 5", strokeWidth: 1, ...style }}
    />
  );
};

const Animated = ({ id, sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, markerEnd, style }) => {
  const [edgePath] = getBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition });
  return (
    <>
      <BaseEdge id={id} markerEnd={markerEnd} path={edgePath} style={{ stroke: "var(--primary)", strokeWidth: 2, ...style }} />
      <circle fill="var(--primary)" r="4">
        <animateMotion dur="1s" path={edgePath} repeatCount="indefinite" />
      </circle>
    </>
  );
};

const Done = ({ id, sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, markerEnd, style }) => {
  const [edgePath] = getBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition });
  return <BaseEdge id={id} markerEnd={markerEnd} path={edgePath} style={{ stroke: "#16a34a", strokeWidth: 2, ...style }} />;
};

const Plain = ({ id, sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, markerEnd, style }) => {
  const [edgePath] = getBezierPath({ sourceX, sourceY, sourcePosition, targetX, targetY, targetPosition });
  return <BaseEdge id={id} markerEnd={markerEnd} path={edgePath} style={{ stroke: "var(--muted-foreground)", strokeWidth: 1.5, ...style }} />;
};

export const Edge = { Temporary, Animated, Done, Plain };
export const edgeTypes = { temporary: Temporary, animated: Animated, done: Done, plain: Plain };
