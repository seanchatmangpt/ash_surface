# L08 runtime issues

Lane L08 (v26.11.11): mirror the INPUT_VALIDATION_FAILED issue mapping in the
hand-authored JS runtime (`priv/static/ash_surface_runtime.mjs`), per the L07
envelope law.

## Law

On Zod `safeParse` failure the runtime throws a `SurfaceRuntimeError` whose
`issues` array is the **normalized** shape — never raw Zod issues:

```js
{ path: "surface.actions.0.authorityBoundary" // dot-joined string
, message: "Invalid enum value..."
, code: "invalid_enum_value" }
```

## Sites

| Site | Code | Before | After |
|---|---|---|---|
| `prepareDispatch` input (~596) | INPUT_VALIDATION_FAILED | throwing `.parse()`, issues only in `cause` | `safeParse`, `issues` normalized, `cause` kept |
| `executeDispatch` output (~715) | OUTPUT_VALIDATION_FAILED | throwing `.parse()` | `safeParse`, normalized, receipt + `outputValid:false` emit kept |
| reconcile reply (~472) | INVALID_RECONCILE_RESULT | raw `parsed.error.issues` | normalized |
| contract (~548) | INVALID_SURFACE_CONTRACT | raw issues | normalized |
| idempotency profile (~993) | INVALID_IDEMPOTENCY_PROFILE | raw issues | normalized |

Helper: `toValidationIssues(zodIssues)` (~line 298). JSDoc: `ValidationIssue`
typedef added; `ActionSchemas` typedef now types the `safeParse` contract.

## Constraints honored

- Payload-free onEvent law: refusal events still emit only `{actionId, code}`;
  issues never enter events.
- `VOCABULARY` export unchanged (no issue-vocabulary field exists).
- `lib/ash_surface/vocabulary.ex` untouched (out of lane scope).

## See Also

`receipts/L08.md` · L07 envelope-law lane
