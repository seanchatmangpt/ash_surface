#!/usr/bin/env bash
# Court 2: union_schema.ex drops the discriminator literal -> union_schema_test red.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
T="$MIXT test/ash_surface/compiler/union_schema_test.exs"
apply_shim() { shim_sub 's/z\.object\(\{\#\{key\(field\)\}: z\.literal\(\#\{lit\(name\)\}\), value:/z.object({#{key(field)}: z.string(), value:/' '#'; }
shim_court_run lib/ash_surface/compiler/union_schema.ex "$(shim_green "$T")" "$(shim_red "$T")"
