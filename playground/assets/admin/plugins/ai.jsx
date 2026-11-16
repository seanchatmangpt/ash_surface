import React, { useState } from "react";
import { useAdmin } from "../context.jsx";
import { useChat } from "../ai/use_chat.js";
import {
  Conversation, ConversationContent, ConversationEmptyState, ConversationScrollButton,
  Message, MessageContent, Response, Reasoning, Sources, Tool, Loader,
  PromptInput, PromptInputTextarea, PromptInputToolbar, PromptInputTools, PromptInputSubmit,
} from "../ai/elements.jsx";

function ChatPage() {
  const { actorId } = useAdmin();
  const { messages, status, error, sendMessage } = useChat({ body: { actor_id: actorId } });
  const [text, setText] = useState("");

  const submit = (value) => {
    const v = (value ?? text).trim();
    if (!v || status === "submitted" || status === "streaming") return;
    setText("");
    sendMessage(v);
  };

  return (
    <div className="mx-auto flex h-[calc(100vh-9rem)] max-w-3xl flex-col rounded-xl border p-4">
      <Conversation className="h-full">
        <ConversationContent>
          {messages.length === 0 && (
            <ConversationEmptyState title="Ask the Blog domain" description='Try "list posts", "count comments" or "create post titled Hello". Pick an actor in the header to apply policies.' />
          )}
          {messages.map((m) => (
            <Message key={m.id} from={m.role}>
              <MessageContent from={m.role}>
                {m.parts.map((p, i) =>
                  p.type === "text" ? <Response key={i}>{p.text}</Response>
                  : p.type === "reasoning" ? <Reasoning key={i} text={p.text} isStreaming={!m.done && i === m.parts.length - 1} />
                  : p.type === "sources" ? <Sources key={i} sources={p.sources} />
                  : p.type === "tool" ? <Tool key={i} part={p} />
                  : null,
                )}
                {m.role === "assistant" && !m.done && m.parts.length === 0 && <Loader />}
              </MessageContent>
            </Message>
          ))}
          {error && <div className="text-sm text-destructive">Error: {error.message}</div>}
        </ConversationContent>
        <ConversationScrollButton />
      </Conversation>
      <PromptInput onSubmit={submit} className="mt-4">
        <PromptInputTextarea value={text} onChange={(e) => setText(e.target.value)} />
        <PromptInputToolbar>
          <PromptInputTools />
          <PromptInputSubmit status={status} disabled={!text.trim() && status === "ready"} />
        </PromptInputToolbar>
      </PromptInput>
    </div>
  );
}

export default { id: "ai", pages: [{ path: "chat", label: "AI Chat", Page: ChatPage }], tabs: [] };
