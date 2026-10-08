#!/usr/bin/env bash
# packs/ash-extension-pack/fixture/spark-closure-consumer/installer_court.sh
#
# Real end-to-end runner for the igniter idempotence court
# (packs/ash-extension-pack/templates/igniter_idempotence_court.exs.tmpl).
#
#   1. copies this committed fixture app into a disposable capsule
#   2. projects the pack's generated output (the real Mix.Tasks.<X>.Install task and
#      the rendered court) into the capsule app with a real `ggen sync run` over the
#      pack ontology + qualification/consumer.ttl union graph
#   3. MIX_ENV=test mix deps.get + mix test <court file>
#
# The committed fixture stays pristine; all build output lands in the capsule.
#
# Env:
#   AEX_INSTALLER_MUTANT  path to a mutant installer .ex; when set, the court swaps
#                         it in over the real installer in every scratch copy
#                         (anti-vacuity: the court must FAIL against the mutant).
#   AEX_CAPSULE           reuse an existing capsule dir instead of a fresh tmp one.
#   AEX_PACK_DIR          pack dir to sync from (default: the pack this fixture lives in).
#
# Usage: installer_court.sh [ggen-binary] [-- mix test args...]
set -euo pipefail

fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# AEX_PACK_DIR overrides the pack source (defaults to the pack this fixture lives in).
# Useful while sibling lanes' in-flight court templates block a full-pack sync.
pack_root="${AEX_PACK_DIR:-$(cd "${fixture_root}/../.." && pwd)}"
ggen_bin="${1:-${GGEN_BIN:-$(command -v ggen)}}"
shift 2>/dev/null || true

capsule="${AEX_CAPSULE:-$(mktemp -d "${TMPDIR:-/tmp}/spark-closure-consumer-court.XXXXXX")}"
echo "capsule: ${capsule}"

if [ ! -f "${capsule}/.rendered" ]; then
  rm -rf "${capsule}"
  mkdir -p "${capsule}"
  cp -R "${fixture_root}/." "${capsule}/"

  # Projection-profile consumer: union of the pack ontology and the qualification
  # consumer graph (the same shape scripts/qualify_packs.py's write_projection_consumer
  # builds), so the sync projects the qualification specs (ledger_probe is the one with
  # an installer) exactly as marketplace qualification does.
  pack_path="${pack_root}"
  cat > "${capsule}/ggen.toml" <<TOML
[project]
name = "spark-closure-consumer-court"

[ontology]
source = "ontology.ttl"

[packs]
"ash-extension-pack" = { path = "${pack_path}" }

[templates]
dir = "templates"
TOML
  # Union graph: pack ontology + qualification consumer specs (the marketplace
  # qualification projection-profile shape).
  if [ -f "${pack_root}/qualification/consumer.ttl" ]; then
    cat "${pack_root}/ontology.ttl" "${pack_root}/qualification/consumer.ttl" > "${capsule}/ontology.ttl"
  else
    cp "${pack_root}/ontology.ttl" "${capsule}/ontology.ttl"
  fi
  mkdir -p "${capsule}/templates"
  touch "${capsule}/.rendered"
fi

( cd "${capsule}" && "${ggen_bin}" sync run --format json >sync.json 2>sync.log ) || {
  echo "REFUSED:GGEN_PACK_SYNC_FAILED" >&2
  tail -20 "${capsule}/sync.log" >&2
  exit 1
}

if [ ! -f "${capsule}/lib/mix/tasks/ledger_probe.install.ex" ]; then
  echo "REFUSED:INSTALLER_NOT_PROJECTED (expected lib/mix/tasks/ledger_probe.install.ex)" >&2
  ls "${capsule}" >&2
  exit 1
fi

cd "${capsule}"
export MIX_ENV=test
mix deps.get
mix test test/*_igniter_idempotence_court_test.exs "$@"
