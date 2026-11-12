#!/usr/bin/env bash
# Court 4: errors.ex stops redacting Policy errors -> errors tests red.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
T="$MIXT test/ash_surface/errors_test.exs test/ash_surface/errors_config_test.exs test/ash_surface/errors_s1b_test.exs"
apply_shim() { shim_sub 's/%Ash\.Error\.Forbidden\.Policy\{\} when show_policy\? ->/%Ash.Error.Forbidden.Policy{} ->/' '#'; }
shim_court_run lib/ash_surface/errors.ex "$(shim_green "$T")" "$(shim_red "$T")"
