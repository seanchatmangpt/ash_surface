import fs from "node:fs";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { z } from "zod";
import { createClient, SurfaceRuntimeError } from "../../priv/static/ash_surface_runtime.mjs";

const [contractPath, portStr, receiptPath] = process.argv.slice(2);

if (!contractPath || !portStr) {
  console.error("Usage: node consumer_e2e_runner.mjs <contract_json_path> <port> [receipt_out_path]");
  process.exit(1);
}

const port = Number(portStr);
const rawContract = JSON.parse(fs.readFileSync(contractPath, "utf-8"));

// 1. Zod schemas for the real consumer boundary
const milestoneInputSchema = z.object({
  member_id: z.string().min(1),
  milestone_id: z.string().min(1),
  cost_physical: z.number().int().nonnegative(),
  reward_spiritual: z.number().int().nonnegative(),
});

const milestoneOutputSchema = z.object({
  success: z.literal(true),
  data: z.object({
    id: z.string().min(1),
    member_id: z.string(),
    milestone_id: z.string(),
    cost_physical: z.number(),
    reward_spiritual: z.number(),
    status: z.string(),
  }),
});

const actionId = "AshSurface.Fixtures.VolunteerMilestone#record";

// 2. Build admitted HTTP transport
const httpTransport = {
  async invoke({ action, input }) {
    const res = await fetch(`http://127.0.0.1:${port}/dispatch`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: action.id, input }),
    });

    if (!res.ok) {
      throw new Error(`HTTP error ${res.status}`);
    }

    return await res.json();
  },
};

// 3. Initialize AshSurface client directly from contract
const client = createClient({
  contract: rawContract,
  transports: {
    http: httpTransport,
  },
  prefer: "http",
  schemas: {
    [actionId]: {
      input: milestoneInputSchema,
      output: milestoneOutputSchema,
    },
  },
});

assert.ok(client.resources["AshSurface.Fixtures.VolunteerMilestone"], "Resource namespace must exist");
const recordAction = client.resources["AshSurface.Fixtures.VolunteerMilestone"].record;
assert.ok(recordAction, "Action must exist on resource");

// 4. Dispatch action and observe consequence
const inputPayload = {
  member_id: "member_zoela_01",
  milestone_id: "milestone_serve_42",
  cost_physical: 10,
  reward_spiritual: 100,
};

const { result, receipt } = await recordAction.invokeWithReceipt(inputPayload);

assert.equal(receipt.dispatchState, "completed");
assert.equal(receipt.selected, "http");
assert.equal(receipt.actionId, actionId);
assert.equal(result.success, true);
assert.equal(result.data.member_id, "member_zoela_01");
assert.equal(result.data.milestone_id, "milestone_serve_42");
assert.equal(result.data.cost_physical, 10);
assert.equal(result.data.reward_spiritual, 100);
assert.equal(result.data.status, "completed");

// 5. Emit cryptographic execution receipt
const receiptPayload = {
  actionId,
  input: inputPayload,
  consequence: result.data,
  dispatchState: receipt.dispatchState,
  selectedTransport: receipt.selected,
  timestamp: new Date().toISOString(),
};

function canonicalStringify(obj) {
  if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(canonicalStringify).join(",")}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalStringify(obj[k])}`).join(",")}}`;
}

const receiptHash = crypto.createHash("sha256").update(canonicalStringify(receiptPayload)).digest("hex");
const finalReceipt = {
  ...receiptPayload,
  receiptHash,
};

if (receiptPath) {
  fs.writeFileSync(receiptPath, JSON.stringify(finalReceipt, null, 2), "utf-8");
}

// 6. Test Transport Law: post-dispatch failure must be UNKNOWN_AFTER_DISPATCH
const failingHttpTransport = {
  async invoke({ input }) {
    await fetch(`http://127.0.0.1:${port}/simulate_disconnect_after_dispatch`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ input }),
    });
    return { success: true };
  },
};

const failingClient = createClient({
  contract: rawContract,
  transports: {
    http: failingHttpTransport,
  },
  prefer: "http",
});

let failedAsExpected = false;
try {
  await failingClient.get(actionId).invoke({
    member_id: "member_fail",
    milestone_id: "milestone_fail",
    cost_physical: 5,
    reward_spiritual: 10,
  });
} catch (error) {
  if (error instanceof SurfaceRuntimeError) {
    assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
    assert.equal(error.receipt?.dispatchState, "unknown_after_dispatch");
    failedAsExpected = true;
  } else {
    throw error;
  }
}

assert.ok(failedAsExpected, "Must fail with TRANSPORT_OUTCOME_UNKNOWN after post-dispatch disconnect");

process.stdout.write(JSON.stringify({ status: "OK", receiptHash }));
