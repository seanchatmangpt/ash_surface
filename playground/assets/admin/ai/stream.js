// Stream protocol (see AshShadcn.Ai.Agent): SSE `data: <json>` frames carrying
// start | reasoning | tool-call | tool-result | sources | text-delta | finish.

// Incremental SSE parser: feed chunks, get complete events. Keeps a remainder buffer.
export function createSseParser(onEvent) {
  let buf = "";
  return {
    push(chunk) {
      buf += chunk;
      let i;
      while ((i = buf.indexOf("\n\n")) >= 0) {
        const frame = buf.slice(0, i);
        buf = buf.slice(i + 2);
        const data = frame
          .split("\n")
          .filter((l) => l.startsWith("data:"))
          .map((l) => l.slice(5).trimStart())
          .join("\n");
        if (data) onEvent(JSON.parse(data));
      }
    },
    rest: () => buf,
  };
}

export function newAssistant(id) {
  return { id, role: "assistant", parts: [], done: false };
}

const lastOf = (parts, type) => (parts.length && parts[parts.length - 1].type === type ? parts[parts.length - 1] : null);

// Pure reducer: apply one protocol event to an assistant message.
export function applyEvent(msg, ev) {
  const parts = msg.parts.slice();
  switch (ev.type) {
    case "reasoning": {
      const last = lastOf(parts, "reasoning");
      if (last) parts[parts.length - 1] = { ...last, text: last.text + ev.text };
      else parts.push({ type: "reasoning", text: ev.text });
      return { ...msg, parts };
    }
    case "tool-call":
      parts.push({ type: "tool", id: ev.id, name: ev.name, args: ev.args, state: "running" });
      return { ...msg, parts };
    case "tool-result": {
      const i = parts.findIndex((p) => p.type === "tool" && p.id === ev.id);
      if (i >= 0)
        parts[i] = { ...parts[i], state: ev.error ? "error" : "done", result: ev.result, error: ev.error };
      return { ...msg, parts };
    }
    case "sources":
      parts.push({ type: "sources", sources: ev.sources });
      return { ...msg, parts };
    case "text-delta": {
      const last = lastOf(parts, "text");
      if (last) parts[parts.length - 1] = { ...last, text: last.text + ev.text };
      else parts.push({ type: "text", text: ev.text });
      return { ...msg, parts };
    }
    case "finish":
      return { ...msg, done: true, finishReason: ev.reason };
    default:
      return msg;
  }
}

export const textOf = (msg) => msg.parts.filter((p) => p.type === "text").map((p) => p.text).join("");

// Read a fetch Response body (ReadableStream) through the parser, reducing into a message.
export async function consume(response, onUpdate, initial = newAssistant("a")) {
  let msg = initial;
  const parser = createSseParser((ev) => {
    msg = applyEvent(msg, ev);
    onUpdate?.(msg, ev);
  });
  const reader = response.body.getReader();
  const dec = new TextDecoder();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    parser.push(dec.decode(value, { stream: true }));
  }
  return msg;
}
