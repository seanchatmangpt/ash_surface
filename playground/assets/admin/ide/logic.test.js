import { expect, test } from "bun:test";
import { parseCommand, splitArgs, toRunBody, runQueue, flattenTree } from "./logic.js";

test("splitArgs respects quotes and brackets", () => {
  expect(splitArgs('a: "x, y", b: [1, 2], c: {"k": 1}')).toEqual(['a: "x, y"', "b: [1, 2]", 'c: {"k": 1}']);
});

test("parseCommand", () => {
  expect(parseCommand('Post.create(title: "x", points: 3, tags: ["a","b"])')).toEqual({
    resource: "Post", action: "create", params: { title: "x", points: 3, tags: ["a", "b"] },
  });
  expect(parseCommand('Playground.Blog.Post.update(id: "abc", title: "n")')).toEqual({
    resource: "Playground.Blog.Post", action: "update", id: "abc", params: { title: "n" },
  });
  expect(parseCommand("Post.read")).toEqual({ resource: "Post", action: "read", params: {} });
  expect(parseCommand("nonsense").error).toBeTruthy();
  expect(parseCommand("Post.create(oops)").error).toMatch(/bad argument/);
});

test("toRunBody resolves short names", () => {
  const rs = [{ name: "Post", module: "Playground.Blog.Post" }];
  const r = toRunBody(parseCommand('Post.create(title: "x")'), rs, { actor_id: "1" });
  expect(r.body).toEqual({ actor_id: "1", resource: "Playground.Blog.Post", action: "create", params: { title: "x" } });
  expect(toRunBody({ resource: "Nope", action: "x", params: {} }, rs).error).toMatch(/unknown/);
});

test("runQueue is sequential, continues after errors, reports each", async () => {
  const order = [];
  const seen = [];
  const run = async (item, i) => {
    order.push(`start${i}`);
    await Promise.resolve();
    order.push(`end${i}`);
    if (item.command === "bad") throw new Error("boom");
    return { command: item.command, status: "ok", lines: [], result: null, duration_ms: 1 };
  };
  const res = await runQueue([{ command: "a" }, { command: "bad" }, { command: "c" }], run, (r) => seen.push(r.status));
  expect(order).toEqual(["start0", "end0", "start1", "end1", "start2", "end2"]);
  expect(seen).toEqual(["ok", "error", "ok"]);
  expect(res.map((r) => r.command)).toEqual(["a", "bad", "c"]);
});

test("flattenTree", () => {
  expect(flattenTree([{ name: "d", children: [{ path: "a" }, { path: "b" }] }]).map((f) => f.path)).toEqual(["a", "b"]);
});
