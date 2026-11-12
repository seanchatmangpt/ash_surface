# Wave 3 Lane RBK Receipt (conformance final regen)

Standing: PASS

Subject: working tree, `MIX_ENV=test MIX_BUILD_ROOT=_build-rbk mix run scripts/conformance_regen.exs`
(no flags except CONFORMANCE_OUT, unused). 788 vectors / 21 files.

## Changed files (before -> after sha256)
- MANIFEST.json: 452b71b2...a803 -> f89bb127...2357 (sha256 of filter_operators.json is the only
  per-file hash that moved among the 21 entries present in the working tree; manifest also lists
  the 10 new kinds).
- vectors/filter_operators.json: 53aa2545...bc76 -> e4628012...d6ed3. Cause: wave3-gu2.md
  (compiler/filter_schema.ex: string gt/gte/lt/lte; whole-array eq/in), wave3-f1en.md (string
  admission), wave3-rbj.md failure 1. Explained, no finding.
- All other vectors: sha256 UNCHANGED by this regen (tracked diffs vs HEAD predate lane RBK).
- IR digest 52edac14...bbf399 pinned in ir_codec_golden_test.exs; ir_codec.json unchanged by regen;
  provenance wave3-01.md:67. KD-12 (FieldName.call_custom) produced no vector delta.

Full before/after list: see /tmp/rbk/before.txt vs after2.txt (all other lines identical).

## Gates
- Idempotence: regen twice, sha256 of MANIFEST + all vectors identical (IDEMPOTENT).
- `node conformance/js/replay.mjs` rc=0.
- `mix test test/conformance` (un-piped): 28 tests, 0 failures, rc=0 (includes Elixir runner).
- `mix ash_surface.parity.tests`: unaccounted=0 broken=0, rc=0.

Falsifier: any vector changed without a receipt; none found.
