import test from "node:test";
import assert from "node:assert/strict";
import { SURFACE_RUNTIME_VERSION } from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Version law, JS side: the runtime's exported SURFACE_RUNTIME_VERSION must
 * equal the golden pinned here, which is also the @version in mix.exs and the
 * AshSurface.schema_version/0 of this checkout. A failure means the runtime
 * drifted from the surface contract it claims to project.
 */
const GOLDEN_VERSION = "26.9.16";

test("SURFACE_RUNTIME_VERSION export equals the pinned golden version", () => {
  assert.equal(SURFACE_RUNTIME_VERSION, GOLDEN_VERSION);
});

test("SURFACE_RUNTIME_VERSION is a non-empty semver-shaped string", () => {
  assert.match(SURFACE_RUNTIME_VERSION, /^\d+\.\d+\.\d+$/);
});
