// Browser-less check against a RUNNING server: markup + hydration bundle + zod module.
// usage: bun assets/test/live_check.mjs http://127.0.0.1:4100
const base = process.argv[2] ?? "http://127.0.0.1:4100";
const fail = (m) => { console.error("FAIL " + m); process.exit(1); };
const page = await (await fetch(base + "/")).text();
if (!page.includes('id="resource-list"')) fail("no SSR resource list");
if (!page.includes("Todo.create")) fail("no contract data in SSR markup");
if (!page.includes("export const SCHEMAS")) fail("emitted zod source missing in markup");
if (!page.includes('src="/assets/client.js"')) fail("no hydration script tag");
const client = await fetch(base + "/assets/client.js");
const ct = await client.text();
if (client.status !== 200 || !ct.includes("hydrateRoot") && !ct.includes("hydrat")) fail("client bundle");
const zod = await fetch(base + "/assets/zod.mjs");
if (zod.status !== 200) fail("zod.mjs status " + zod.status);
console.log("OK ssr markup + client.js(" + ct.length + "B) + zod.mjs");
