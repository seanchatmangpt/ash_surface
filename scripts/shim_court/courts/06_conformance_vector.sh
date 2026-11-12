#!/usr/bin/env bash
# Court 6: alter one expected value in a scratch conformance vector -> replay red.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
T="node --test --test-name-pattern='post-dispatch failures' test/js/conformance_replay.test.mjs"
# JSON has no comments: the marker is embedded in the altered value itself.
apply_shim() { shim_sub 's/"failureOutcome":"UNKNOWN_AFTER_DISPATCH"/"failureOutcome":"SHIM-COURT-UNKNOWN"/' ''; }
shim_court_run conformance/vectors/transport_outcome.json "$(shim_green "$T")" "$(shim_red "$T")"
