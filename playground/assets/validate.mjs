// Loads the EMITTED artifact text as a real ES module whose `zod` import is
// rewired to the bundled zod (/assets/zod.mjs), then validates with SCHEMAS.
export async function loadSchemas(artifactText, zodUrl) {
  const rewritten = artifactText.replace(
    /from\s+(["'])zod\1/g,
    () => `from ${JSON.stringify(zodUrl)}`,
  );
  const blob = new Blob([rewritten], { type: "text/javascript" });
  const url = URL.createObjectURL(blob);
  try {
    return await import(/* @vite-ignore */ url);
  } finally {
    URL.revokeObjectURL(url);
  }
}

export function makeValidator(mod) {
  return (actionId, text) => {
    let value;
    try {
      value = JSON.parse(text);
    } catch (e) {
      return { ok: false, kind: "invalid JSON", issues: [{ path: "", code: "json", message: String(e.message) }] };
    }
    const schema = mod.SCHEMAS[actionId];
    if (!schema) {
      return { ok: false, kind: "no schema for action", issues: [{ path: "", code: "unknown_action", message: actionId }] };
    }
    const r = schema.safeParse(value);
    if (r.success) return { ok: true };
    return {
      ok: false,
      kind: "zod issues",
      issues: r.error.issues.map((i) => ({ path: i.path.join("."), code: i.code, message: i.message })),
    };
  };
}
