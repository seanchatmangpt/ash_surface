import * as React from "react";
import { CheckCircle2, Info, X, XCircle } from "lucide-react";
import { cn } from "../lib/utils.js";

// Hand-ported shadcn-style toast: provider + hook, auto-dismiss driven by an effect (SSR-safe).
const ToastCtx = React.createContext(null);
const noop = { toast: () => {}, dismiss: () => {} };
export const useToast = () => React.useContext(ToastCtx) ?? noop;

let seq = 0;

export function ToastProvider({ children, duration = 4000 }) {
  const [items, setItems] = React.useState([]);
  const dismiss = React.useCallback((id) => setItems((xs) => xs.filter((x) => x.id !== id)), []);
  const toast = React.useCallback((t) => {
    const item = { id: ++seq, variant: "default", ...(typeof t === "string" ? { title: t } : t) };
    setItems((xs) => [...xs.slice(-4), item]);
    return item.id;
  }, []);
  const value = React.useMemo(() => ({ toast, dismiss }), [toast, dismiss]);
  return (
    <ToastCtx.Provider value={value}>
      {children}
      <div role="region" aria-label="Notifications" className="pointer-events-none fixed bottom-4 right-4 z-[100] grid w-80 gap-2">
        {items.map((t) => <ToastItem key={t.id} item={t} duration={duration} onDismiss={dismiss} />)}
      </div>
    </ToastCtx.Provider>
  );
}

function ToastItem({ item, duration, onDismiss }) {
  React.useEffect(() => {
    const h = setTimeout(() => onDismiss(item.id), item.duration ?? duration);
    return () => clearTimeout(h);
  }, [item.id]);
  const Icon = item.variant === "destructive" ? XCircle : item.variant === "success" ? CheckCircle2 : Info;
  return (
    <div
      role={item.variant === "destructive" ? "alert" : "status"}
      className={cn(
        "pointer-events-auto flex items-start gap-3 rounded-md border bg-popover p-3 text-sm text-popover-foreground shadow-lg",
        item.variant === "destructive" && "border-destructive/60",
      )}
    >
      <Icon className={cn("mt-0.5 size-4 shrink-0", item.variant === "destructive" && "text-destructive", item.variant === "success" && "text-green-600")} />
      <div className="grid flex-1 gap-0.5">
        {item.title && <div className="font-medium">{item.title}</div>}
        {item.description && <div className="text-muted-foreground">{item.description}</div>}
      </div>
      <button type="button" aria-label="Dismiss" className="text-muted-foreground hover:text-foreground" onClick={() => onDismiss(item.id)}>
        <X className="size-4" />
      </button>
    </div>
  );
}
