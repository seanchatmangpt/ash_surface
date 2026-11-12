#!/usr/bin/env bash
# run_all.sh — run every shim court against ONE shared scratch copy; aggregate PASS/FAIL/SKIP.
# Exit 1 on any FAIL; SKIPs are loud and counted, never PASS.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
SHIM_OWNS_SCRATCH=1
shim_scratch_make
trap 'shim_scratch_clean' EXIT
pass=0; fail=0; skip=0
for c in "$here"/courts/*.sh; do
  echo "=== $(basename "$c")"
  bash "$c"; rc=$?
  case $rc in 0) pass=$((pass+1));; 3) skip=$((skip+1));; *) fail=$((fail+1)); echo "[FAIL] $(basename "$c") rc=$rc";; esac
done
echo "SUMMARY pass=$pass fail=$fail skip=$skip"
[ "$fail" -eq 0 ]
