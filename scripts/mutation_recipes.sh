#!/usr/bin/env bash
# scripts/mutation_recipes.sh — Chicago falsifier for the three golden families
# (runtime behaviour, contract digest, IR codec golden). Companion of
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

# Family 1 guard is BEHAVIOURAL (node:test, needs `npm install` for zod): the
# post-dispatch classification law. There is no runtime whole-file digest.
G1="test/js/transport_law.test.mjs"
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
expect "BASELINE_G1" 0 node --test "$G1"
expect "BASELINE_G2" 0 mix test "$G2"
expect "BASELINE_G3" 0 mix test "$G3"

# --- family 1: runtime behaviour — post-dispatch classification ----------
# Always reporting SUCCESS would let a timed-out/disconnected dispatch look
# settled (transport law: post-dispatch failure is UNKNOWN_AFTER_DISPATCH).
perl -pi -e 's/const outcome = dispatchState === "completed"[^;]*;/const outcome = "SUCCESS";/' "$S1"
grep -q 'const outcome = "SUCCESS";' "$S1" || fail "family 1 mutation did not land"
expect "M1_RED" nonzero node --test "$G1"
git checkout -- "$S1"
expect "M1_GREEN" 0 node --test "$G1"

# --- family 2: contract digest — field rename ----------------------------
perl -pi -e 's/"generatorIdentity" =>/"generatorIdentityRenamed" =>/' "$S2"
expect "M2_RED" nonzero mix test "$G2"
git checkout -- "$S2"
expect "M2_GREEN" 0 mix test "$G2"

# --- family 3: IR codec golden — expected-field drop ----------------------------
# The codec now lives in lib/; the golden pins its shape with a field-list
# assertion. Drop one expected presentation field so that assertion goes RED.
perl -pi -e 's/assert fields\.\(IR\.Presentation\) == ~w\(format group label order widget\)a/assert fields.(IR.Presentation) == ~w(format group order widget)a/' "$S3"
grep -q 'assert fields.(IR.Presentation) == ~w(format group order widget)a' "$S3" || fail "family 3 mutation did not land"
expect "M3_RED" nonzero mix test "$G3"
git checkout -- "$S3"
expect "M3_GREEN" 0 mix test "$G3"

# --- final cleanliness ----------------------------------------------------
for subject in "$S1" "$S2" "$S3"; do assert_clean "$subject"; done

echo "MUTATION_RECIPES_OK"
