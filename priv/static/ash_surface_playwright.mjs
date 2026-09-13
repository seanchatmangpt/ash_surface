import { createHash } from "node:crypto";

const WAI_ARIA_SPEC = "https://www.w3.org/TR/wai-aria/";

/**
 * @typedef {Object} AccessibilityProbe
 * @property {string} id Stable semantic probe identity.
 * @property {string} role WAI-ARIA role name, e.g. `link`, `button`, `searchbox`.
 * @property {string|RegExp} name Accessible name matched through Playwright getByRole.
 * @property {boolean} [exact=true]
 */

/**
 * Observe one web surface through Playwright's accessibility semantics.
 *
 * This adapter is OBSERVE-only. It intentionally exposes no click/fill/submit
 * primitive. Consequence-bearing browser work must be constructed separately
 * and admitted by the application's authority/receipt boundary.
 *
 * Playwright is loaded lazily so AshSurface core does not make browser tooling
 * a mandatory runtime dependency. Consumers may inject an already-installed
 * Playwright module through `options.playwright`.
 *
 * @param {string} target URL to observe.
 * @param {Object} [options]
 * @param {Object} [options.playwright] Playwright module; lazily imported when omitted.
 * @param {"chromium"|"firefox"|"webkit"} [options.browser="chromium"]
 * @param {boolean} [options.headless=true]
 * @param {number} [options.timeout=30000]
 * @param {AccessibilityProbe[]} [options.probes=[]]
 * @returns {Promise<Object>} AshSurface ObservationProjection-compatible object.
 */
export async function observeAccessibility(target, options = {}) {
  if (typeof target !== "string" || target.length === 0) {
    throw new TypeError("target must be a non-empty URL string");
  }

  const playwright = options.playwright ?? (await import("playwright"));
  const browserName = options.browser ?? "chromium";
  const browserType = playwright[browserName];

  if (!browserType || typeof browserType.launch !== "function") {
    throw new TypeError(`unsupported Playwright browser: ${browserName}`);
  }

  const probes = options.probes ?? [];
  const browser = await browserType.launch({ headless: options.headless ?? true });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    const response = await page.goto(target, {
      waitUntil: "domcontentloaded",
      timeout: options.timeout ?? 30_000,
    });

    const ariaSnapshot = await page.locator("body").ariaSnapshot();
    const probeResults = [];

    for (const probe of probes) {
      assertProbe(probe);

      const locator = page.getByRole(probe.role, {
        name: probe.name,
        exact: probe.exact ?? true,
      });
      const count = await locator.count();
      const first = count > 0 ? locator.first() : null;
      const visible = first ? await first.isVisible() : false;

      probeResults.push(
        Object.freeze({
          id: probe.id,
          role: probe.role,
          accessibleName: String(probe.name),
          count,
          visible,
          href: first ? await first.getAttribute("href") : null,
          ariaDisabled: first ? await first.getAttribute("aria-disabled") : null,
          standing: probeStanding(count, visible),
        }),
      );
    }

    const facts = {
      title: await page.title(),
      httpStatus: response?.status() ?? null,
      accessibility: {
        vocabulary: WAI_ARIA_SPEC,
        snapshot: ariaSnapshot,
        probes: probeResults,
      },
    };

    const exactSubject = page.url();
    const stateDigest = createHash("sha256")
      .update(`${exactSubject}:${JSON.stringify(facts)}`)
      .digest("hex");

    return Object.freeze({
      observationId: `obs_${stateDigest.slice(0, 16)}`,
      exactSubject,
      observedAt: new Date().toISOString(),
      stateDigest,
      facts,
      evidenceRefs: [],
      standing: probeResults.some((probe) => probe.standing !== "ALIVE")
        ? "PARTIAL_ALIVE"
        : "ALIVE",
      projectionPurpose: "accessibility_surface_observation",
      authorityBoundary: "OBSERVE",
    });
  } finally {
    await context.close();
    await browser.close();
  }
}

function assertProbe(probe) {
  if (!probe || typeof probe !== "object") throw new TypeError("probe must be an object");
  if (typeof probe.id !== "string" || probe.id.length === 0) {
    throw new TypeError("probe.id must be a non-empty string");
  }
  if (typeof probe.role !== "string" || probe.role.length === 0) {
    throw new TypeError("probe.role must be a non-empty WAI-ARIA role name");
  }
  if (!(typeof probe.name === "string" || probe.name instanceof RegExp)) {
    throw new TypeError("probe.name must be a string or RegExp accessible name");
  }
}

function probeStanding(count, visible) {
  if (count === 0) return "MISSING";
  if (count > 1) return "AMBIGUOUS";
  return visible ? "ALIVE" : "BLOCKED";
}
