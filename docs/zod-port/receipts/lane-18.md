# Lane 18 Receipt

Standing: PASS

## Files
- lib/ash_surface/projectors/js/inference.ex (new): `utility_types/0`, `resource_meta/2`, `emit/1`
- test/ash_surface/inference_test.exs (new)

## Commands
- `MIX_BUILD_ROOT=_build-lane18 mix test test/ash_surface/inference_test.exs` -> exit 0,
  "3 tests, 0 failures" (includes a real `tsc --noEmit --strict` run on the emitted block
  plus a `@ts-expect-error` negative case; tsc at /opt/homebrew/bin/tsc, test skips if absent).
- Initial run warned on heredoc indentation; fixed, re-run clean of warnings in tail.
- A manual ad hoc tsc run of `mix run` stdout was polluted by compile logs; not counted.
- `_build-lane18` deleted.

## Notes
- Block adapted from ash_typescript utility_types.ex with default field names
  (fields/filter/sort/page/limit/offset/count/after/before/args/results/hasMore/...).
- Artifact is NOT passed through ZodGuard. Resource names regex-validated, field names JSON-encoded.
- Output sorted, byte-deterministic.

## Requests
- Lane 15 (js.ex): add a separate artifact, e.g. `inference.d.ts` =
  `AshSurface.Projectors.JS.Inference.emit([{ResourceName, [%{name:, ts:, primitive?:}]}])`,
  not routed through ZodGuard. Lane 17 may need to supply per-resource field lists (`ts` text).

## Falsifiers
- Output differing between two `emit/1` calls; tsc failing on the block; a bad resource name accepted.
