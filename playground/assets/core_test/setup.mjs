// Preload for `bun test --preload ./assets/core_test/setup.mjs assets/core_test`.
// A real HTTP server (Bun.serve) plays the /admin/api backend from fixture JSON and records every
// request it receives; happy-dom is registered with that server's origin so the components' real
// relative-URL `fetch` calls reach it. No fetch/module mocking.
import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { fixtures } from "./fixtures.mjs";

const NativeResponse = Response; // happy-dom replaces the global after register()
const requests = [];
const server = Bun.serve({
  port: 0,
  async fetch(req) {
    const url = new URL(req.url);
    const body = req.method === "POST" ? await req.json().catch(() => null) : null;
    requests.push({ method: req.method, path: url.pathname, query: Object.fromEntries(url.searchParams), body });
    const hit = fixtures.route(req.method, url, body);
    return new NativeResponse(JSON.stringify(hit.body), { status: hit.status ?? 200, headers: { "content-type": "application/json" } });
  },
});

globalThis.__fixtureRequests = requests;
globalThis.__fixtureServer = server;
GlobalRegistrator.register({ url: `http://localhost:${server.port}/admin`, width: 1280, height: 800 });
// happy-dom lacks these; cmdk/radix read them when open.
globalThis.ResizeObserver ??= class { observe() {} unobserve() {} disconnect() {} };
globalThis.Element.prototype.scrollIntoView ??= function () {};
globalThis.Element.prototype.hasPointerCapture ??= () => false;

import { afterEach } from "bun:test";
afterEach(async () => {
  const { cleanup } = await import("@testing-library/react");
  cleanup();
});
