import * as React from "react";
import { cn } from "../lib/utils.js";

const mk = (tag, base, name) => {
  const C = React.forwardRef(({ className, ...p }, ref) =>
    React.createElement(tag, { ref, className: cn(base, className), ...p }),
  );
  C.displayName = name;
  return C;
};

export const Table = React.forwardRef(({ className, ...props }, ref) => (
  <div className="relative w-full overflow-auto">
    <table ref={ref} className={cn("w-full caption-bottom text-sm", className)} {...props} />
  </div>
));
Table.displayName = "Table";
export const TableHeader = mk("thead", "[&_tr]:border-b", "TableHeader");
export const TableBody = mk("tbody", "[&_tr:last-child]:border-0", "TableBody");
export const TableRow = mk("tr", "border-b transition-colors hover:bg-muted/50 data-[state=selected]:bg-muted", "TableRow");
export const TableHead = mk("th", "h-10 px-3 text-left align-middle font-medium text-muted-foreground", "TableHead");
export const TableCell = mk("td", "p-3 align-middle", "TableCell");
export const TableCaption = mk("caption", "mt-4 text-sm text-muted-foreground", "TableCaption");
