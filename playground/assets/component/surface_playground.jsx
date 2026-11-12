import React, { useState } from "react";

// Shared by SSR (phoenix_react_server renderToString) and the browser hydrate.
// `validate(actionId, payloadText)` is injected only in the browser (real zod).
export function Playground({ entries, selectedId, contract, artifact, validate, initialPayload }) {
  const [sel, setSel] = useState(selectedId);
  const [payload, setPayload] = useState(initialPayload ?? "{}");
  const [contractText, setContractText] = useState(contract);
  const current = entries.find((e) => e.id === sel) ?? entries[0];
  const result = validate ? validate(current.actionId, payload) : null;

  async function select(id) {
    setSel(id);
    if (typeof fetch === "function") {
      const res = await fetch(`/contract/${id}`);
      if (res.ok) setContractText(await res.text());
    }
  }

  return (
    <main>
      <h1>AshSurface playground</h1>
      <p>
        Compile-only: Ash fixture domain, IR contract, emitted Zod, in-browser validation. No Ash
        action executes; no backend call.
      </p>
      <section>
        <h2>Resources / actions ({entries.length})</h2>
        <ul id="resource-list">
          {entries.map((e) => (
            <li key={e.id} className={e.id === sel ? "sel" : ""}>
              <button type="button" data-testid={`select-${e.id}`} onClick={() => select(e.id)}>
                {e.resource}.{e.action}
              </button>{" "}
              <small>
                {e.action_type} - {e.digest}
              </small>
            </li>
          ))}
        </ul>
      </section>
      <div className="grid">
        <section>
          <h2>
            Compiled IR contract JSON: {current.resource}.{current.action}
          </h2>
          <pre id="contract-json">{contractText}</pre>
        </section>
        <section>
          <h2>Emitted Zod schema source (.mjs)</h2>
          <pre id="zod-source">{artifact}</pre>
        </section>
      </div>
      <section>
        <h2>Payload editor (zod runs in the browser)</h2>
        <p>
          Schema id: <code id="action-id">{current.actionId}</code>
        </p>
        <textarea
          id="payload"
          value={payload}
          onChange={(ev) => setPayload(ev.target.value)}
        />
        <div id="validation">
          {result === null ? (
            <span>validation available after hydration</span>
          ) : result.ok ? (
            <span className="ok">VALID</span>
          ) : (
            <div className="err">
              <b>{result.kind}</b>
              <ul>
                {result.issues.map((i, n) => (
                  <li key={n}>
                    <code>{i.path || "(root)"}</code> [{i.code}] {i.message}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </section>
    </main>
  );
}

export const Component = (props) => <Playground {...props} />;
