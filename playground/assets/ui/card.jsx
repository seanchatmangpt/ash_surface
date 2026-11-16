import * as React from "react";
import { cn } from "../lib/utils.js";

const mk = (tag, base, name) => {
  const C = React.forwardRef(({ className, ...p }, ref) =>
    React.createElement(tag, { ref, className: cn(base, className), ...p }),
  );
  C.displayName = name;
  return C;
};

export const Card = mk("div", "rounded-xl border bg-card text-card-foreground shadow-sm", "Card");
export const CardHeader = mk("div", "flex flex-col gap-1.5 p-6", "CardHeader");
export const CardTitle = mk("h3", "font-semibold leading-none tracking-tight", "CardTitle");
export const CardDescription = mk("p", "text-sm text-muted-foreground", "CardDescription");
export const CardContent = mk("div", "p-6 pt-0", "CardContent");
export const CardFooter = mk("div", "flex items-center p-6 pt-0", "CardFooter");
