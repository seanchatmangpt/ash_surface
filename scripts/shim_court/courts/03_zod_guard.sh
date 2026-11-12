#!/usr/bin/env bash
# Court 3: zod_guard.ex removes one allowed name (`min`) -> zod_guard_test red.
# (An allow-list guard: removing a name makes the admitted chain refuse.)
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
T="$MIXT test/ash_surface/projectors/js/zod_guard_test.exs"
apply_shim() { shim_sub 's/ date time datetime duration regex min max gt/ date time datetime duration regex max gt/' '#'; }
shim_court_run lib/ash_surface/projectors/js/zod_guard.ex "$(shim_green "$T")" "$(shim_red "$T")"
