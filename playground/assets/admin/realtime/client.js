// Realtime client: one Socket for the page, one channel per resource. SSR-safe: nothing runs at import.
import { Socket } from "phoenix";
import { bus } from "../bus.js";

const state = { socket: null, channels: new Map(), status: "idle", events: [], actor: "" };
const MAX_EVENTS = 100;

const setStatus = (s) => {
  state.status = s;
  bus.emit("realtime:status", s);
};

export const getStatus = () => state.status;
export const getEvents = () => state.events;

function join(mod) {
  const key = `${mod}|${state.actor}`;
  if (state.channels.has(mod)) {
    if (state.channels.get(mod).key === key) return;
    state.channels.get(mod).ch.leave();
  }
  const ch = state.socket.channel(`admin:${mod}`, { actor_id: state.actor });
  ch.on("changed", (payload) => {
    state.events = [{ ...payload, seq: Date.now() + Math.random() }, ...state.events].slice(0, MAX_EVENTS);
    bus.emit(`changed:${mod}`, payload);
    bus.emit("realtime:event", payload);
  });
  ch.join()
    .receive("ok", () => bus.emit("realtime:joined", mod))
    .receive("error", (e) => bus.emit("realtime:denied", { module: mod, reason: e?.reason }));
  state.channels.set(mod, { ch, key });
}

// Connect once (idempotent), join every given module topic; re-joins when the actor changes.
export function start(modules, actorId = "") {
  if (typeof window === "undefined") return;
  state.actor = actorId || "";
  if (!state.socket) {
    state.socket = new Socket("/admin/socket");
    state.socket.onOpen(() => setStatus("connected"));
    state.socket.onClose(() => setStatus("disconnected"));
    state.socket.onError(() => setStatus("disconnected"));
    setStatus("connecting");
    state.socket.connect();
  }
  modules.forEach(join);
}

export function stop() {
  state.channels.forEach(({ ch }) => ch.leave());
  state.channels.clear();
  state.socket?.disconnect();
  state.socket = null;
  setStatus("idle");
}
