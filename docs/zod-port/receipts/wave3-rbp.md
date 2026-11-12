# Wave 3 RBP: route-key oracle made independent of the lib

Standing: PASS

Subject: test/ash_surface/adversarial/route_channel_adversarial_test.exs (only file edited; no lib edits).

## Reference rule (ash_typescript @ 5d6e80ae, source reads, deps not installed)

- Client keys = `Helpers.format_output_field/1` (lib/ash_typescript/helpers.ex:73) ->
  `FieldFormatter.compute_field_name` :camel_case (field_formatter.ex:293-305) ->
  `Helpers.snake_to_camel_case` = lowerFirst(`Macro.camelize`) (helpers.ex:25-30).
- Applied to route query keys (typed_controller/codegen/route_renderer.ex:147,155), path-param
  object keys, and request keys (request_handler.ex:324). `p_1` -> `p1`, `line_1` -> `line1`,
  `user_id` -> `userId`. URL template keeps `:p_1` verbatim.
- Digit rule: lib agrees (no lib defect). Lib deviations, documented in FieldName (not changed):
  trailing `?` stripped (ref `isReady?`), leading `_` kept (ref drops), `Foo_bar` (ref `fooBar`).

## Oracle

`ref_emit/1` = Macro.camelize + lowerFirst (does not call FieldName), plus a literal table
(p_1->p1, user_id->userId, line_1->line1, a_b_2c->aB2c, is_ready?->isReady, _p->_p) executed
through RouteSchema; hostile `_`/`?` names outside the reference domain are filtered.

## Evidence (MIX_BUILD_ROOT=_build-rbp, rc un-piped)

- Red baseline: pre-RBL logic (verbatim names) vs current lib: 7 tests, 1 failure, 53 wrong
  cases (p_1 vs `p1`). Digit-only attribution: UNVERIFIED beyond the p_1 witness.
- New file: 8 tests, 0 failures, rc=0.
- In-memory mutations (Code.compile_string, /tmp/rbp/mut.exs): identity, upcase, digit rule
  (`_`+Cap) each -> 2 failures.
- mix ash_surface.parity.tests rc=0 unaccounted=0. adversarial + ported/rpc: 2250 tests,
  0 failures, 213 skipped, rc=0.
