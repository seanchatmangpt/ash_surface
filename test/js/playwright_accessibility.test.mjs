import test from "node:test";
import assert from "node:assert/strict";

import { observationProjectionSchema } from "../../priv/static/ash_surface_runtime.mjs";

// Observation-runtime gate (same class as the FLOCK_TEST runtime gate): the
// Playwright/Chromium observation runtime is optional in a fresh clone —
// CI's javascript job installs playwright@1.63.0 + chromium and runs these
// for real; the zero-config batteries (npm install + npm test, no browsers)
// must still pass, so the browser-launching tests type-refuse to SKIP when
// the runtime is absent instead of failing on a static import. The shipped
// module is imported dynamically for the same reason.
let observeAccessibility = null;
let chromiumReady = false;
try {
  const pw = await import("playwright");
  const executable = pw.chromium?.executablePath?.();
  chromiumReady = typeof executable === "string" && executable.length > 0;
  if (chromiumReady) {
    ({ observeAccessibility } = await import("../../priv/static/ash_surface_playwright.mjs"));
  }
} catch {
  chromiumReady = false;
}
const runtimeSkip = { skip: chromiumReady ? false : "playwright + chromium observation runtime not installed" };

test("real Chromium produces an OBSERVE-only WAI-ARIA surface receipt", runtimeSkip, async () => {
  const html = `<!doctype html>
    <html>
      <head><title>Accessibility Fixture</title></head>
      <body>
        <main>
          <h1>Marketplace</h1>
          <a href="http://127.0.0.1/events/marketplace">Register</a>
          <button type="button" aria-expanded="false">Details</button>
        </main>
      </body>
    </html>`;

  const target = `data:text/html;charset=utf-8,${encodeURIComponent(html)}`;

  const observation = await observeAccessibility(target, {
    probes: [
      { id: "marketplace-register", role: "link", name: "Register" },
      { id: "marketplace-details", role: "button", name: "Details" },
    ],
  });

  const admitted = observationProjectionSchema.parse(observation);

  assert.equal(admitted.authorityBoundary, "OBSERVE");
  assert.equal(admitted.projectionPurpose, "accessibility_surface_observation");
  assert.equal(admitted.facts.title, "Accessibility Fixture");
  assert.match(admitted.facts.accessibility.snapshot, /link "Register"/);
  assert.match(admitted.facts.accessibility.snapshot, /button "Details"/);

  const [register, details] = admitted.facts.accessibility.probes;
  assert.deepEqual(
    { role: register.role, count: register.count, visible: register.visible, standing: register.standing },
    { role: "link", count: 1, visible: true, standing: "ALIVE" },
  );
  assert.equal(register.href, "http://127.0.0.1/events/marketplace");
  assert.equal(details.standing, "ALIVE");
});

test("missing accessible target is evidence, not a CSS/XPath fallback", runtimeSkip, async () => {
  const target = `data:text/html;charset=utf-8,${encodeURIComponent("<main><h1>People</h1></main>")}`;

  const observation = await observeAccessibility(target, {
    probes: [{ id: "people-search", role: "searchbox", name: "Search people" }],
  });

  assert.equal(observation.authorityBoundary, "OBSERVE");
  assert.equal(observation.standing, "PARTIAL_ALIVE");
  assert.equal(observation.facts.accessibility.probes[0].standing, "MISSING");
});
