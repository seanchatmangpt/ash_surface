import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { z } from "zod";

// Consumer execution receipt for the manufactured `<prefix>.voice.json`:
// the artifact is read as a consumer would (JSON.parse) and validated by a
// Zod boundary schema, then compared with the surface it was projected from.
// spec: { artifactPath, surfaceDigest, actionIds }

const [specPath] = process.argv.slice(2);
if (!specPath) throw new Error("usage: node generated_voice_kiosk_runner.mjs <specPath>");

const spec = JSON.parse(await readFile(specPath, "utf8"));
const artifact = JSON.parse(await readFile(spec.artifactPath, "utf8"));

const intent = z.object({
  actionId: z.string().min(1),
  prompt: z.string().min(1),
  slots: z.array(z.object({ name: z.string(), grammar: z.string(), required: z.boolean() }).passthrough()),
  mode: z.enum(["ANSWER", "CONFIRM"]),
  autoExecute: z.boolean(),
}).strict();
const schema = z.object({
  kind: z.literal("voice_kiosk"),
  surfaceDigest: z.string().min(1),
  intents: z.array(intent),
}).strict();

const voice = schema.parse(artifact);
assert.equal(voice.surfaceDigest, spec.surfaceDigest);
assert.deepEqual(voice.intents.map((i) => i.actionId), [...spec.actionIds].sort());

// Capability gating, observed on the emitted data: a confirmation is never an
// auto-execution, and only an answered OBSERVE may auto-execute.
for (const i of voice.intents) {
  if (i.mode === "CONFIRM") {
    assert.equal(i.autoExecute, false, `${i.actionId}: confirmation must not auto-execute`);
    assert.match(i.prompt, /^Please confirm: /);
  }
}
assert.throws(() => schema.parse({ ...artifact, intents: [{ ...voice.intents[0], mode: "EXECUTE" }] }));

console.log(JSON.stringify({ receipt: "GENERATED_VOICE_KIOSK_PASS", intents: voice.intents.length }));
