import test from "node:test";
import assert from "node:assert/strict";

import {
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

// Boundary refusals of the shipped JavaScript modules that no other suite
// pins:
//
//   1. transportFacts shape law — a profile's delegated `transportFacts` (and
//      each per-transport entry) must be a plain object; arrays, strings and
//      numbers are typed pre-dispatch refusals (TRANSPORT_FACTS_MUST_BE_A_MAP),
//      never coerced into "undelegated" and never dispatched.
//   2. OBSERVE adapter input law — observeAccessibility refuses a bad target,
//      an unsupported browser, and malformed probes with TypeError, and grades
//      duplicate / invisible targets as AMBIGUOUS / BLOCKED evidence.
//
// State-based: every case drives the real public surface (createClient /
// inspect / invoke, observeAccessibility) and asserts on the returned or
// thrown state. The transport adapter is the injected seam the law defines;
// its call counter proves "never dispatched".

function contractWithFacts(transportFacts) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: [
        {
          id: "todos:Todo:create",
          semanticId: null,
          authorityBoundary: null,
          doAuthority: null,
          receiptRequired: null,
          resource: "Todo",
          action: "create",
          profile: { transportFacts },
        },
      ],
    },
  };
}

function countingAdapter() {
  const calls = { invoke: 0 };
  return {
    calls,
    adapter: {
      async invoke() {
        calls.invoke += 1;
        return { success: true, data: { id: "row_1" } };
      },
    },
  };
}

const factsMapRefusal = (label) => (error) =>
  error instanceof SurfaceRuntimeError &&
  error.code === "TRANSPORT_FACTS_MUST_BE_A_MAP" &&
  error.message === `${label} must be a plain object`;

for (const [name, facts] of [
  ["an array", [{ cost: "low" }]],
  ["a string", "cheap"],
  ["a number", 1],
]) {
  test(`transportFacts given as ${name} is a typed refusal on inspect and invoke, never a dispatch`, async () => {
    const http = countingAdapter();
    const client = createClient({
      contract: contractWithFacts(facts),
      transports: { http: http.adapter },
    });

    assert.throws(() => client.inspect("todos:Todo:create"), factsMapRefusal("transportFacts"));
    await assert.rejects(
      client.actions["todos:Todo:create"].invoke({ title: "x" }),
      factsMapRefusal("transportFacts"),
    );
    assert.equal(http.calls.invoke, 0);
  });
}

test("a non-object per-transport facts entry names the offending transport and is never dispatched", async () => {
  const http = countingAdapter();
  const channel = countingAdapter();
  const client = createClient({
    contract: contractWithFacts({ http: { cost: "low" }, phoenix_channel: ["low"] }),
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
  });

  assert.throws(
    () => client.inspect("todos:Todo:create"),
    factsMapRefusal("transportFacts.phoenix_channel"),
  );
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({ title: "x" }),
    factsMapRefusal("transportFacts.phoenix_channel"),
  );
  assert.equal(http.calls.invoke + channel.calls.invoke, 0);
});

// ---------------------------------------------------------------------------
// OBSERVE adapter (priv/static/ash_surface_playwright.mjs)
// ---------------------------------------------------------------------------

// The target and browser guards run before any launch, so they need no
// browser runtime: the module is imported directly and handed an injected
// Playwright module (the adapter's documented `options.playwright` seam).
const { observeAccessibility } = await import("../../priv/static/ash_surface_playwright.mjs");

test("observeAccessibility refuses an empty or non-string target before launching anything", async () => {
  const launches = { count: 0 };
  const playwright = {
    chromium: {
      async launch() {
        launches.count += 1;
        throw new Error("must not launch");
      },
    },
  };

  for (const target of ["", null, undefined, 42]) {
    await assert.rejects(observeAccessibility(target, { playwright }), {
      name: "TypeError",
      message: "target must be a non-empty URL string",
    });
  }
  assert.equal(launches.count, 0);
});

test("observeAccessibility refuses a browser the Playwright module does not provide", async () => {
  await assert.rejects(
    observeAccessibility("http://127.0.0.1/", { playwright: {}, browser: "chromium" }),
    { name: "TypeError", message: "unsupported Playwright browser: chromium" },
  );
  await assert.rejects(
    observeAccessibility("http://127.0.0.1/", {
      playwright: { webkit: { launch: "not a function" } },
      browser: "webkit",
    }),
    { name: "TypeError", message: "unsupported Playwright browser: webkit" },
  );
});

// Probe validation and standing grading need a real page. Same runtime gate as
// playwright_accessibility.test.mjs: readiness is a real headless launch.
let chromiumReady = false;
try {
  const pw = await import("playwright");
  const probe = await pw.chromium.launch({ headless: true });
  await probe.close();
  chromiumReady = true;
} catch {
  chromiumReady = false;
}
const runtimeSkip = { skip: chromiumReady ? false : "playwright + chromium observation runtime not installed" };

const page = (body) => `data:text/html;charset=utf-8,${encodeURIComponent(body)}`;

test("malformed probes are TypeErrors, and the browser is still released", runtimeSkip, async () => {
  const target = page("<main><button>Go</button></main>");
  const cases = [
    [null, "probe must be an object"],
    [{ id: "", role: "button", name: "Go" }, "probe.id must be a non-empty string"],
    [{ id: "go", role: "", name: "Go" }, "probe.role must be a non-empty WAI-ARIA role name"],
    [{ id: "go", role: "button", name: 7 }, "probe.name must be a string or RegExp accessible name"],
  ];

  for (const [probe, message] of cases) {
    await assert.rejects(observeAccessibility(target, { probes: [probe] }), { name: "TypeError", message });
  }
});

test("duplicate targets grade AMBIGUOUS and invisible targets grade BLOCKED — evidence, never a guess", runtimeSkip, async () => {
  const target = page(`
    <main>
      <button>Save</button>
      <button>Save</button>
      <button aria-label="Ghost" style="width:0;height:0;padding:0;border:0;overflow:hidden"></button>
    </main>`);

  const observation = await observeAccessibility(target, {
    probes: [
      { id: "save", role: "button", name: "Save" },
      { id: "ghost", role: "button", name: "Ghost" },
    ],
  });

  const [save, ghost] = observation.facts.accessibility.probes;
  assert.deepEqual({ count: save.count, standing: save.standing }, { count: 2, standing: "AMBIGUOUS" });
  assert.deepEqual(
    { count: ghost.count, visible: ghost.visible, standing: ghost.standing },
    { count: 1, visible: false, standing: "BLOCKED" },
  );
  assert.equal(observation.authorityBoundary, "OBSERVE");
  assert.notEqual(observation.standing, "ALIVE");
});
