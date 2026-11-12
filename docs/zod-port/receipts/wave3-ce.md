# Wave 3 lane CE receipt

Standing: PARTIAL_ALIVE

- I05: generic-action `returns` now carried (`compiler.ex` `returns_facts`, `section/schema.ex`
  `"returns"`), `response_zod` emitted for generic actions (`compiler/ir.ex`). Gap file removed;
  4 skips became real tests (artifact text + real node acceptance) in
  `test/ash_surface/ported/top/embedded_generic_action_return_test.exs`:
  `mix test` on that file: 9 tests, 0 failures, 0 skipped (exit 0).
- I06: `RecordSchema` wired into `response_zod` for read/create/update; non-inlinable (named
  declaration) programs skip with a typed reason. `mix test test/ash_surface/ir_codec_golden_test.exs
  test/ash_surface/compiler/ir_wiring_test.exs`: 51 tests, 0 failures (exit 0). ir_wiring_test
  expectations moved to the camelCase default formatter; response_zod test added.
- Full-suite run shows failures in files outside this lane (camelCase/formatter, filter_operators
  conformance drift, spark parity courts): UNVERIFIED as pre-existing; not triaged here.
- Conformance not regenerated; new digest UNVERIFIED (coordinator FINAL-REGEN).
