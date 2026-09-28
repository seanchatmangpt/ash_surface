// Links core's runtime as node_modules/ash_surface so the package's bare
// `import ... from "ash_surface"` resolves to priv/static/ash_surface_runtime.mjs
// of the path-dep'd core (../../priv/static). Zod resolves from the repo-root
// node_modules by ordinary parent-directory lookup. Idempotent; no network.
import { existsSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const pkgRoot = resolve(here, "..");
const core = resolve(pkgRoot, "../../priv/static/ash_surface_runtime.mjs");
if (!existsSync(core)) throw new Error(`core runtime not found at ${core}`);

const dir = join(pkgRoot, "node_modules", "ash_surface");
rmSync(dir, { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
writeFileSync(
  join(dir, "package.json"),
  JSON.stringify({ name: "ash_surface", type: "module", exports: "./index.mjs" }),
);
symlinkSync(core, join(dir, "index.mjs"));
