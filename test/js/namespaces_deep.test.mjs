import test from "node:test";
import assert from "node:assert/strict";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";

// State-based (Chicago) tests of the createClient namespaces themselves:
// actions[id] / resources[resource][action] lookup laws, unknown-id behavior,
// freeze state of the namespace surfaces, and exact descriptor surfacing.
// Transport selection, receipts, and refusal paths are covered by
// runtime.test.mjs and are not retested here.

function contract(actions, overrides = {}) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: { profile: {}, actions },
    ...overrides,
  };
}

function action(overrides = {}) {
  return {
    id: "todos:Todo:create",
    // v26.9.16 delegation: semanticId/authorityBoundary/doAuthority/receiptRequired
    // are delegated facts — explicit null when not delegated.
    semanticId: null,
    authorityBoundary: null,
    doAuthority: null,
    receiptRequired: null,
    resource: "Todo",
    action: "create",
    profile: {},
    ...overrides,
  };
}

const stubTransports = {
  http: { async invoke() { return { success: true }; } },
  phoenix_channel: { async invoke() { return { success: true }; } },
};

function multiActionContract() {
  return contract([
    action({ id: "todos:Todo:create", resource: "Todo", action: "create" }),
    action({ id: "todos:Todo:list", resource: "Todo", action: "list" }),
    action({ id: "admin:Todo:create", resource: "AdminTodo", action: "create" }),
    action({ id: "admin:Todo:destroy", resource: "AdminTodo", action: "destroy", profile: { transport: "phoenix_channel" } }),
  ]);
}

test("actions[id], resources[resource][action], and get(id) resolve to the identical descriptor object", () => {
  const client = createClient({ contract: multiActionContract(), transports: stubTransports });

  const expectations = [
    ["todos:Todo:create", "Todo", "create"],
    ["todos:Todo:list", "Todo", "list"],
    ["admin:Todo:create", "AdminTodo", "create"],
    ["admin:Todo:destroy", "AdminTodo", "destroy"],
  ];

  for (const [id, resource, actionName] of expectations) {
    const byId = client.actions[id];
    const byResource = client.resources[resource][actionName];
    assert.ok(byId, `actions[${id}] must resolve`);
    assert.ok(byResource, `resources[${resource}][${actionName}] must resolve`);
    assert.equal(byId, byResource, "both lookup paths must return the same object reference");
    assert.equal(client.get(id), byId, "get(id) must return the same object reference");
  }
});

test("unknown ids resolve to undefined through both namespaces without throwing", () => {
  const client = createClient({ contract: multiActionContract(), transports: stubTransports });

  let lookups;
  assert.doesNotThrow(() => {
    lookups = {
      unknownAction: client.actions["todos:Todo:destroy"],
      emptyId: client.actions[""],
      symbolId: client.actions[Symbol("nope")],
      unknownResource: client.resources["NoSuchResource"],
      knownResourceUnknownAction: client.resources.Too, // typo of a resource name
      knownResourceUnknownActionName: client.resources.Todo.destroy,
      unknownResourceRecordAction: client.resources["NoSuchResource"]?.create,
    };
  });

  assert.equal(lookups.unknownAction, undefined);
  assert.equal(lookups.emptyId, undefined);
  assert.equal(lookups.symbolId, undefined);
  assert.equal(lookups.unknownResource, undefined);
  assert.equal(lookups.knownResourceUnknownAction, undefined);
  assert.equal(lookups.knownResourceUnknownActionName, undefined);
  assert.equal(lookups.unknownResourceRecordAction, undefined);
  assert.equal(client.get("todos:Todo:destroy"), null, "get() documents unknown ids as null, never a throw");
});

test("namespace surfaces are frozen: descriptor, profile, refusals, per-resource records, and the client itself", () => {
  const client = createClient({ contract: multiActionContract(), transports: stubTransports });

  assert.equal(Object.isFrozen(client), true);
  assert.equal(Object.isFrozen(client.actions["todos:Todo:create"]), true);
  assert.equal(Object.isFrozen(client.resources.Todo), true);
  assert.equal(Object.isFrozen(client.resources.AdminTodo), true);

  const descriptor = client.actions["admin:Todo:destroy"];
  assert.equal(Object.isFrozen(descriptor), true);
  assert.equal(Object.isFrozen(descriptor.profile), true);
  assert.equal(Object.isFrozen(descriptor.possibleRefusals), true);
});

test("mutation attempts against frozen namespace surfaces throw and leave the contract intact", () => {
  const client = createClient({ contract: multiActionContract(), transports: stubTransports });

  const byId = client.actions["todos:Todo:create"];
  const byResource = client.resources.Todo.create;

  assert.throws(() => { byId.authorityBoundary = "OBSERVE"; }, TypeError);
  assert.throws(() => { byResource.doAuthority = false; }, TypeError);
  assert.throws(() => { delete byId.id; }, TypeError);
  assert.throws(() => { byId.injected = "fake"; }, TypeError);
  assert.throws(() => { byId.profile.transport = "http"; }, TypeError);
  assert.throws(() => { byId.possibleRefusals.push("FORGED_REFUSAL"); }, TypeError);
  assert.throws(() => { client.resources.Todo.destroy = byId; }, TypeError);
  assert.throws(() => { client.reconcile = () => {}; }, TypeError);

  // The contract survives every refused mutation identically on both paths.
  assert.equal(client.actions["todos:Todo:create"], byId);
  assert.equal(client.resources.Todo.create, byId);
  assert.equal(client.get("todos:Todo:create"), byId);
  assert.equal("injected" in byId, false);
  assert.deepEqual(byId.possibleRefusals, []);
  assert.deepEqual(byId.profile, {});
  assert.equal(client.resources.Todo.create.id, "todos:Todo:create");
});

test("authorityBoundary, transport, and offline classification surface exactly as provided", () => {
  const provided = {
    id: "zoe:CareDriver:dispatch",
    semanticId: "zoe:DispatchCareDriver",
    resource: "CareDriver",
    action: "dispatch",
    authorityBoundary: "CONSTRUCT",
    doAuthority: false,
    possibleRefusals: ["REFUSED_NO_AUTHORITY", "REFUSED_EVIDENCE_MISSING"],
    profile: {
      transport: "phoenix_channel",
      offline: { class: "queue_behind_receipt", reconcilable: true },
      maxRetries: 0,
    },
  };

  const client = createClient({ contract: contract([provided]), transports: stubTransports });

  const descriptor = client.actions["zoe:CareDriver:dispatch"];
  assert.equal(descriptor, client.resources.CareDriver.dispatch);

  assert.equal(descriptor.id, "zoe:CareDriver:dispatch");
  assert.equal(descriptor.semanticId, "zoe:DispatchCareDriver");
  assert.equal(descriptor.authorityBoundary, "CONSTRUCT");
  assert.equal(descriptor.doAuthority, false);
  assert.deepEqual(descriptor.possibleRefusals, ["REFUSED_NO_AUTHORITY", "REFUSED_EVIDENCE_MISSING"]);
  assert.deepEqual(descriptor.profile, {
    transport: "phoenix_channel",
    offline: { class: "queue_behind_receipt", reconcilable: true },
    maxRetries: 0,
  });

  // An explicitly projected transport is declared exactly as provided, not expanded.
  assert.deepEqual(descriptor.inspect().declared, ["phoenix_channel"]);
});

// v26.9.16 delegation: delegated facts (authorityBoundary, doAuthority, and
// the other IR-sourced fields) are never defaulted client-side. An omitted or
// null delegated fact surfaces as null; only non-delegated projection metadata
// (possibleRefusals, profile) keeps its schema defaults.
test("omitted delegated facts surface as null; non-delegated fields keep defaults", () => {
  const client = createClient({ contract: contract([action()]), transports: stubTransports });

  const descriptor = client.actions["todos:Todo:create"];
  assert.equal(descriptor.authorityBoundary, null);
  assert.equal(descriptor.doAuthority, null);
  assert.deepEqual(descriptor.possibleRefusals, []);
  assert.deepEqual(descriptor.profile, {});
});

// Copy law holds per top-level profile key and array (zod re-parses records
// and arrays into fresh values). Nested profile objects are shared references
// after the shallow spread — see the commit receipt for that admitted gap.
test("descriptor state is a copy: mutating the raw input contract after createClient does not leak in", () => {
  const rawAction = action({
    authorityBoundary: "SELECT",
    possibleRefusals: ["REFUSED_NO_AUTHORITY"],
    profile: { transport: "phoenix_channel", maxRetries: 0 },
  });
  const client = createClient({ contract: contract([rawAction]), transports: stubTransports });

  rawAction.authorityBoundary = "DO";
  rawAction.possibleRefusals.push("FORGED_REFUSAL");
  rawAction.profile.transport = "http";
  rawAction.profile.maxRetries = 99;

  const descriptor = client.actions["todos:Todo:create"];
  assert.equal(descriptor.authorityBoundary, "SELECT");
  assert.deepEqual(descriptor.possibleRefusals, ["REFUSED_NO_AUTHORITY"]);
  assert.equal(descriptor.profile.transport, "phoenix_channel");
  assert.equal(descriptor.profile.maxRetries, 0);
});
