# wave3-f1sg receipt

Standing: PASS

Lane F1-sparkguard. Subject: non-Spark module passed to `Spark.extensions/1` raised
"is not a Spark DSL module" (7 failures, wave3-01).

## Diff

- `lib/ash_surface.ex` `dsl_metadata_options/1`: guard `Spark.Dsl.is?(resource, Ash.Resource) and ...`.
- `lib/ash_surface/manifest/dsl.ex` `serialize/1`: same guard. Not an owned file; it was the
  second raise site (stacktrace after first fix). Disclosed minimal unblock.

## Goldens

None re-pinned. The failures were the raise, not digest drift; all goldens pass unchanged.

## Commands

- `MIX_BUILD_ROOT=_build-f1sg mix test test/ash_surface/digest_test.exs
  test/ash_surface/ir_codec_golden_test.exs test/ash_surface/no_local_do_test.exs`
  - before fix 1: 45 tests, 7 failures; after fix 1 only: 7 failures (second site)
  - after both: 45 tests, 0 failures, exit 0
- `mix format` on both files: exit 0
