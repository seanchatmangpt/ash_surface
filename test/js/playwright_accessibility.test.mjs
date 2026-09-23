import test from "node:test";
import assert from "node:assert/strict";

import { observationProjectionSchema } from "../../priv/static/ash_surface_runtime.mjs";
import { observeAccessibility } from "../../priv/static/ash_surface_playwright.mjs";

test("real Chromium produces an OBSERVE-only WAI-ARIA surface receipt", async () => {
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

test("missing accessible target is evidence, not a CSS/XPath fallback", async () => {
  const target = `data:text/html;charset=utf-8,${encodeURIComponent("<main><h1>People</h1></main>")}`;

  const observation = await observeAccessibility(target, {
    probes: [{ id: "people-search", role: "searchbox", name: "Search people" }],
  });

  assert.equal(observation.authorityBoundary, "OBSERVE");
  assert.equal(observation.standing, "PARTIAL_ALIVE");
  assert.equal(observation.facts.accessibility.probes[0].standing, "MISSING");
});
