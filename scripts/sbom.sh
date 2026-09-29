#!/usr/bin/env bash
# Generate a deterministic CycloneDX 1.5 JSON SBOM covering every mix.lock
# package (hex + git) and every package-lock.json package (npm).
#
#   scripts/sbom.sh [OUT]        default OUT: sbom.cdx.json
#
# Offline and hermetic: reads only committed lockfiles + mix.exs @version.
# Same lockfiles => byte-identical output (no timestamp, derived serialNumber).
# Needs only `elixir` (OTP >= 27 for :json). Never hits the network.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-sbom.cdx.json}"
elixir scripts/sbom.exs --lock mix.lock --npm-lock package-lock.json \
  --mix-exs mix.exs --out "$out"
echo "SBOM_OK $out sha256=$(sha256sum "$out" | cut -d' ' -f1)"
