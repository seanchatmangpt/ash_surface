#!/usr/bin/env bash
# ci_falsifier.sh — bounded mutation falsifier for CI (ticket chicago-ci-falsifier-049).
#
# Law: a guard that cannot fail guards nothing. For each recipe in
# scripts/mutation_recipes.md this script mutates the REAL subject, demands the
# guarding test turn RED, restores the subject, and demands GREEN again. A
# mutation the guard survives (or a restore that does not heal) fails the job:
# the guard is dead, or the recipe is mis-wired. Tripwire canaries must be
# GREEN on pristine HEAD before any mutation runs.
#
# Fail-closed: refuses a dirty tracked tree (restore must be lossless), refuses
# a mutation that did not land, and prints FALSIFIER_OK only when every proof
# held. Exits 0 only on that line. Runtime bound: ~1 compile + 7 narrow
# `mix test` invocations (CI job pins timeout-minutes: 5).
set -Eeuo pipefail

FALSIFIER_FAIL_MSG=""
fail() {
  FALSIFIER_FAIL_MSG="FALSIFIER_FAIL: $*"
  echo "$FALSIFIER_FAIL_MSG" >&2
  exit 1
}
trap 'rc=$?; [ $rc -eq 0 ] || echo "FALSIFIER_FAIL: error exit $rc at line $LINENO" >&2' ERR

repo_root=$(git rev-parse --show-toplevel) || fail "not inside a git work tree"
cd "$repo_root"

# The restore step is `git checkout -- <subject>`; a dirty tracked tree would
# make that restore destroy uncommitted work. Refuse instead.
[ -z "$(git status --porcelain --untracked-files=no)" ] ||
  fail "tracked tree is dirty; falsifier refuses to run (restore must be lossless)"

tmpdir=$(mktemp -d)
mutated_subject=""
# Self-healing: if this run dies mid-recipe (dead guard, failed restore,
# interrupt), put the subject back so neither CI nor a local tree keeps the
# mutation. A clean EXIT path has already restored + verified it.
trap 'rm -rf "$tmpdir"; [ -z "$mutated_subject" ] || git checkout -- "$mutated_subject"' EXIT

# run_guard <label> <files...>: runs the guard subset, prints its verdict tail
# and EXIT[label]=code. Echoes nothing else on stdout.
run_guard() {
  local label="$1"
  shift
  local rc=0
  mix test "$@" >"$tmpdir/guard.log" 2>&1 || rc=$?
  echo "EXIT[$label]=$rc"
  tail -n 2 "$tmpdir/guard.log"
  return $rc
}

# guard_is_red: non-zero exit AND ExUnit reported assertion failures (a compile
# error of the subject is not a detection — the guard must fail assertions).
# Format is the ExUnit verdict line: `Failed: 1 test` / `Failed: 2 tests`
# (older ExUnit: `N failures`).
guard_is_red() {
  grep -Eq '^Failed: [0-9]+ tests?| [0-9]+ failures?' "$tmpdir/guard.log"
}

# assert_mutated <probe-cmd>: the mutation MUST land; a silent no-op would let
# a dead guard masquerade as alive.
assert_mutated() {
  "$@" || fail "mutation did not land: $*"
}

# ---- 1. tripwire canaries on pristine HEAD --------------------------------
echo "==> canaries: standing tripwire suites must be GREEN on HEAD"
run_guard canaries \
  test/ash_surface/no_local_do_test.exs \
  test/ash_surface/handwritten_ledger_test.exs \
  test/ash_surface/standing_test.exs \
  test/ash_surface/transport_falsifiers_test.exs \
  test/ash_surface/refactor_safety_net_test.exs ||
  fail "tripwire canary RED on pristine HEAD"

# ---- 2. mutation recipes: RED under mutation, GREEN after restore ----------
# name|subject|guard-file (recipes documented in scripts/mutation_recipes.md)
recipes=(
  "runtime-sha-whitespace|priv/static/ash_surface_runtime.mjs|test/ash_surface/runtime_source_test.exs"
  "digest-hexcase-flip|lib/ash_surface.ex|test/ash_surface/digest_test.exs"
  "irgolden-presentation-fielddrop|test/ash_surface/ir_codec_golden_test.exs|test/ash_surface/ir_codec_golden_test.exs"
)

for row in "${recipes[@]}"; do
  IFS='|' read -r name subject guard <<<"$row"
  echo "==> recipe $name: mutate $subject, demand RED from $guard"

  bytes_before=$(wc -c <"$subject" | tr -d ' ')
  case "$name" in
    runtime-sha-whitespace)
      printf '\n' >>"$subject"
      assert_mutated [ "$bytes_before" -lt "$(wc -c <"$subject" | tr -d ' ')" ]
      ;;
    digest-hexcase-flip)
      perl -pi -e 's/Base\.encode16\(case: :lower\)/Base.encode16(case: :upper)/' "$subject"
      assert_mutated grep -q 'Base.encode16(case: :upper)' "$subject"
      ;;
    irgolden-presentation-fielddrop)
      # \@ in the replacement: perl would otherwise interpolate
      # @presentation_fields as an (empty) array and mangle the line.
      perl -pi -e 's/\@presentation_fields ~w\(format group label order widget\)/\@presentation_fields ~w(format group order widget)/' "$subject"
      assert_mutated grep -q '@presentation_fields ~w(format group order widget)' "$subject"
      ;;
    *)
      fail "unknown recipe: $name"
      ;;
  esac
  mutated_subject="$subject"

  # `|| rc=$?`: keeps the expected guard failure out of both set -e and the
  # ERR trap — a RED guard is this recipe's demanded outcome, not an error.
  rc=0
  run_guard "red:$name" "$guard" || rc=$?
  [ "$rc" -ne 0 ] || fail "guard survived mutation (dead guard): $name"
  guard_is_red || fail "guard failed without reporting failures (compile error, not detection): $name"

  mutated_subject=""
  git checkout -- "$subject"
  [ -z "$(git status --porcelain --untracked-files=no -- "$subject")" ] ||
    fail "restore left $subject mutated"

  run_guard "green:$name" "$guard" ||
    fail "guard still RED after restore: $name"
done

# ---- 3. no residue ---------------------------------------------------------
[ -z "$(git status --porcelain --untracked-files=no)" ] ||
  fail "falsifier left residue in the tracked tree"

echo "FALSIFIER_OK"
