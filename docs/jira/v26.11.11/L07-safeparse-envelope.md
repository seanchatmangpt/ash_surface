# L07 safeparse envelope

Scope: the generated `dispatchIntent` in `lib/ash_surface/projectors/js.ex` replaces the
raw throwing `action.schema.parse(input)` with `schema.safeParse(input)`; on failure it
throws a `SurfaceRuntimeError`-compatible Error with `code: "INPUT_VALIDATION_FAILED"`
and `detail.issues = [{path (dot-joined), message, code}]` (the ash_typescript
`{type, fields, path}` shape made executable). REFUSED_UNKNOWN_ACTION /
REFUSED_NOT_DO_BOUNDARY refusals are unchanged and never carry the envelope code. The
emitted JS stays in the artifact's no-build JSDoc style with no new top-level
identifiers (identifier admission unaffected).

Test re-pins (premise rot on the old raw-ZodError leak): `test/js/ir_projection.test.mjs`,
`test/js/generated_js_projector_runner.mjs`, and the frozen golden byte-fixture
`test/js/ir_projector_deep.test.mjs` (inline ARTIFACT_SOURCE + FROZEN_SHA256 refreshed;
byte-parity against fresh projector output proven).

## See Also

`receipts/L07.md` · `lib/ash_surface/projectors/js.ex` ·
`priv/static/ash_surface_runtime.mjs` (SurfaceRuntimeError shape)
