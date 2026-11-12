#!/usr/bin/env bash
# Court 1: zod_type.ex numeric `.min(` -> `.max(` must flip schema_constraint_test red.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
T="$MIXT test/ash_surface/compiler/schema_constraint_test.exs --only describe:\"numeric min/max on numeric kinds\""
apply_shim() { shim_sub 's/"\.#\{zod\}\(#\{value\}\)"/".max(#{value})"/' '#'; }
shim_court_run lib/ash_surface/compiler/zod_type.ex "$(shim_green "$T")" "$(shim_red "$T")"
