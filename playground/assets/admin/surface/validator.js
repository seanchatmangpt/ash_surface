// Client-side validation against the EMITTED AshSurface artifact (real zod).
// The artifact module text comes from GET /admin/api/surface/artifact.mjs; its bare `zod`
// import is rewired to the bundled /assets/zod.mjs. SSR-safe: nothing runs at import time.
import { useEffect, useMemo, useState } from "react";

export const ARTIFACT_URL = "/admin/api/surface/artifact.mjs";
export const ZOD_URL = "/assets/zod.mjs";

// Evaluate artifact text as an ES module (browser: blob URL). `importer(text)` may be injected
// for non-browser hosts (bun tests write the text to a file and import it).
export async function loadSurfaceModule(text, { zodUrl = ZOD_URL, importer } = {}) {
  if (importer) return importer(text);
  const rewritten = text.replace(/from\s+(["'])zod\1/g, () => `from ${JSON.stringify(zodUrl)}`);
  const url = URL.createObjectURL(new Blob([rewritten], { type: "text/javascript" }));
  try {
    return await import(/* @vite-ignore */ url);
  } finally {
    URL.revokeObjectURL(url);
  }
}

let cached = null;
export function fetchSurfaceModule(opts = {}) {
  if (!cached) {
    cached = fetch(opts.artifactUrl ?? ARTIFACT_URL)
      .then((r) => (r.ok ? r.text() : r.json().then((e) => Promise.reject(new Error(e.message || e.error)))))
      .then((t) => loadSurfaceModule(t, opts))
      .catch((e) => {
        cached = null;
        throw e;
      });
  }
  return cached;
}

// "Playground.Blog.Post" + "create" -> "Post.create" (the artifact's SCHEMAS key).
export function actionId(resourceModule, actionName) {
  return `${String(resourceModule).split(".").pop()}.${actionName}`;
}

// Pure: validate a value against SCHEMAS[id]. Returns { ok } or { ok:false, kind, issues }.
export function validateWith(mod, id, value) {
  const schema = mod?.SCHEMAS?.[id];
  if (!schema) return { ok: false, kind: "no_schema", issues: [{ path: "", code: "unknown_action", message: id }] };
  const r = schema.safeParse(value);
  if (r.success) return { ok: true, issues: [] };
  return {
    ok: false,
    kind: "zod_issues",
    issues: r.error.issues.map((i) => ({ path: i.path.join("."), code: i.code, message: i.message })),
  };
}

// Same, from JSON text.
export function validateText(mod, id, text) {
  let value;
  try {
    value = JSON.parse(text);
  } catch (e) {
    return { ok: false, kind: "invalid_json", issues: [{ path: "", code: "json", message: String(e.message) }] };
  }
  return validateWith(mod, id, value);
}

// React hook: { ready, error, id, hasSchema, validate(payloadObject) -> {ok, issues} }.
export function useSurfaceValidator(resourceModule, actionName, opts) {
  const [state, setState] = useState({ mod: null, error: null });
  useEffect(() => {
    let live = true;
    fetchSurfaceModule(opts).then(
      (mod) => live && setState({ mod, error: null }),
      (error) => live && setState({ mod: null, error: error.message }),
    );
    return () => {
      live = false;
    };
  }, []);
  const id = actionId(resourceModule, actionName);
  return useMemo(
    () => ({
      id,
      ready: !!state.mod,
      error: state.error,
      hasSchema: !!state.mod?.SCHEMAS?.[id],
      validate: (value) => validateWith(state.mod, id, value),
    }),
    [state, id],
  );
}
