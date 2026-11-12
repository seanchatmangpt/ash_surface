#!/usr/bin/env bash
# Court 5: runtime.mjs flips dispatch outcome classification -> transport_law.test.mjs red.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
T="node --test test/js/transport_law.test.mjs"
apply_shim() { shim_sub 's/dispatchState === "completed" \? DISPATCH_OUTCOMES\[0\] : DISPATCH_OUTCOMES\[1\]/dispatchState !== "completed" ? DISPATCH_OUTCOMES[0] : DISPATCH_OUTCOMES[1]/' '//'; }
shim_court_run priv/static/ash_surface_runtime.mjs "$(shim_green "$T")" "$(shim_red "$T")"
