import { test, expect } from "bun:test";
import { flattenSchema, groupOperations, buildUrl, resolveRef } from "./explorer_lib.js";

const spec = {
  paths: {
    "/posts": { get: { tags: ["post"], summary: "List", parameters: [{ name: "sort", in: "query" }], responses: { 200: { description: "ok", content: { "application/vnd.api+json": { schema: { $ref: "#/components/schemas/Post" } } } } } },
                post: { tags: ["post"], requestBody: { content: { "application/vnd.api+json": { schema: { $ref: "#/components/schemas/Post" } } } }, responses: { 201: { description: "c" } } } },
    "/posts/{id}": { delete: { tags: ["post"], parameters: [{ name: "id", in: "path" }], responses: { 200: { description: "d" } } } },
    "/authors": { get: { tags: ["author"], responses: {} } },
  },
  components: { schemas: { Post: { type: "object", required: ["title"], properties: { title: { type: "string" }, tags: { type: "array", items: { type: "string" } }, parent: { $ref: "#/components/schemas/Post" } } } } },
};

test("resolveRef follows $ref", () => expect(resolveRef(spec, { $ref: "#/components/schemas/Post" }).type).toBe("object"));

test("flattenSchema: nested rows, required flag, array types, cycle-safe", () => {
  const rows = flattenSchema(spec, { $ref: "#/components/schemas/Post" });
  const by = Object.fromEntries(rows.map((r) => [r.path, r]));
  expect(by.title).toMatchObject({ type: "string", required: true, depth: 1 });
  expect(by.tags.type).toBe("array<string>");
  expect(by.parent.type).toBe("object");
  expect(rows.length).toBeLessThan(20);
});

test("groupOperations groups by tag with every method", () => {
  const g = groupOperations(spec);
  expect(g.map((x) => x.tag)).toEqual(["author", "post"]);
  expect(g[1].operations.map((o) => o.id).sort()).toEqual(["DELETE /posts/{id}", "GET /posts", "POST /posts"]);
  expect(g[1].operations.find((o) => o.method === "POST").requestSchema).toBeTruthy();
});

test("buildUrl substitutes path and query params", () => {
  expect(buildUrl("/posts/{id}", [{ name: "id", in: "path" }, { name: "sort", in: "query" }], { id: "a b", sort: "-points" })).toBe("/posts/a%20b?sort=-points");
});
