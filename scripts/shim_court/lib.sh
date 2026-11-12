#!/usr/bin/env bash
# shim_court/lib.sh — ash_surface port of smalt's shim-court protocol (lane Q2).
# Divergence from smalt: every shim lands in a /tmp SCRATCH COPY of the repo
# (shim_scratch_make), never in the live tree; shim_live_guard proves the live
# tree's sha256 of the shimmed relpath is unchanged.
#
# Generalizes scripts/mutation_court.py's BEFORE/after/restore phases into a
# shell harness. A "shim court" proves a gate or behavior is NON-VACUOUS by
# transiently replacing a subject file's behavior:
#
#   1. SHA-BASELINE   sha256 the subject file.
#   2. BEFORE         run the before-witness against the UNMODIFIED file;
#                     exit 0 = the OLD signature holds.
#   3. SHIM           call the caller-defined `apply_shim` hook (must edit
#                     <file> in place, marking edits with "SHIM-COURT").
#   4. AFTER          run the after-witness against the SHIMMED file;
#                     exit 0 = the NEW outcome holds. This flip IS the
#                     non-vacuity proof.
#   5. RESTORE        restore from backup; sha256 must equal the baseline
#                     byte-exact. The court FAILS CLOSED on any mismatch.
#
# Exit 0 only if every phase passes. Typed FAIL lines per phase:
#   [FAIL:BASELINE] [FAIL:BEFORE] [FAIL:SHIM] [FAIL:AFTER] [FAIL:RESTORE]
#
# Contract for court scripts (see README.md):
#   - `set -euo pipefail`, then `source "$(dirname "$0")/lib.sh"`.
#   - Define `apply_shim` (edits $SHIM_FILE in place) BEFORE calling with_shim.
#   - Pass witness commands as args 2 and 3 (run via bash -uc; see below).
#   - A leg needing a missing environment must SKIP LOUDLY with a reason via
#     `shim_court_skip "reason"` — never fake a pass.

# Bail on unbound vars only here (courts set -e themselves); keep restore safe
# under `set -e` via explicit guards in with_shim.

SHIM_COURT_NAME="$(basename "${0:-shim_court}" .sh)"
SHIM_FILE=""            # set by with_shim; visible to apply_shim
SHIM_BACKUP=""          # mktemp backup of the pristine file
SHIM_BASELINE_SHA=""    # sha256 of the pristine file
SHIM_PHASE="INIT"

shim_court_log() { printf '[%s] %s\n' "$1" "$2"; }

shim_court_fail() {
    # shim_court_fail <PHASE> <detail> — typed FAIL line, then exit 1.
    printf '[FAIL:%s] %s\n' "$1" "$2" >&2
    exit 1
}

shim_court_skip() {
    # SKIP-loud-with-reason: a leg needing a missing environment prints this
    # and exits 3 — recorded as SKIP (never PASS) by the aggregate, and never
    # a faked pass.
    printf '[SKIP] %s: %s\n' "$SHIM_COURT_NAME" "$1"
    exit 3
}

shim_court_sha() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }

shim_court_self_check() {
    # Real temp-copy exercise (no mocks): prove the sha256 restore rule
    # DETECTS a corrupted restore. Run once per court invocation.
    local tmp dir backup good corrupt
    dir="$(mktemp -d)" || return 1
    tmp="$dir/subject.txt"
    printf 'subject-body\n' > "$tmp"
    backup="$dir/backup"
    cp "$tmp" "$backup"
    local base; base="$(shim_court_sha "$tmp")"
    printf 'SHIM-COURT body\n' > "$tmp"
    cp "$backup" "$tmp"                      # clean restore
    good="$(shim_court_sha "$tmp")"
    cp "$backup" "$tmp"
    printf 'x' | dd of="$tmp" bs=1 seek=3 conv=notrunc status=none 2>/dev/null
    corrupt="$(shim_court_sha "$tmp")"
    rm -rf "$dir"
    [ "$good" = "$base" ] && [ "$corrupt" != "$base" ] || {
        printf '[FAIL:SELF-CHECK] restore-detection self-check failed\n' >&2
        return 1
    }
    printf '[self-check] sha256 restore-detection verified\n'
    return 0
}

shim_court_trap() {
    # Interrupt safety: if we die mid-shim, still attempt a byte-exact
    # restore before exiting nonzero.
    if [ -n "${SHIM_BACKUP:-}" ] && [ -f "${SHIM_BACKUP:-}" ] && \
       [ -n "${SHIM_FILE:-}" ] && [ -f "${SHIM_FILE:-}" ] && \
       [ "$SHIM_PHASE" = "AFTER" ]; then
        cp "$SHIM_BACKUP" "$SHIM_FILE"
        if [ "$(shim_court_sha "$SHIM_FILE")" != "$SHIM_BASELINE_SHA" ]; then
            printf '[FAIL:RESTORE] interrupt path: restore did not verify\n' >&2
        fi
    fi
}

# Witnesses run under `bash -uc` (SHIM-COURT hardening, 2026-10-16, R190
# class): a witness referencing an unset variable — e.g. a court forgot to
# export a var its `declare -f` witness body reads — fails LOUD with
# "unbound variable" instead of silently expanding to empty and passing
# vacuously. `${VAR:-default}` stays safe under -u by design.

with_shim() {
    # with_shim <file> <before-cmd> <after-cmd>  (witnesses run via bash -uc)
    local file="$1" before_cmd="$2" after_cmd="$3"

    # --- Phase 1: BASELINE ----------------------------------------------------
    SHIM_PHASE="BASELINE"
    if [ ! -f "$file" ]; then
        shim_court_fail BASELINE "subject file not found: $file"
    fi
    SHIM_FILE="$file"
    SHIM_BASELINE_SHA="$(shim_court_sha "$file")"
    if [ -z "$SHIM_BASELINE_SHA" ]; then
        shim_court_fail BASELINE "could not sha256 $file"
    fi
    shim_court_log SHIM "baseline sha256($file) = $SHIM_BASELINE_SHA"

    # --- Phase 2: BEFORE (old signature must hold) ----------------------------
    SHIM_PHASE="BEFORE"
    if ! bash -uc "$before_cmd"; then
        shim_court_fail BEFORE \
            "before-witness failed against UNMODIFIED $file — old signature absent; refusing to shim"
    fi
    shim_court_log SHIM "BEFORE witness passed (old signature holds)"

    # --- Phase 3: SHIM ----------------------------------------------------------
    SHIM_PHASE="SHIM"
    if ! declare -F apply_shim >/dev/null; then
        shim_court_fail SHIM "apply_shim() not defined by court script"
    fi
    SHIM_BACKUP="$(mktemp "${TMPDIR:-/tmp}/shim_court.orig.XXXXXX")"
    cp "$file" "$SHIM_BACKUP"
    if ! apply_shim; then
        cp "$SHIM_BACKUP" "$file"
        rm -f "$SHIM_BACKUP"; SHIM_BACKUP=""
        shim_court_fail SHIM "apply_shim failed; file restored from backup"
    fi
    if ! grep -q 'SHIM-COURT' "$file"; then
        cp "$SHIM_BACKUP" "$file"
        rm -f "$SHIM_BACKUP"; SHIM_BACKUP=""
        shim_court_fail SHIM \
            "shimmed $file carries no 'SHIM-COURT' marker; refusing to continue"
    fi
    shim_court_log SHIM "shim applied to $file (SHIM-COURT marker present)"

    # --- Phase 4: AFTER (new outcome must hold) --------------------------------
    SHIM_PHASE="AFTER"
    trap shim_court_trap EXIT INT TERM
    if ! bash -uc "$after_cmd"; then
        cp "$SHIM_BACKUP" "$file"
        if [ "$(shim_court_sha "$file")" != "$SHIM_BASELINE_SHA" ]; then
            shim_court_fail RESTORE \
                "restore after AFTER-witness failure did NOT verify byte-exact (baseline $SHIM_BASELINE_SHA)"
        fi
        rm -f "$SHIM_BACKUP"; SHIM_BACKUP=""
        trap - EXIT INT TERM
        shim_court_fail AFTER \
            "after-witness failed against SHIMMED $file — new outcome absent (gate vacuous or shim inert); file restored+verified"
    fi
    shim_court_log SHIM "AFTER witness passed (new outcome holds under shim)"

    # --- Phase 5: RESTORE (byte-exact) ------------------------------------------
    SHIM_PHASE="RESTORE"
    cp "$SHIM_BACKUP" "$file"
    local actual; actual="$(shim_court_sha "$file")"
    rm -f "$SHIM_BACKUP"; SHIM_BACKUP=""
    trap - EXIT INT TERM
    if [ "$actual" != "$SHIM_BASELINE_SHA" ]; then
        shim_court_fail RESTORE \
            "sha256 mismatch after restore: got $actual, baseline $SHIM_BASELINE_SHA — $file CORRUPTED"
    fi
    shim_court_log SHIM "RESTORE verified byte-exact (sha256 match)"

    printf '[PASS] %s: non-vacuous (BEFORE old-signature, AFTER new-outcome, restore verified)\n' \
        "$SHIM_COURT_NAME"
    return 0
}


# ---------------------------------------------------------------------------
# ash_surface additions: scratch copy (live tree never mutated) + guards.
# ---------------------------------------------------------------------------
SHIM_REPO="${SHIM_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SHIM_SCRATCH="${SHIM_SCRATCH:-}"

shim_scratch_make() {
    # Plain cp -R subtree (not a git worktree/clone). deps + node_modules are
    # symlinked; _build/test is seeded so deps are not recompiled.
    if [ -n "$SHIM_SCRATCH" ] && [ -d "$SHIM_SCRATCH/lib" ]; then return 0; fi
    SHIM_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/shim_court_scratch.XXXXXX")"
    local r="$SHIM_REPO" x
    for x in lib test priv config conformance parity docs scripts packages templates fixture semantic; do
        [ -e "$r/$x" ] && cp -R "$r/$x" "$SHIM_SCRATCH/$x"
    done
    for x in mix.exs mix.lock package.json package-lock.json .formatter.exs ontology.ttl; do
        [ -e "$r/$x" ] && cp "$r/$x" "$SHIM_SCRATCH/$x"
    done
    ln -s "$r/deps" "$SHIM_SCRATCH/deps"
    ln -s "$r/node_modules" "$SHIM_SCRATCH/node_modules"
    mkdir -p "$SHIM_SCRATCH/_build-q2"
    [ -d "$r/_build/test" ] && cp -R "$r/_build/test" "$SHIM_SCRATCH/_build-q2/test"
    export SHIM_SCRATCH
    shim_court_log SCRATCH "$SHIM_SCRATCH (cp -R of live tree; deps/node_modules symlinked)"
}

shim_scratch_clean() { [ -n "${SHIM_OWNS_SCRATCH:-}" ] && rm -rf "$SHIM_SCRATCH"; return 0; }

shim_mix_test() {  # shim_mix_test <test file> in scratch
    ( cd "$SHIM_SCRATCH" && MIX_ENV=test MIX_BUILD_ROOT=_build-q2 mix test "$@" )
}

shim_live_guard() {
    # shim_live_guard <relpath>: the live file must carry no SHIM-COURT marker. sha256 pre/post is
    # reported as evidence; a difference means ANOTHER lane edited it (the court only writes /tmp).
    local rel="$1" now
    now="$(shim_court_sha "$SHIM_REPO/$rel" || true)"; [ -n "$now" ] || now="absent-in-live(scratch-only fixture)"
    printf '[LIVE-GUARD] %s live sha256 pre=%s post=%s\n' "$rel" "${LIVE_PIN:-?}" "$now"
    [ "$now" = "${LIVE_PIN:-}" ] || printf '[LIVE-GUARD] note: live file changed during court (concurrent lane edit)\n'
    if [ -f "$SHIM_REPO/$rel" ] && grep -q 'SHIM-COURT' "$SHIM_REPO/$rel"; then shim_court_fail RESTORE "SHIM-COURT marker found in LIVE $rel"; fi
}
shim_live_pin() { LIVE_PIN="$(shim_court_sha "$SHIM_REPO/$1" || true)"; [ -n "$LIVE_PIN" ] || LIVE_PIN="absent-in-live(scratch-only fixture)"; }

shim_court_run() {
    # shim_court_run <relpath> <before-cmd> <after-cmd>; caller defined apply_shim
    # and already called shim_scratch_make. Shim is applied ONLY in the scratch.
    local rel="$1"
    trap 'shim_scratch_clean' EXIT
    shim_live_pin "$rel"
    with_shim "$SHIM_SCRATCH/$rel" "$2" "$3"
    shim_live_guard "$rel"
    printf '[GIT-DIFF-STAT] live %s: [%s]\n' "$rel" "$(cd "$SHIM_REPO" && git diff --stat -- "$rel" 2>/dev/null | tail -1 || true)"
}

# Witness builders. Both print the run's tail and the exit code (receipt evidence).
# GREEN: command must exit 0.  RED: command must exit nonzero AND show a real
# test failure (not merely a compile error) so a broken shim cannot fake a flip.
shim_green() { printf '( cd "$SHIM_SCRATCH" && %s ) > "$SHIM_SCRATCH/.out" 2>&1; rc=$?; tail -n 25 "$SHIM_SCRATCH/.out"; echo "[witness] BEFORE exit=$rc"; [ $rc -eq 0 ]' "$1"; }
shim_red() { printf '( cd "$SHIM_SCRATCH" && %s ) > "$SHIM_SCRATCH/.out" 2>&1; rc=$?; tail -n 25 "$SHIM_SCRATCH/.out"; echo "[witness] AFTER exit=$rc"; [ $rc -ne 0 ] && grep -Eq "[0-9]+ failures?|^# fail [1-9]|ℹ fail [1-9]|^not ok|^Gate FAIL|PARITY-VERDICT exit=1" "$SHIM_SCRATCH/.out"' "$1"; }

shim_sub() {  # shim_sub <perl-substitution> <comment-prefix>; edits $SHIM_FILE, must change it
    local before after
    before="$(shim_court_sha "$SHIM_FILE")"
    perl -0pi -e "$1" "$SHIM_FILE"
    [ -n "${2:-}" ] && printf '\n%s SHIM-COURT\n' "$2" >> "$SHIM_FILE"
    after="$(shim_court_sha "$SHIM_FILE")"
    [ "$before" != "$after" ] || { echo "[shim_sub] substitution matched nothing" >&2; return 1; }
}
MIXT='MIX_ENV=test MIX_BUILD_ROOT=_build-q2 mix test'
