# Wave 3 Lane 18: AshSurface.digest/1 and Transport.classify_failure/2

Standing: PARTIAL_ALIVE

## Files

- lib/ash_surface.ex: replaced `defp digest/1` with public `def digest/1` (delegates to
  `AshSurface.Digest.content_digest/1`; `contract_digest/1` unchanged).
- lib/ash_surface/transport.ex: added `classify_failure/2` (`:pre_dispatch` ->
  `:not_dispatched`, fallback open; `:post_dispatch` -> `:unknown_after_dispatch`, no
  fallback; other phase -> `{:error, :unknown_phase}`).
- test/ash_surface/digest_api_test.exs, test/ash_surface/transport_classify_test.exs (new).

## Commands

`MIX_BUILD_ROOT=_build-w318 mix test test/conformance test/ash_surface/digest_api_test.exs
test/ash_surface/transport_classify_test.exs test/ash_surface/no_local_do_test.exs`
-> 31 tests, 2 failures. New tests (digest vs surface_contract_digest vectors, classify vs all
transport_outcome vectors, node-executed VOCABULARY twin) and no_local_do pass.

The 2 failures are in test/conformance/conformance_replay_test.exs and come from other
lanes' in-flight conformance edits: `constraints.json c/match-backslash` zod drift, and
MANIFEST corpusVersion "1.0.0" vs Runner "2.0.0". Not touched by this lane.

## Closed gaps (for lane w3-04 / CONFORMANCE.md D-17)

1. Public `AshSurface.digest/1`: closed.
2. `AshSurface.Transport.classify_failure/2`: closed.

## UNVERIFIED

- Pre-change conformance replay baseline was not captured (the edit preceded the first run).
- Moduledoc mention of the two functions is in the function docs, not the module header.

## Requests

- Owner of conformance corpus: reconcile corpusVersion and the c/match-backslash vector.
