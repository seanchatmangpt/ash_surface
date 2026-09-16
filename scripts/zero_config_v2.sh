#!/usr/bin/env bash
#
# zero_config_v2.sh — v2 fresh-clone battery (ticket zero-config-battery-002).
#
# WHAT IT PROVES
#   Everything scripts/zero_config_check.sh proves, plus the env-read guard
#   and `mix test.zero`: a pristine `git clone` of THIS worktree's HEAD
#   (local clone; git never touches the network) passes the FULL battery
#   with zero configuration beyond PATH and HOME:
#
#     1. env-read guard    — no file under test/ reads an environment
#                            variable outside the documented allowlist
#                            (@zero_env_allowlist in mix.exs). Reads are
#                            System.get_env / System.fetch_env! with a
#                            literal variable name; a read without a
#                            literal name fails closed (opaque read).
#     2. mix deps.get
#     3. npm install --no-audit — before mix test, same as v1: two mix e2e
#                            tests shell out to node and import 'zod' from
#                            node_modules.
#     4. mix test
#     5. npm test
#     6. mix test.zero     — if (and only if) the alias is defined in the
#                            clone's mix.exs; re-runs `mix test.all` under
#                            literal env -i with only the allowlist
#                            surviving. Absent alias => skipped, exit 0.
#
#   Every battery step prints `EXIT[<label>]=<code>` BEFORE the next step,
#   so the run log records every exit code (ticket acceptance).
#
# HERMETIC GUARD
#   Re-execs itself through `env -i PATH=... HOME=...` (plus a
#   ZERO_CONFIG_SANITIZED=1 recursion sentinel) — same as
#   scripts/zero_config_check.sh. No MIX_ENV, NPM_CONFIG_*, ASDF_*, HEX_*,
#   or any other caller configuration can leak in.
#
# FAILURE SEMANTICS
#   set -Eeuo pipefail; an ERR trap reports the failing command and exit
#   code. Any failure aborts BEFORE the ZERO_CONFIG_OK line, so the line
#   can never be printed for a broken tree.
#
# OFFLINE POLICY (zero-config != offline)
#   git is fully offline (local clone). Hex/npm may consult the network
#   for `mix deps.get` / `npm install` unless their user caches under HOME
#   are warm. Network failures there are network blockers, NOT zero-config
#   failures; the script never auto-skips them (no false ZERO_CONFIG_OK).
#
# USAGE
#   bash scripts/zero_config_v2.sh
#   Exit 0 + final line "ZERO_CONFIG_OK"  -> proof holds.

set -Eeuo pipefail

# --- Hermetic guard: re-exec with exactly PATH and HOME. -------------------
if [[ "${ZERO_CONFIG_SANITIZED:-}" != "1" ]]; then
  self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  exec env -i \
    PATH="${PATH}" \
    HOME="${HOME}" \
    ZERO_CONFIG_SANITIZED=1 \
    bash "${self}" "$@"
fi

on_err() {
  local code=$1 cmd=$2
  printf '\nZERO_CONFIG_FAIL: command failed (exit %s): %s\n' "${code}" "${cmd}" >&2
  exit "${code}"
}
trap 'on_err $? "${BASH_COMMAND}"' ERR

step() { printf '\n==> %s\n' "$*"; }

# run_step LABEL FN — run one battery step, print EXIT[label]=code, abort
# on non-zero. `|| code=$?` keeps errexit from firing; the ERR trap stays
# armed for everything else.
run_step() {
  local label="$1"; shift
  local code=0
  "$@" || code=$?
  printf 'EXIT[%s]=%s\n' "${label}" "${code}"
  if [[ "${code}" -ne 0 ]]; then
    on_err "${code}" "${label}"
  fi
}

step "hermetic environment (env -i PATH HOME)"
printf 'environment is:\n'
env | LC_ALL=C sort

# Source = the worktree this script lives in (resolve from script location).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"
SRC_HEAD="$(git -C "${SRC}" rev-parse HEAD)"
printf 'worktree: %s\nHEAD:     %s\n' "${SRC}" "${SRC_HEAD}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/zero-config-v2.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
CLONE="${TMP}/ash_surface"

step "git clone (local, no network): ${SRC} -> ${CLONE}"
git clone --quiet "${SRC}" "${CLONE}"
CLONE_HEAD="$(git -C "${CLONE}" rev-parse HEAD)"
if [[ "${CLONE_HEAD}" != "${SRC_HEAD}" ]]; then
  on_err 1 "clone HEAD ${CLONE_HEAD} != worktree HEAD ${SRC_HEAD}"
fi
printf 'cloned HEAD matches worktree HEAD: %s\n' "${CLONE_HEAD}"

# --- Battery steps (each is a subshell function over ${CLONE}). ------------

# Guard: FAIL if any test/ file reads env vars outside the documented
# allowlist. The allowlist is parsed from the clone's mix.exs
# (@zero_env_allowlist ~w(...)) so the guard and the scrubber share one
# source of truth; an unparsable allowlist fails closed.
step_env_guard() (
  cd "${CLONE}"
  local allowlist
  allowlist="$(sed -n 's/^.*@zero_env_allowlist[[:space:]]*~w(\([^)]*\)).*$/\1/p' mix.exs)"
  if [[ -z "${allowlist}" ]]; then
    printf 'env guard: cannot locate @zero_env_allowlist ~w(...) in mix.exs — failing closed\n' >&2
    return 1
  fi
  printf 'documented env allowlist (mix.exs @zero_env_allowlist): %s\n' "${allowlist}"

  local violations=0 line file lineno text name
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    file="${line%%:*}"
    text="${line#*:}"; lineno="${text%%:*}"; text="${text#*:}"
    local found_any=0
    while IFS= read -r name; do
      [[ -n "${name}" ]] || continue
      found_any=1
      if ! printf '%s\n' "${allowlist}" | tr '[:space:]' '\n' | grep -qx -- "${name}"; then
        printf 'env guard VIOLATION %s:%s reads %s (outside allowlist: %s)\n' \
          "${file}" "${lineno}" "${name}" "${allowlist}" >&2
        violations=1
      fi
    done < <(printf '%s\n' "${text}" | grep -oE 'System\.(get_env|fetch_env!?)\([[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
    if [[ "${found_any}" -ne 1 ]]; then
      printf 'env guard VIOLATION %s:%s opaque env read (no literal var name): %s\n' \
        "${file}" "${lineno}" "${text}" >&2
      violations=1
    fi
  done < <(grep -RInE 'System\.(get_env|fetch_env!?)\(' test/ || true)

  if [[ "${violations}" -ne 0 ]]; then
    printf 'env guard: test/ reads env vars outside the documented allowlist\n' >&2
    return 1
  fi
  printf 'env guard: no test/ file reads env vars outside the allowlist\n'
)

step_mix_deps_get() ( cd "${CLONE}" && mix deps.get )

step_npm_install() ( cd "${CLONE}" && npm install --no-audit )

step_mix_test() ( cd "${CLONE}" && mix test )

step_npm_test() ( cd "${CLONE}" && npm test )

# mix test.zero if present: detected by the alias definition in the clone's
# mix.exs (preferred_envs makes it a first-class task); absent => skip 0.
step_mix_test_zero() (
  cd "${CLONE}"
  if ! grep -q '"test.zero":' mix.exs; then
    printf 'mix test.zero: alias not defined in mix.exs — skipped (not a failure)\n'
    return 0
  fi
  mix test.zero
)

run_step "env-read guard (test/ vs @zero_env_allowlist)" step_env_guard
run_step "mix deps.get" step_mix_deps_get
run_step "npm install --no-audit (before mix test: e2e tests import zod)" step_npm_install
run_step "mix test" step_mix_test
run_step "npm test" step_npm_test
run_step "mix test.zero (if present)" step_mix_test_zero

printf '\nZERO_CONFIG_OK\n'
