// Real zod + real emitted artifact (fetched from the compiled projection by the ExUnit suite,
// which also records what the real Ash /validate endpoint answered for the same payloads).
import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { loadSurfaceModule, validateWith, validateText, actionId } from "./validator.js";

const artifactPath = process.env.SURFACE_ARTIFACT;
const parityPath = process.env.SURFACE_PARITY;
if (!artifactPath || !parityPath) throw new Error("SURFACE_ARTIFACT and SURFACE_PARITY required (run via mix test)");

const text = readFileSync(artifactPath, "utf8");
// Non-browser importer: the ExUnit suite wrote the artifact inside the project so `zod` resolves.
const mod = await loadSurfaceModule(text, { importer: () => import(pathToFileURL(resolve(artifactPath)).href) });
const parity = JSON.parse(readFileSync(parityPath, "utf8"));

test("actionId maps module + action to the SCHEMAS key", () => {
  expect(actionId("Playground.Blog.Post", "create")).toBe("Post.create");
  expect(mod.SCHEMAS["Post.create"]).toBeDefined();
});

test("accepts a valid Post.create payload", () => {
  expect(validateWith(mod, "Post.create", { title: "Hello", points: 2 }).ok).toBe(true);
});

test("rejects title 'ab' with too_small at path title", () => {
  const r = validateWith(mod, "Post.create", { title: "ab" });
  expect(r.ok).toBe(false);
  expect(r.issues.some((i) => i.path === "title" && i.code === "too_small")).toBe(true);
});

test("rejects negative points and unknown status enum", () => {
  const r = validateWith(mod, "Post.create", { title: "abc", points: -1, status: "nope" });
  expect(r.issues.map((i) => i.path).sort()).toEqual(["points", "status"]);
});

test("validateText reports invalid JSON and unknown action as typed results", () => {
  expect(validateText(mod, "Post.create", "{").kind).toBe("invalid_json");
  expect(validateWith(mod, "Nope.none", {}).kind).toBe("no_schema");
});

test("PARITY: zod verdict and failing fields equal the real Ash /validate endpoint", () => {
  expect(parity.length).toBeGreaterThanOrEqual(3);
  for (const c of parity) {
    const z = validateWith(mod, "Post.create", c.payload);
    expect(z.ok).toBe(c.ashValid);
    expect([...new Set(z.issues.map((i) => i.path))].sort()).toEqual([...c.ashFields].sort());
  }
});
