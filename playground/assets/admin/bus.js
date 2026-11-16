// Tiny event bus shared by plugins and core views (works in SSR: no window access at import).
const handlers = new Map();
export const bus = {
  on(event, fn) {
    if (!handlers.has(event)) handlers.set(event, new Set());
    handlers.get(event).add(fn);
    return () => handlers.get(event)?.delete(fn);
  },
  emit(event, payload) {
    handlers.get(event)?.forEach((fn) => fn(payload));
  },
};
