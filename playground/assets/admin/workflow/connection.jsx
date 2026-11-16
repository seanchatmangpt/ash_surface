// Port of AI Elements `Connection` (custom connection line while dragging a handle).
import * as React from "react";

const HALF = 0.5;

export const Connection = ({ fromX, fromY, toX, toY }) => (
  <g>
    <path
      className="animated"
      d={`M${fromX},${fromY} C ${fromX + (toX - fromX) * HALF},${fromY} ${fromX + (toX - fromX) * HALF},${toY} ${toX},${toY}`}
      fill="none"
      stroke="var(--ring)"
      strokeWidth={1}
    />
    <circle cx={toX} cy={toY} fill="#fff" r={3} stroke="var(--ring)" strokeWidth={1} />
  </g>
);
