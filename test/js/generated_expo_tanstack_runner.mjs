import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for the manufactured Expo client factory
// (`<prefix>.mjs`) and TanStack adapter (`<prefix>.tanstack.mjs`), driven
// through the defined seam: a stub transport adapter (`invoke`).
// spec: { prefix, factory, contract, actionId, validInput, invalidInput,
//   resource, action, runtimeVersion }

const [targetDir, specPath] = process.argv.slice(2);
if (!targetDir || !specPath) {
  throw new Error("usage: node generated_expo_tanstack_runner.mjs <targetDir> <specPath>");
}

const spec = JSON.parse(await readFile(specPath, "utf8"));
const load = (name) => import(pathToFileURL(join(targetDir, name)).href);
const clientMod = await load(`${spec.prefix}.mjs`);
const tanstack = await load(`${spec.prefix}.tanstack.mjs`);
const actions = await load(`${spec.prefix}.actions.mjs`);
const runtime = await load("node_modules/ash_surface/index.mjs");

assert.deepEqual(Object.keys(clientMod), [spec.factory]);
assert.deepEqual(Object.keys(tanstack).sort(), ["createMutationOptions", "queryKeys"]);

function stubTransport(behaviour) {
  const calls = [];
  return {
    calls,
    adapter: {
      invoke(request) {
        calls.push(request);
        return behaviour(request);
      },
    },
  };
}

const build = (stub) =>
  clientMod[spec.factory]({ contract: spec.contract, transports: { http: stub.adapter }, prefer: "http" });

// --- client factory: wires the shipped runtime, pre-binds manufactured schemas
{
  const stub = stubTransport(async () => ({ success: true, data: { id: "m1" }, receiptRef: "rcpt_1" }));
  const client = build(stub);
  assert.ok(Object.isFrozen(client));
  assert.equal(client.runtimeVersion, runtime.SURFACE_RUNTIME_VERSION, "client is the shipped runtime, not a copy");
  assert.deepEqual(client.actionsMetadata, actions.ACTIONS);
  assert.equal(typeof client.reconcile, "function");
  for (const id of spec.contract.surface.actions.map((a) => a.id)) assert.ok(client.get(id), id);

  // Pre-bound input schema: invalid input is refused BEFORE dispatch.
  await assert.rejects(client.get(spec.actionId).invokeWithReceipt(spec.invalidInput), { code: "INPUT_VALIDATION_FAILED" });
  assert.equal(stub.calls.length, 0, "invalid input must never reach the transport");

  // Pre-bound output schema: a malformed reply is refused, not passed through.
  const badOut = stubTransport(async () => ({ success: "yes" }));
  await assert.rejects(build(badOut).get(spec.actionId).invokeWithReceipt(spec.validInput), { code: "OUTPUT_VALIDATION_FAILED" });
}

// --- query keys: stable hierarchy rooted at the ash_surface namespace
{
  const { queryKeys } = tanstack;
  assert.deepEqual(queryKeys.all, ["ash_surface"]);
  assert.deepEqual(queryKeys.resource("R"), ["ash_surface", "R"]);
  assert.deepEqual(queryKeys.action("R", "a"), ["ash_surface", "R", "a"]);
  const isPrefix = (p, k) => p.length <= k.length && p.every((seg, i) => seg === k[i]);
  assert.ok(isPrefix(queryKeys.all, queryKeys.resource("R")));
  assert.ok(isPrefix(queryKeys.resource("R"), queryKeys.action("R", "a")));
  assert.ok(!isPrefix(queryKeys.resource("Q"), queryKeys.action("R", "a")));
}

// --- createMutationOptions: keyed from action metadata, wired to invokeWithReceipt
{
  const stub = stubTransport(async () => ({ success: true, data: { id: "m1" }, receiptRef: "rcpt_1" }));
  const client = build(stub);
  const options = tanstack.createMutationOptions(client, spec.actionId);
  assert.deepEqual(options.mutationKey, tanstack.queryKeys.action(spec.resource, spec.action));
  assert.equal(typeof options.mutationFn, "function");

  // Receipt-bearing: the mutation resolves { result, receipt }, not a bare result.
  const outcome = await options.mutationFn(spec.validInput);
  assert.equal(stub.calls.length, 1);
  assert.equal(stub.calls[0].action.id, spec.actionId);
  assert.equal(outcome.result.receiptRef, "rcpt_1");
  assert.equal(outcome.receipt.dispatchState, "completed");
  assert.equal(outcome.receipt.domainReceiptRef, "rcpt_1");
  assert.equal(outcome.receipt.transportReceipt.selected, "http");

  // Invalid input is refused before dispatch through the mutation seam too.
  await assert.rejects(options.mutationFn(spec.invalidInput), { code: "INPUT_VALIDATION_FAILED" });
  assert.equal(stub.calls.length, 1);
}

// --- post-dispatch failure is UNKNOWN_AFTER_DISPATCH: dispatched once, never replayed
{
  const stub = stubTransport(async () => { throw new Error("socket closed"); });
  const options = tanstack.createMutationOptions(build(stub), spec.actionId);
  await assert.rejects(options.mutationFn(spec.validInput), (err) => {
    assert.equal(err.code, "TRANSPORT_OUTCOME_UNKNOWN");
    assert.equal(err.receipt.dispatchState, "unknown_after_dispatch");
    assert.equal(err.receipt.outcome, "UNKNOWN_AFTER_DISPATCH");
    return true;
  });
  assert.equal(stub.calls.length, 1, "no replay after dispatch");
}

// --- unknown action: keyed on absent metadata, and nothing can be dispatched
{
  const stub = stubTransport(async () => ({ success: true }));
  const options = tanstack.createMutationOptions(build(stub), "Ghost#nothing");
  assert.deepEqual(options.mutationKey, tanstack.queryKeys.action(undefined, undefined));
  await assert.rejects(options.mutationFn({}));
  assert.equal(stub.calls.length, 0);
}

console.log(JSON.stringify({ receipt: "GENERATED_EXPO_TANSTACK_PASS", wiredToInvokeWithReceipt: true }));
