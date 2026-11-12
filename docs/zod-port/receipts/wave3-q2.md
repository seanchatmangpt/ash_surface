# wave3-q2 shim-court receipt

Standing: PASS

Subject: live tree snapshot of /Users/sac/ash_surface (uncommitted, concurrent lanes editing);
courts run on /tmp scratch copies. Command: `bash scripts/shim_court/run_all.sh`, exit 0,
`SUMMARY pass=7 fail=0 skip=0`. Self-check: `mix test
test/ash_surface/shim_court_selfcheck_test.exs` 4 tests, 0 failures.

| court | BEFORE exit | AFTER exit (red) | baseline == restore sha256 |
|---|---|---|---|
| 01 zod_type.ex (numeric min->max) | 0 | 2 | 405de7d0...e72403 verified |
| 02 union_schema.ex | 0 | 2 | 112ed508...a547b91 verified |
| 03 zod_guard.ex | 0 | 2 | b65297d7...b7cc80 verified |
| 04 errors.ex | 0 | 2 | c7720e11...662d78 verified |
| 05 ash_surface_runtime.mjs | 0 | 1 | f6a01e68...d3429b6e5 verified |
| 06 transport_outcome.json vector | 0 | 1 | b8bc72ad...dabd6b0e verified |
| 07 parity gate (fixture court map) | 0 | 1 (`PARITY-VERDICT exit=1`) | c6716b42...b852a0 verified |

Live-tree evidence: no `SHIM-COURT` under lib/ or priv/ (grep, 0 matches). `[LIVE-GUARD]`
prints each live file's sha256 pre/post. `git diff --stat` on shimmed live files shows only
other lanes' pre-existing edits (zod_guard.ex 50+/5-, runtime.mjs 49+/13-,
transport_outcome.json 1+/1-; others empty). zod_type.ex's live sha changed mid-run
(concurrent lane edit, noted by LIVE-GUARD); the court never wrote it.

Loud SKIPs: none in the final run. Court 07 `[SKIP]`s if the Q1 task or
parity/{court_map,capabilities}.json are absent (both present).

Notes:
- The live parity gate is itself red (`mix ash_surface.parity` exit 1, real MISSING ids), so
  court 07 drives the real `AshSurface.Parity.Report` over a one-capability fixture cut from
  the real court map: green, delete the mapping, exit 1.
- Courts 01/06 are narrowed to tests green in the snapshot (a schema_constraint regex test
  and the full conformance_replay file were red from other lanes' in-flight edits; first
  runs recorded those as `[FAIL:BEFORE]`).
- `_build-q2` in the live tree and `/tmp` scratch dirs deleted.

Falsifier: a court whose AFTER stays green, or a restore sha mismatch, exits 1.
