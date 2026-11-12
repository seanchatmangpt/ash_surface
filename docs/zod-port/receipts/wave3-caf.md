# wave3-caf

Standing: PARTIAL_ALIVE

Lane CAF repairs the CAC findings (wave3-cac.md) in the parity gate tag handling.
Files: `lib/ash_surface/parity/test_index.ex`, `lib/ash_surface/parity/court_map.ex`, new
`lib/ash_surface/parity/exclude_spec.ex`, new
`test/ash_surface/parity/test_index_tags_adversarial_test.exs` (18 courts, real temp files).

## Fixes

- (a) test_helper.exs read via `Code.string_to_quoted`; `~w(slow)a`, bound variables, keyword
  filters resolve; `Application.get_env`/module attributes/unbound vars give typed
  `UNRESOLVABLE-EXCLUDE` (hard) problem. Comments ignored.
- (b) include overrides exclude; exclusions compare tag VALUES (`slow: false`, `slow: "x"`).
- (c) `--only/--exclude/--include` read from mix.exs alias strings (string and token-list
  forms); courts use temp mix.exs fixtures (latent in the live repo).
- (d) nested defmodule scoped (tags, skip, describe); `@tag` before `describe` binds to the
  first test only, verified by a real `elixir` ExUnit subprocess in the court.
- (e) for-comprehension and local-macro-generated tests reported in `idx.dynamic` as
  `unindexable-dynamic-test`; a court needing one gets `UNINDEXABLE-DYNAMIC-TEST`
  (hard for literal refs, soft/MISSING for `{leaf}` families, so static alternatives still win).

## Commands (MIX_BUILD_ROOT=_build-caf, rc un-piped)

- `mix test test/ash_surface/parity`: rc=0, 69 tests, 0 failures
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0
- `mix ash_surface.parity`: rc=1 (pre-existing missing=10, unchanged); summary total=403
  pass=302 divergence=12 non_goal=79 broken=0 missing=10, identical to wave3-cm baseline.

## Reclassifications

None in the final summary. Intermediate: 16 `{leaf}` family hits had matched only via the
old mangled "gen \0" entries; with hard dynamic problems they went broken=16, so the
dynamic problem is soft for templated refs (they remain covered by static alternatives).

## Not run

`parity_tests/skips.ex` (separate exclude reader, not owned) still uses its own scan: UNVERIFIED.
