#!/usr/bin/env bash
#
# zero_config_check.sh — the fresh-clone proof for ash_surface.
#
# WHAT IT PROVES
#   A pristine `git clone` of THIS worktree's HEAD (local clone; git never
#   touches the network) builds and passes its full gate with zero
#   configuration beyond PATH and HOME:
#
#       mix deps.get && npm install --no-audit && mix test && npm test
#
#   ORDER NOTE: npm install precedes mix test because two mix e2e tests
#   (consumer_fixture_test, mx_closed_loop_episode_test) shell out to node
#   and import 'zod' from node_modules. A fresh clone without node_modules
#   fails mix test — discovered by this very script's first hermetic run.
#
# HERMETIC GUARD
#   The script re-execs itself through `env -i PATH=... HOME=...` (plus a
#   ZERO_CONFIG_SANITIZED=1 recursion sentinel), so every downstream
#   command runs with exactly PATH and HOME — no MIX_ENV, NPM_CONFIG_*,
#   ASDF_*, HEX_*, or any other caller configuration can leak in.
#
# FAILURE SEMANTICS
#   set -Eeuo pipefail; an ERR trap reports the failing command and exit
#   code. Any failure aborts BEFORE the ZERO_CONFIG_OK line, so the line
#   can never be printed for a broken tree.
#
# OFFLINE POLICY (zero-config != offline)
#   git is fully offline (local clone). Hex/npm may consult the network
#   for `mix deps.get` / `npm install` unless their user caches under HOME
#   are warm. If run in a genuinely offline environment those steps may
#   fail with network errors — that is a network blocker, NOT a zero-config
#   failure. The script deliberately does NOT auto-skip on network errors
#   (no false ZERO_CONFIG_OK); record the exact blocker in the receipt
#   instead, and rerun with network or warm caches.
#
# USAGE
#   bash scripts/zero_config_check.sh
#   Exit 0 + line "ZERO_CONFIG_OK"  -> proof holds.

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

step "hermetic environment (env -i PATH HOME)"
printf 'environment is:\n'
env | LC_ALL=C sort

# Source = the worktree this script lives in (resolve from script location).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(git -C "${SCRIPT_DIR}/.." rev-parse --show-toplevel)"
SRC_HEAD="$(git -C "${SRC}" rev-parse HEAD)"
printf 'worktree: %s\nHEAD:     %s\n' "${SRC}" "${SRC_HEAD}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/zero-config-check.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
CLONE="${TMP}/ash_surface"

step "git clone (local, no network): ${SRC} -> ${CLONE}"
git clone --quiet "${SRC}" "${CLONE}"
CLONE_HEAD="$(git -C "${CLONE}" rev-parse HEAD)"
if [[ "${CLONE_HEAD}" != "${SRC_HEAD}" ]]; then
  on_err 1 "clone HEAD ${CLONE_HEAD} != worktree HEAD ${SRC_HEAD}"
fi
printf 'cloned HEAD matches worktree HEAD: %s\n' "${CLONE_HEAD}"

step "mix deps.get"
( cd "${CLONE}" && mix deps.get )

step "npm install --no-audit (before mix test: e2e tests import zod)"
( cd "${CLONE}" && npm install --no-audit )

step "mix test"
( cd "${CLONE}" && mix test )

step "npm test"
( cd "${CLONE}" && npm test )

printf '\nZERO_CONFIG_OK\n'
