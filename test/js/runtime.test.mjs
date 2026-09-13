import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  SurfaceRuntimeError,
  observationProjectionSchema,
  planningEpisodeSchema,
  eventProjectionSchema,
} from "../../priv/static/ash_surface_runtime.mjs";

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
    resource: "Todo",
    action: "create",
    profile: {},
    ...overrides,
  };
}

test("refuses a contract with an unsupported surface schema major", () => {
  assert.throws(
    () => createClient({ contract: contract([], { surfaceSchemaVersion: "9.0.0" }), transports: {} }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNSUPPORTED_SURFACE_VERSION",
  );
});

test("refuses a contract that fails Zod validation", () => {
  assert.throws(
    () => createClient({ contract: { not: "a contract" }, transports: {} }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "INVALID_SURFACE_CONTRACT",
  );
});

test("falls back to an available transport when the preferred one is unavailable", async () => {
  let httpCalls = 0;
  const transports = {
    http: {
      async invoke() {
        httpCalls += 1;
        return { success: true, data: { id: "1" } };
      },
    },
  };

  const client = createClient({
    contract: contract([action()]),
    transports,
    prefer: "phoenix_channel",
  });

  const inspected = client.inspect("todos:Todo:create");
  assert.equal(inspected.decision.selected, "http");
  assert.equal(inspected.decision.reason, "preferred_unavailable");
  assert.deepEqual(inspected.declared, ["http", "phoenix_channel"]);
  assert.deepEqual(inspected.available, ["http"]);

  const { result, receipt } = await client.get("todos:Todo:create").invokeWithReceipt({ title: "x" });
  assert.equal(httpCalls, 1);
  assert.equal(result.success, true);
  assert.equal(receipt.selected, "http");
  assert.equal(receipt.dispatchState, "completed");
});

test("uses the preferred transport when it is available", async () => {
  let httpCalls = 0;
  let channelCalls = 0;

  const transports = {
    http: {
      async invoke() {
        httpCalls += 1;
        return { success: true };
      },
    },
    phoenix_channel: {
      async invoke() {
        channelCalls += 1;
        return { success: true, data: { id: "2" } };
      },
    },
  };

  const client = createClient({
    contract: contract([action()]),
    transports,
    prefer: "phoenix_channel",
  });

  const { result, receipt } = await client.resources.Todo.create.invokeWithReceipt({ title: "x" });

  assert.equal(httpCalls, 0);
  assert.equal(channelCalls, 1);
  assert.equal(result.data.id, "2");
  assert.equal(receipt.selected, "phoenix_channel");
  assert.equal(receipt.dispatchState, "completed");
});

test("a transport failure after dispatch is reported unknown, never retried", async () => {
  let httpCalls = 0;

  const transports = {
    http: {
      async invoke() {
        httpCalls += 1;
        return { success: true };
      },
    },
    phoenix_channel: {
      async invoke() {
        throw new Error("channel disconnected mid-flight");
      },
    },
  };

  const client = createClient({
    contract: contract([action()]),
    transports,
    prefer: "phoenix_channel",
  });

  await assert.rejects(
    () => client.get("todos:Todo:create").invoke({ title: "x" }),
    (error) => {
      assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
      assert.equal(error.receipt.dispatchState, "unknown_after_dispatch");
      assert.equal(error.receipt.fallback, "pre_dispatch_only");
      return true;
    },
  );

  assert.equal(httpCalls, 0);
});

test("resources preserve equal action names without collapsing identity across resources", () => {
  const actions = [
    action({ id: "admin:Todo:create", resource: "AdminTodo" }),
    action({ id: "public:Todo:create", resource: "PublicTodo" }),
  ];

  const client = createClient({
    contract: contract(actions),
    transports: { http: { async invoke() { return { success: true }; } } },
  });

  assert.ok(client.resources.AdminTodo.create);
  assert.ok(client.resources.PublicTodo.create);
  assert.notEqual(client.resources.AdminTodo.create.id, client.resources.PublicTodo.create.id);
});

test("refuses invocation of an action with no admitted transport implementation", async () => {
  const client = createClient({ contract: contract([action()]), transports: {}, prefer: "http" });

  await assert.rejects(
    () => client.get("todos:Todo:create").invoke({}),
    (error) => error.code === "UNSUPPORTED_TRANSPORT" && error.receipt.dispatchState === "not_dispatched",
  );
});

test("refuses a duplicate action id within one contract", () => {
  const actions = [action(), action()];

  assert.throws(
    () => createClient({ contract: contract(actions), transports: {} }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "DUPLICATE_ACTION_ID",
  );
});

test("observationProjectionSchema validates read-only world state snapshot", () => {
  const obs = {
    observationId: "obs_abc123",
    exactSubject: "zoe:KingdomNeed#need_42",
    observedAt: new Date().toISOString(),
    stateDigest: "9f83a0bc8192a0129f83a0bc8192a0129f83a0bc8192a0129f83a0bc8192a012",
    facts: { open_opportunities: 3, standing: "ALIVE" },
    evidenceRefs: ["ev_123"],
    standing: "ALIVE",
    projectionPurpose: "consumer_state_observation",
    authorityBoundary: "OBSERVE",
  };

  const parsed = observationProjectionSchema.parse(obs);
  assert.equal(parsed.authorityBoundary, "OBSERVE");
  assert.equal(parsed.exactSubject, "zoe:KingdomNeed#need_42");
  assert.equal(parsed.facts.open_opportunities, 3);
});

test("planningEpisodeSchema validates FOND/HDDL candidates with non-DO authority ceiling", () => {
  const episode = {
    episodeId: "ep_789xyz",
    worldStateRef: "obs_abc123",
    plannerIdentity: "ash_pplan:solver",
    policyIdentity: "zoe:policy:strong_cyclic",
    policyStanding: "VALID_STRONG_CYCLIC",
    candidateActions: [{ action: "select_option", candidate: "care_driver" }],
    authorityCeiling: "SELECT",
  };

  const parsed = planningEpisodeSchema.parse(episode);
  assert.equal(parsed.authorityCeiling, "SELECT");
  assert.equal(parsed.policyStanding, "VALID_STRONG_CYCLIC");

  assert.throws(() => {
    planningEpisodeSchema.parse({
      ...episode,
      authorityCeiling: "DO", // Refused: Planner != DO
    });
  });
});

test("eventProjectionSchema validates realtime server-to-client observation events", () => {
  const event = {
    eventId: "ev_001",
    sequence: 42,
    subjectRef: "zoe:KingdomNeed#need_42",
    eventType: "state_changed",
    stateDigest: "digest123",
    occurredAt: new Date().toISOString(),
    authorityBoundary: "OBSERVE",
  };

  const parsed = eventProjectionSchema.parse(event);
  assert.equal(parsed.sequence, 42);
  assert.equal(parsed.authorityBoundary, "OBSERVE");
});

test("reconciliation resolves unknown command without re-actuation", async () => {
  const reconciledCommands = [];
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      async reconcile(commandId) {
        reconciledCommands.push(commandId);
        return {
          commandId,
          status: "COMPLETED",
          receipt: { hash: "receipt_hash_123" },
        };
      },
    },
  };

  const client = createClient({
    contract: contract([action()]),
    transports,
    prefer: "http",
  });

  const res = await client.reconcile("cmd_offline_001");
  assert.equal(res.status, "COMPLETED");
  assert.deepEqual(reconciledCommands, ["cmd_offline_001"]);
});

test("composed MX receipt separates transport disposition from domain consequences", async () => {
  const transports = {
    http: {
      async invoke() {
        return {
          success: true,
          data: { id: "record_uuid_123", status: "completed" },
          consequenceReceipt: { hash: "consequence_sha256_witness" },
        };
      },
    },
  };

  const client = createClient({
    contract: contract([action({ semanticId: "zoe:SelectOption", authorityBoundary: "SELECT", doAuthority: false })]),
    transports,
    prefer: "http",
  });

  const { result, receipt } = await client.get("todos:Todo:create").invokeWithReceipt({ title: "test" });
  assert.equal(result.success, true);
  assert.equal(receipt.authorityBoundary, "SELECT");
  assert.equal(receipt.doAuthority, false);
  assert.equal(receipt.transportReceipt.selected, "http");
  assert.equal(receipt.transportReceipt.dispatchState, "completed");
  assert.equal(receipt.consequenceReceipt.hash, "consequence_sha256_witness");
});
