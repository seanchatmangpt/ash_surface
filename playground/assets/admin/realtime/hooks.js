import { useEffect, useState } from "react";
import { bus } from "../bus.js";
import { api } from "../api.js";
import { start, getStatus, getEvents } from "./client.js";

// Client-only effect: starts the shared socket and joins all resources. No-op during SSR.
export function useRealtime(actorId) {
  const [status, setStatus] = useState(getStatus());
  const [events, setEvents] = useState(getEvents());
  useEffect(() => {
    let off = [bus.on("realtime:status", setStatus), bus.on("realtime:event", () => setEvents([...getEvents()]))];
    let dead = false;
    api.domains().then((d) => {
      if (dead) return;
      start(d.domains.flatMap((x) => x.resources.map((r) => r.module)), actorId);
    });
    return () => {
      dead = true;
      off.forEach((f) => f());
    };
  }, [actorId]);
  return { status, events };
}
