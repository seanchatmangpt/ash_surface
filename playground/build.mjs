// Bundles the browser assets (hydration client + real zod as an ESM module).
import { mkdirSync } from "node:fs";

mkdirSync("priv/static/assets", { recursive: true });

const common = { outdir: "priv/static/assets", target: "browser", format: "esm" };

const client = await Bun.build({
  ...common,
  entrypoints: ["assets/client.jsx"],
  naming: "client.js",
  define: { "process.env.NODE_ENV": '"production"' },
});
const zod = await Bun.build({
  ...common,
  entrypoints: ["assets/zod_entry.mjs"],
  naming: "zod.mjs",
});

for (const r of [client, zod]) {
  if (!r.success) {
    for (const l of r.logs) console.error(String(l));
    process.exit(1);
  }
}
console.log("built priv/static/assets/{client.js,zod.mjs}");
