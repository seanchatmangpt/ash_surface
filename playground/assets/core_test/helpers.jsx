import React from "react";
import { render } from "@testing-library/react";
import { AdminProvider } from "../admin/context.jsx";
import { ToastProvider } from "../ui/toast.jsx";

export const requests = () => globalThis.__fixtureRequests;
export const clearRequests = () => (globalThis.__fixtureRequests.length = 0);
export const lastRequest = (pred) => [...requests()].reverse().find(pred);

// Polls an observable until it holds (deadline-bound; never a fixed sleep).
export async function until(fn, { timeout = 3000, step = 10 } = {}) {
  const end = performance.now() + timeout;
  let last;
  while (performance.now() < end) {
    try { const v = fn(); if (v) return v; } catch (e) { last = e; }
    await new Promise((r) => setTimeout(r, step));
  }
  throw last ?? new Error("until: condition not met within deadline");
}

export function renderAdmin(ui, { navigate = () => {} } = {}) {
  return render(
    <AdminProvider navigate={navigate} path="/">
      <ToastProvider>{ui}</ToastProvider>
    </AdminProvider>,
  );
}
