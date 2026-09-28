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
# held. Exits 0 only on that line. Runtime bound: 1 compile + 2 narrow
# guard runs per recipe (CI job pins timeout-minutes: 5; measured in the report).
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
# and EXIT[label]=code. Echoes nothing else on stdout. `*.mjs` files run under
# `node --test` (the behavioural JS suites); everything else under `mix test`.
run_guard() {
  local label="$1"
  shift
  local rc=0
  case "$1" in
    *.mjs) node --test "$@" >"$tmpdir/guard.log" 2>&1 || rc=$? ;;
    *) mix test "$@" >"$tmpdir/guard.log" 2>&1 || rc=$? ;;
  esac
  echo "EXIT[$label]=$rc"
  tail -n 2 "$tmpdir/guard.log"
  return $rc
}

# guard_is_red: non-zero exit AND the runner reported assertion failures (a
# compile/import error of the subject is not a detection — the guard must fail
# assertions). ExUnit: `Failed: 1 test` (older: `N failures`); node:test:
# `# fail N` / `ℹ fail N` with N >= 1.
guard_is_red() {
  grep -Eq '^Failed: [0-9]+ (tests?|propert(y|ies))| [0-9]+ failures?|^(#|ℹ) fail [1-9]' "$tmpdir/guard.log"
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
# Every recipe is a BEHAVIOURAL or guard-removing mutation: the named guard is
# a behaviour test, never a byte-change detector. `.mjs` guards need
# `npm install` (zod) first; the CI falsifier job does that.
recipes=(
  "rt-post-dispatch-classification|priv/static/ash_surface_runtime.mjs|test/js/transport_law.test.mjs"
  "rt-known-transports-order|priv/static/ash_surface_runtime.mjs|test/js/transport_law.test.mjs"
  "rt-null-prototype-registry|priv/static/ash_surface_runtime.mjs|test/js/runtime_hardening.test.mjs"
  "digest-hexcase-flip|lib/ash_surface.ex|test/ash_surface/digest_test.exs"
  "from-manifest-refused-prefix|lib/ash_surface.ex|test/ash_surface/boundary_hardening_test.exs"
  "irgolden-presentation-fielddrop|test/ash_surface/ir_codec_golden_test.exs|test/ash_surface/ir_codec_golden_test.exs"
  "event-digest-second-slot|lib/ash_surface/ir/event_projection.ex|test/ash_surface/boundary_hardening_test.exs"
  "transport-duplicate-check|lib/ash_surface/transport.ex|test/ash_surface/transport_coverage_test.exs"
  "zodguard-allow-constructor|lib/ash_surface/projectors/js/zod_guard.ex|test/ash_surface/decode_boundary_zod_guard_test.exs"
  "js-namespace-collision|lib/ash_surface/projectors/js.ex|test/ash_surface/projector_hardening_test.exs"
  "mx-verifier-timeout|lib/ash_surface/mx_episode.ex|test/ash_surface/mx_episode_verify_hardening_test.exs"
)

for row in "${recipes[@]}"; do
  IFS='|' read -r name subject guard <<<"$row"
  echo "==> recipe $name: mutate $subject, demand RED from $guard"

  case "$name" in
    rt-post-dispatch-classification)
      # Post-dispatch failure must classify UNKNOWN_AFTER_DISPATCH; always
      # reporting SUCCESS would let a timed-out call look settled.
      perl -pi -e 's/const outcome = dispatchState === "completed"[^;]*;/const outcome = "SUCCESS";/' "$subject"
      assert_mutated grep -q 'const outcome = "SUCCESS";' "$subject"
      ;;
    rt-known-transports-order)
      # Transport selection order under "auto" is the http-first frontier.
      perl -pi -e 's/Object\.freeze\(\["http", "phoenix_channel"\]\)/Object.freeze(["phoenix_channel", "http"])/' "$subject"
      assert_mutated grep -q 'KNOWN_TRANSPORTS = Object.freeze(\["phoenix_channel", "http"\])' "$subject"
      ;;
    rt-null-prototype-registry)
      # A plain-object action registry lets id "constructor"/"__proto__"
      # resolve through Object.prototype.
      perl -pi -e 's/const actions = Object\.create\(null\);/const actions = {};/' "$subject"
      assert_mutated grep -q 'const actions = {};' "$subject"
      ;;
    digest-hexcase-flip)
      perl -pi -e 's/Base\.encode16\(case: :lower\)/Base.encode16(case: :upper)/' "$subject"
      assert_mutated grep -q 'Base.encode16(case: :upper)' "$subject"
      ;;
    from-manifest-refused-prefix)
      # The REFUSED_-prefix admission branch of from_manifest's per-action
      # profile validation is disabled: a non-refusal string would become an
      # admissible "possible refusal" (the JS runtime would then reject the
      # contract Elixir emitted).
      perl -pi -e 's/bad = Enum\.reject\(refusals, &refusal_code\?\/1\)[^\n]*->\s*$/bad = nil ->/' "$subject"
      assert_mutated grep -q '^ *bad = nil ->' "$subject"
      ;;
    irgolden-presentation-fielddrop)
      # Re-pointed at the live golden assertion (the old @presentation_fields
      # attribute left with the blue-river-dam merge): drop one expected
      # presentation field so the golden suite's own field-shape assert goes RED.
      perl -pi -e 's/assert fields\.\(IR\.Presentation\) == ~w\(format group label order widget\)a/assert fields.(IR.Presentation) == ~w(format group order widget)a/' "$subject"
      assert_mutated grep -q 'assert fields.(IR.Presentation) == ~w(format group order widget)a' "$subject"
      ;;
    event-digest-second-slot)
      # Drop the receiptRef slot from digest binding: a tampered digest moved
      # into the second slot would project.
      perl -pi -e 's/\[\[:receipt_hash, "receiptHash"\], \[:receipt_ref, "receiptRef"\]\]/[[:receipt_hash, "receiptHash"]]/' "$subject"
      assert_mutated grep -q '\[\[:receipt_hash, "receiptHash"\]\]' "$subject"
      ;;
    transport-duplicate-check)
      perl -pi -e 's/^(\s*)duplicates != \[\] ->/$1false ->/' "$subject"
      assert_mutated grep -q '^ *false ->' "$subject"
      ;;
    zodguard-allow-constructor)
      perl -pi -e 's/\@denied_members ~w\(constructor prototype call apply bind\)/\@denied_members ~w(prototype call apply bind)/' "$subject"
      assert_mutated grep -q '@denied_members ~w(prototype call apply bind)' "$subject"
      ;;
    js-namespace-collision)
      perl -pi -e 's/\{short, many\} -> \{:error, \{:js_namespace_collision, short, many\}\}/{_short, _many} -> nil/' "$subject"
      assert_mutated grep -q '{_short, _many} -> nil' "$subject"
      ;;
    mx-verifier-timeout)
      # A hung verifier that never times out would block forever; the mutation
      # makes the timeout branch report success instead of the typed refusal.
      perl -pi -e 's/\{:error, \{:verifier_timeout, timeout\}\}/{:ok, {"", 0}}/' "$subject"
      assert_mutated grep -q '{:ok, {"", 0}}' "$subject"
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
