// Hand-ported AI Elements (https://elements.ai-sdk.dev) as shadcn-style components:
// Conversation, Message, Response, Reasoning, Sources, Tool, Loader, PromptInput.
import React, { useState } from "react";
import { StickToBottom, useStickToBottomContext } from "use-stick-to-bottom";
import { ArrowDownIcon, BrainIcon, BookIcon, ChevronDownIcon, WrenchIcon, SendIcon, SquareIcon } from "lucide-react";
import { cn } from "../../lib/utils.js";
import { Button } from "../../ui/button.jsx";

// ---- Conversation ----
export const Conversation = ({ className, ...p }) => (
  <StickToBottom className={cn("relative flex-1 overflow-y-hidden", className)} initial="smooth" resize="smooth" role="log" {...p} />
);
export const ConversationContent = ({ className, ...p }) => (
  <StickToBottom.Content className={cn("flex flex-col gap-6 p-4", className)} {...p} />
);
export const ConversationEmptyState = ({ title = "No messages yet", description = "Start a conversation to see messages here", className, children }) => (
  <div className={cn("flex size-full flex-col items-center justify-center gap-1 p-8 text-center text-muted-foreground", className)}>
    {children ?? (
      <>
        <h3 className="text-sm font-medium text-foreground">{title}</h3>
        <p className="text-sm">{description}</p>
      </>
    )}
  </div>
);
export function ConversationScrollButton({ className }) {
  const { isAtBottom, scrollToBottom } = useStickToBottomContext();
  if (isAtBottom) return null;
  return (
    <Button
      type="button"
      variant="outline"
      size="icon"
      className={cn("absolute bottom-4 left-1/2 -translate-x-1/2 rounded-full", className)}
      onClick={() => scrollToBottom()}
    >
      <ArrowDownIcon className="size-4" />
    </Button>
  );
}

// ---- Message ----
export const Message = ({ from, className, ...p }) => (
  <div className={cn("group flex w-full max-w-[95%] flex-col gap-2", from === "user" ? "is-user ml-auto items-end" : "is-assistant", className)} {...p} />
);
export const MessageContent = ({ from, className, ...p }) => (
  <div
    className={cn(
      "flex flex-col gap-2 overflow-hidden rounded-lg px-4 py-3 text-sm",
      from === "user" ? "bg-primary text-primary-foreground" : "text-foreground",
      className,
    )}
    {...p}
  />
);

// ---- Response (tiny markdown: fenced code, lists, bold, inline code) ----
function inline(text) {
  return text.split(/(\*\*[^*]+\*\*|`[^`]+`)/g).map((s, i) =>
    s.startsWith("**") ? <strong key={i}>{s.slice(2, -2)}</strong>
    : s.startsWith("`") ? <code key={i} className="rounded bg-muted px-1 py-0.5 font-mono text-xs">{s.slice(1, -1)}</code>
    : s,
  );
}
export function Response({ children, className }) {
  const text = String(children ?? "");
  const blocks = text.split(/```/);
  return (
    <div className={cn("flex flex-col gap-2 [&>*]:leading-relaxed", className)}>
      {blocks.map((b, i) => {
        if (i % 2 === 1) return <pre key={i} className="overflow-x-auto rounded-md bg-muted p-3 font-mono text-xs">{b.replace(/^\w*\n/, "")}</pre>;
        const lines = b.split("\n");
        const out = [];
        let list = [];
        const flush = () => { if (list.length) { out.push(<ul key={`l${out.length}`} className="list-disc pl-5">{list.map((l, j) => <li key={j}>{inline(l)}</li>)}</ul>); list = []; } };
        lines.forEach((l) => {
          if (/^\s*[-*] /.test(l)) list.push(l.replace(/^\s*[-*] /, ""));
          else { flush(); if (l.trim()) out.push(<p key={`p${out.length}`}>{inline(l)}</p>); }
        });
        flush();
        return <React.Fragment key={i}>{out}</React.Fragment>;
      })}
    </div>
  );
}

// ---- Reasoning (collapsible; auto-open while streaming) ----
export function Reasoning({ isStreaming, text, className }) {
  const [open, setOpen] = useState(null);
  const isOpen = open ?? !!isStreaming;
  return (
    <div className={cn("not-prose mb-2 text-sm", className)}>
      <button type="button" onClick={() => setOpen(!isOpen)} className="flex items-center gap-2 text-muted-foreground transition-colors hover:text-foreground">
        <BrainIcon className="size-4" />
        <span>{isStreaming ? "Thinking..." : "Thought for a few seconds"}</span>
        <ChevronDownIcon className={cn("size-4 transition-transform", isOpen ? "rotate-180" : "rotate-0")} />
      </button>
      {isOpen && <div className="mt-3 border-l-2 pl-3 text-muted-foreground"><Response>{text}</Response></div>}
    </div>
  );
}

// ---- Sources ----
export function Sources({ sources, className }) {
  const [open, setOpen] = useState(false);
  return (
    <div className={cn("not-prose mb-2 text-xs", className)}>
      <button type="button" onClick={() => setOpen(!open)} className="flex items-center gap-2 text-primary">
        <span className="font-medium">Used {sources.length} source{sources.length === 1 ? "" : "s"}</span>
        <ChevronDownIcon className={cn("size-4 transition-transform", open && "rotate-180")} />
      </button>
      {open && (
        <div className="mt-3 flex flex-col gap-2">
          {sources.map((s) => (
            <a key={s.url} href={s.url} target="_blank" rel="noreferrer" className="flex items-center gap-2 text-blue-600 hover:underline">
              <BookIcon className="size-4" />
              <span className="block font-medium">{s.title}</span>
            </a>
          ))}
        </div>
      )}
    </div>
  );
}

// ---- Tool ----
export function Tool({ part, className }) {
  const [open, setOpen] = useState(false);
  const label = { running: "Running", done: "Completed", error: "Error" }[part.state];
  return (
    <div className={cn("not-prose w-full rounded-md border", className)} data-testid="tool">
      <button type="button" onClick={() => setOpen(!open)} className="flex w-full items-center justify-between gap-4 p-3">
        <span className="flex items-center gap-2 text-sm font-medium"><WrenchIcon className="size-4 text-muted-foreground" />{part.name}
          <span className="rounded-full bg-secondary px-2 py-0.5 text-xs">{label}</span></span>
        <ChevronDownIcon className={cn("size-4 transition-transform", open && "rotate-180")} />
      </button>
      {open && (
        <div className="space-y-3 border-t p-4 text-xs">
          <div><div className="mb-1 font-medium uppercase text-muted-foreground">Parameters</div><pre className="overflow-x-auto rounded bg-muted p-2">{JSON.stringify(part.args, null, 2)}</pre></div>
          <div><div className="mb-1 font-medium uppercase text-muted-foreground">{part.error ? "Error" : "Result"}</div>
            <pre className="overflow-x-auto rounded bg-muted p-2">{part.error ?? JSON.stringify(part.result, null, 2)}</pre></div>
        </div>
      )}
    </div>
  );
}

// ---- Loader ----
export const Loader = ({ size = 16, className }) => (
  <svg className={cn("animate-spin text-muted-foreground", className)} width={size} height={size} viewBox="0 0 24 24" fill="none" role="status" aria-label="Loading">
    <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" opacity="0.25" />
    <path d="M22 12a10 10 0 0 0-10-10" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
  </svg>
);

// ---- PromptInput ----
export const PromptInput = ({ onSubmit, className, ...p }) => (
  <form
    onSubmit={(e) => { e.preventDefault(); onSubmit?.(new FormData(e.currentTarget).get("message")?.toString() ?? "", e); }}
    className={cn("w-full divide-y overflow-hidden rounded-xl border bg-background shadow-sm", className)}
    {...p}
  />
);
export const PromptInputTextarea = ({ className, onKeyDown, ...p }) => (
  <textarea
    name="message"
    rows={2}
    placeholder="What would you like to know?"
    className={cn("w-full resize-none border-0 bg-transparent p-3 text-sm outline-none", className)}
    onKeyDown={(e) => {
      onKeyDown?.(e);
      if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); e.currentTarget.form?.requestSubmit(); }
    }}
    {...p}
  />
);
export const PromptInputToolbar = ({ className, ...p }) => <div className={cn("flex items-center justify-between p-1", className)} {...p} />;
export const PromptInputTools = ({ className, ...p }) => <div className={cn("flex items-center gap-1", className)} {...p} />;
export function PromptInputSubmit({ status, className, ...p }) {
  const busy = status === "submitted" || status === "streaming";
  return (
    <Button type="submit" size="icon" className={cn("gap-1.5 rounded-lg", className)} disabled={busy} {...p}>
      {status === "submitted" ? <Loader /> : status === "streaming" ? <SquareIcon className="size-4" /> : <SendIcon className="size-4" />}
    </Button>
  );
}
