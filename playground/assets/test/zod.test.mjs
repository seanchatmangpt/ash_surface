// Real zod, real emitted artifact (path from ARTIFACT env, written by the ExUnit suite).
import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { loadSchemas, makeValidator } from "../validate.mjs";

const artifactPath = process.env.ARTIFACT;
if (!artifactPath) throw new Error("ARTIFACT env var is required (run via mix test)");
const text = readFileSync(artifactPath, "utf8");
const { SCHEMAS } = await import(pathToFileURL(resolve(artifactPath)).href);

test("valid create payload passes the emitted schema", () => {
  const r = SCHEMAS["Todo.create"].safeParse({ title: "Ship it", points: 5, priority: "high" });
  expect(r.success).toBe(true);
});

test("points above max yields a typed too_big issue at path points", () => {
  const r = SCHEMAS["Todo.create"].safeParse({ title: "x", points: 150 });
  expect(r.success).toBe(false);
  const issue = r.error.issues.find((i) => i.path.join(".") === "points");
  expect(issue.code).toBe("too_big");
});

test("empty title and bad enum are refused with typed codes", () => {
  const r = SCHEMAS["Todo.create"].safeParse({ title: "", priority: "urgent" });
  expect(r.success).toBe(false);
  const byPath = Object.fromEntries(r.error.issues.map((i) => [i.path.join("."), i.code]));
  expect(byPath.title).toBe("too_small");
  expect(byPath.priority).toBe("invalid_value");
});

test("browser loader path: blob module + bundled zod + makeValidator", async () => {
  const zodUrl = pathToFileURL(resolve("priv/static/assets/zod.mjs")).href;
  const mod = await loadSchemas(text, zodUrl);
  const validate = makeValidator(mod);
  expect(validate("Todo.create", '{"title":"ok"}')).toEqual({ ok: true });
  const bad = validate("Todo.create", '{"title":"x","points":150}');
  expect(bad.ok).toBe(false);
  expect(bad.issues.some((i) => i.path === "points" && i.code === "too_big")).toBe(true);
  expect(validate("Todo.create", "{nope").kind).toBe("invalid JSON");
  expect(validate("Nope.x", "{}").kind).toBe("no schema for action");
});
