#!/usr/bin/env bash
# Court 7: Q1 parity gate (AshSurface.Parity.Report, the engine of `mix ash_surface.parity`)
# must exit 1 when a court mapping is deleted. The live inventory is not all-green (real MISSING
# ids exist), so the court drives the REAL gate over a one-capability fixture cut from the real
# court map: BEFORE exit 0, delete the mapping in the scratch copy, AFTER exit 1.
set -euo pipefail
source "$(dirname "$0")/../lib.sh"
[ -f "$SHIM_REPO/lib/mix/tasks/ash_surface.parity.ex" ] || shim_court_skip "lib/mix/tasks/ash_surface.parity.ex absent (Q1 not landed)"
[ -f "$SHIM_REPO/parity/court_map.json" ] && [ -f "$SHIM_REPO/parity/capabilities.json" ] || \
  shim_court_skip "parity/court_map.json and/or parity/capabilities.json absent in live tree"
shim_court_self_check
[ -n "${SHIM_SCRATCH:-}" ] || SHIM_OWNS_SCRATCH=1
shim_scratch_make
ID="codegen.module.Codegen.Orchestrator"
mkdir -p "$SHIM_SCRATCH/parity_fixture"
python3 - "$SHIM_SCRATCH" "$ID" <<'PY'
import json,sys
root,i=sys.argv[1:3]
m=json.load(open(root+"/parity/court_map.json"))["entries"][i]
inv=json.load(open(root+"/parity/capabilities.json"))
cap=[c for c in inv["capabilities"] if c["id"]==i]
json.dump({"advisory":{},"capabilities":cap},open(root+"/parity_fixture/capabilities.json","w"))
json.dump({"entries":{i:m}},open(root+"/parity_fixture/court_map.json","w"),indent=2)
PY
EVAL='r=AshSurface.Parity.Report.evaluate(root: File.cwd!(), inventory_path: "parity_fixture/capabilities.json", map_path: "parity_fixture/court_map.json"); IO.puts("PARITY-VERDICT exit=#{r.exit} missing=#{inspect(r.missing)} errors=#{inspect(r.errors)}"); System.halt(r.exit)'
T="MIX_ENV=test MIX_BUILD_ROOT=_build-q2 mix run --no-start -e '$EVAL'"
apply_shim() { python3 - "$SHIM_FILE" "$ID" <<'PY'
import json,sys
p,i=sys.argv[1:3]; d=json.load(open(p))
del d["entries"][i]            # delete the court mapping
d["_SHIM-COURT"]="deleted mapping "+i
json.dump(d,open(p,"w"),indent=2)
PY
}
shim_court_run parity_fixture/court_map.json "$(shim_green "$T")" "$(shim_red "$T")"
