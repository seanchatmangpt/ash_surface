import { useCallback, useRef, useState } from "react";
import { consume, newAssistant, textOf } from "./stream.js";

// Minimal useChat over our SSE transport. status: ready | submitted | streaming | error
export function useChat({ api = "/admin/api/ai/chat", body = {} } = {}) {
  const [messages, setMessages] = useState([]);
  const [status, setStatus] = useState("ready");
  const [error, setError] = useState(null);
  const ref = useRef([]);
  ref.current = messages;

  const sendMessage = useCallback(
    async (text) => {
      const user = { id: `u${Date.now()}`, role: "user", parts: [{ type: "text", text }] };
      const asst = newAssistant(`a${Date.now()}`);
      const history = [...ref.current, user];
      setMessages([...history, asst]);
      setStatus("submitted");
      setError(null);
      try {
        const res = await fetch(api, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            ...body,
            messages: history.map((m) => ({ role: m.role, content: textOf(m) })),
          }),
        });
        if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
        await consume(
          res,
          (m) => {
            setStatus("streaming");
            setMessages([...history, m]);
          },
          asst,
        );
        setStatus("ready");
      } catch (e) {
        setError(e);
        setStatus("error");
      }
    },
    [api, JSON.stringify(body)],
  );

  return { messages, status, error, sendMessage };
}
