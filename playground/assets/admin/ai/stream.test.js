import { test, expect } from "bun:test";
import { createSseParser, applyEvent, newAssistant, consume, textOf } from "./stream.js";

const fixture = await Bun.file(new URL("./fixture.sse", import.meta.url)).text();

test("parser yields every frame even when the stream is split mid-frame", () => {
  const evs = [];
  const p = createSseParser((e) => evs.push(e));
  for (let i = 0; i < fixture.length; i += 7) p.push(fixture.slice(i, i + 7));
  expect(evs.map((e) => e.type)).toEqual(["start", "reasoning", "tool-call", "tool-result", "sources", "text-delta", "text-delta", "finish"]);
  expect(p.rest()).toBe("");
});

test("reducer folds the fixture into reasoning, tool, sources and text parts", () => {
  let m = newAssistant("a");
  createSseParser((e) => (m = applyEvent(m, e))).push(fixture);
  expect(m.parts.map((p) => p.type)).toEqual(["reasoning", "tool", "sources", "text"]);
  const tool = m.parts[1];
  expect(tool).toMatchObject({ name: "list_posts", state: "done", args: { limit: 25 } });
  expect(tool.result[0].title).toBe("Hello");
  expect(textOf(m)).toBe("Found 1 post(s).");
  expect(m.done).toBe(true);
});

test("tool-result with error marks the tool part as error", () => {
  let m = applyEvent(newAssistant("a"), { type: "tool-call", id: "x", name: "create_post", args: {} });
  m = applyEvent(m, { type: "tool-result", id: "x", name: "create_post", error: "forbidden" });
  expect(m.parts[0]).toMatchObject({ state: "error", error: "forbidden" });
});

test("consume reads a real chunked HTTP SSE response end to end", async () => {
  const server = Bun.serve({
    port: 0,
    fetch() {
      const enc = new TextEncoder();
      const body = new ReadableStream({
        start(c) {
          for (let i = 0; i < fixture.length; i += 11) c.enqueue(enc.encode(fixture.slice(i, i + 11)));
          c.close();
        },
      });
      return new Response(body, { headers: { "content-type": "text/event-stream" } });
    },
  });
  try {
    const res = await fetch(`http://localhost:${server.port}/`);
    const m = await consume(res);
    expect(textOf(m)).toBe("Found 1 post(s).");
    expect(m.done).toBe(true);
  } finally {
    server.stop(true);
  }
});
