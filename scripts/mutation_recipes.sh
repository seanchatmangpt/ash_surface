#!/usr/bin/env bash
# scripts/mutation_recipes.sh — Chicago falsifier for the three golden families
# (runtime SHA, contract digest, IR codec golden). Companion of
# scripts/mutation_recipes.md, which documents each recipe and its executed
# receipt.
#
# NOT wired to default CI. Run by hand, on a clean tree:
#
#   bash scripts/mutation_recipes.sh
#
# Per family: mutate the real subject -> guard RED -> restore -> guard GREEN.
# Prints EXIT[<step>]=<code> for every step; prints MUTATION_RECIPES_OK only
# when every RED was red and every GREEN green. Fails closed: a guard that
# stays green under mutation is a dead guard. An EXIT trap restores all three
# subjects even on failure — never commit a mutated state.

set -Eeuo pipefail

cd "$(dirname "$0")/.."

S1="priv/static/ash_surface_runtime.mjs"
S2="lib/ash_surface.ex"
S3="test/ash_surface/ir_codec_golden_test.exs"

G1="test/ash_surface/runtime_source_test.exs"
G2="test/ash_surface/digest_test.exs"
G3="$S3"

LOG="$(mktemp)"
trap 'rm -f "$LOG"; git checkout -- "$S1" "$S2" "$S3" 2>/dev/null || true' EXIT

fail() {
  echo "MUTATION_RECIPES_FAIL: $*" >&2
  exit 1
}

assert_clean() {
  [[ -z "$(git status --porcelain -- "$1")" ]] || fail "subject not clean, refusing to mutate: $1"
}

# expect <label> <0|nonzero> <command...> — run, print EXIT[label], verify verdict
expect() {
  local label="$1" want="$2"
  shift 2
  local got
  set +e
  "$@" >"$LOG" 2>&1
  got=$?
  set -e
  echo "EXIT[$label]=$got"
  grep -h "Result:" "$LOG" | tail -1 | sed "s/^/  $label: /" || true
  if [[ "$want" == "0" && "$got" -ne 0 ]]; then
    tail -20 "$LOG" >&2
    fail "$label: expected exit 0"
  elif [[ "$want" == "nonzero" && "$got" -eq 0 ]]; then
    fail "$label: expected nonzero exit — mutation did NOT fail the guard (dead guard)"
  fi
}

# --- preflight ----------------------------------------------------------
for subject in "$S1" "$S2" "$S3"; do assert_clean "$subject"; done

# --- baseline: all guards green before any mutation ----------------------
expect "BASELINE_COMPILE" 0 mix compile --warnings-as-errors
expect "BASELINE_G1" 0 mix test "$G1"
expect "BASELINE_G2" 0 mix test "$G2"
expect "BASELINE_G3" 0 mix test "$G3"

# --- family 1: runtime SHA — whitespace injection ------------------------
printf '\n' >> "$S1"
expect "M1_RED" nonzero mix test "$G1"
git checkout -- "$S1"
expect "M1_GREEN" 0 mix test "$G1"

# --- family 2: contract digest — field rename ----------------------------
perl -pi -e 's/"generatorIdentity" =>/"generatorIdentityRenamed" =>/' "$S2"
expect "M2_RED" nonzero mix test "$G2"
git checkout -- "$S2"
expect "M2_GREEN" 0 mix test "$G2"

# --- family 3: IR codec golden — field rename ----------------------------
perl -pi -e 's/"presentation" => section_to_map/"presentation_renamed" => section_to_map/' "$S3"
expect "M3_RED" nonzero mix test "$G3"
git checkout -- "$S3"
expect "M3_GREEN" 0 mix test "$G3"

# --- final cleanliness ----------------------------------------------------
for subject in "$S1" "$S2" "$S3"; do assert_clean "$subject"; done

echo "MUTATION_RECIPES_OK"
