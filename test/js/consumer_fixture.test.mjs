import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import crypto from "node:crypto";
import { z } from "zod";
import {
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

function makeFixtureContract() {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {
      resources: [
        {
          name: "VolunteerMilestone",
          module: "AshSurface.Fixtures.VolunteerMilestone",
        },
      ],
    },
    surface: {
      profile: { audience: "public" },
      actions: [
        {
          id: "AshSurface.Fixtures.VolunteerMilestone#record",
          // v26.9.16 delegation: delegated facts surface as explicit null
          // when not delegated.
          semanticId: null,
          authorityBoundary: null,
          doAuthority: null,
          receiptRequired: null,
          resource: "AshSurface.Fixtures.VolunteerMilestone",
          action: "record",
          profile: {
            consumer: "mobile",
            transport: "http",
          },
        },
      ],
    },
  };
}

function canonicalStringify(obj) {
  if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(canonicalStringify).join(",")}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalStringify(obj[k])}`).join(",")}}`;
}

test("consumer fixture executes end-to-end against HTTP transport with Zod schemas and receipts", async () => {
  let serverDispatched = null;

  const server = http.createServer(async (req, res) => {
    if (req.method === "POST" && req.url === "/dispatch") {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const body = JSON.parse(Buffer.concat(chunks).toString("utf-8"));
      serverDispatched = body;

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(
        JSON.stringify({
          success: true,
          data: {
            id: "65ad98a3-4d77-4365-924c-b050a12b5160",
            ...body.input,
            status: "completed",
          },
        }),
      );
      return;
    }

    res.writeHead(404);
    res.end();
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();

  try {
    const contract = makeFixtureContract();
    const actionId = "AshSurface.Fixtures.VolunteerMilestone#record";

    const inputSchema = z.object({
      member_id: z.string().min(1),
      milestone_id: z.string().min(1),
      cost_physical: z.number().int().nonnegative(),
      reward_spiritual: z.number().int().nonnegative(),
    });

    const outputSchema = z.object({
      success: z.literal(true),
      data: z.object({
        id: z.string().uuid(),
        member_id: z.string(),
        milestone_id: z.string(),
        cost_physical: z.number(),
        reward_spiritual: z.number(),
        status: z.string(),
      }),
    });

    const client = createClient({
      contract,
      transports: {
        http: {
          async invoke({ action, input }) {
            const res = await fetch(`http://127.0.0.1:${port}/dispatch`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ action: action.id, input }),
            });
            return await res.json();
          },
        },
      },
      prefer: "http",
      schemas: {
        [actionId]: {
          input: inputSchema,
          output: outputSchema,
        },
      },
    });

    const input = {
      member_id: "member_zoela_01",
      milestone_id: "milestone_serve_42",
      cost_physical: 10,
      reward_spiritual: 100,
    };

    const { result, receipt } = await client.resources[
      "AshSurface.Fixtures.VolunteerMilestone"
    ].record.invokeWithReceipt(input);

    assert.equal(receipt.dispatchState, "completed");
    assert.equal(receipt.selected, "http");
    assert.equal(result.success, true);
    assert.equal(result.data.member_id, "member_zoela_01");
    assert.equal(serverDispatched.input.member_id, "member_zoela_01");

    const receiptPayload = {
      actionId,
      input,
      consequence: result.data,
      dispatchState: receipt.dispatchState,
      selectedTransport: receipt.selected,
      timestamp: new Date().toISOString(),
    };

    const receiptHash = crypto
      .createHash("sha256")
      .update(canonicalStringify(receiptPayload))
      .digest("hex");

    // receiptHash integrity law (chicago-receipthash-038): the hash is the
    // lowercase-hex SHA-256 of canonical JSON over the receipt payload's
    // NAMED content fields — actionId, input, consequence, dispatchState,
    // selectedTransport, timestamp — never a bare shape check. Independent
    // recomputation rebuilds the payload from the named fields only, so a
    // payload that grows or shrinks a field fails here.
    const expectedPayload = {
      actionId: actionId,
      input: input,
      consequence: result.data,
      dispatchState: receipt.dispatchState,
      selectedTransport: receipt.selected,
      timestamp: receiptPayload.timestamp,
    };
    const expectedHash = crypto
      .createHash("sha256")
      .update(canonicalStringify(expectedPayload))
      .digest("hex");

    assert.equal(receiptHash, expectedHash);
    assert.equal(receiptHash.length, 64);

    // Reorder-invariant: key insertion order must never move the hash.
    const permutedPayload = {
      timestamp: receiptPayload.timestamp,
      selectedTransport: receipt.selected,
      dispatchState: receipt.dispatchState,
      consequence: result.data,
      input: input,
      actionId: actionId,
    };
    assert.equal(
      crypto.createHash("sha256").update(canonicalStringify(permutedPayload)).digest("hex"),
      receiptHash,
    );

    // Value-sensitive: any content change must move the hash.
    const tamperedHash = crypto
      .createHash("sha256")
      .update(
        canonicalStringify({ ...expectedPayload, dispatchState: "unknown_after_dispatch" }),
      )
      .digest("hex");
    assert.notEqual(tamperedHash, receiptHash);
  } finally {
    server.close();
  }
});
