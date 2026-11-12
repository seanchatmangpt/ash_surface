# Wave 3 RBL: route adversarial p1 vs p_1

Standing: PASS

Verdict (a): test oracle stale; lib correct. RouteSchema emits every client-facing key as
`FieldName.emitted(name)` (path object, query, body), router path template stays verbatim
(`p_1`), inverse tables map back; this is ash_typescript route_renderer.ex format_output_field
parity (request_handler.ex:324). Schema key `p1` for path param `p_1` is the lawful, single
emission; the client sends `p1`.

Edit (1 file, disclosed): test/ash_surface/adversarial/route_channel_adversarial_test.exs,
oracle names now `FieldName.emitted/1` of declared names. No lib edits.

Mutations (in-memory Code.compile_string of route_schema.ex, nothing on disk changed; run via
/tmp/rbl/mut.exs): emitted_name identity -> 1 failure; upcase -> 1 failure; object() keeps one
field -> 1 failure. Unmutated: route_channel file 7 tests 0 failures (rc=0).

Gates (rc un-piped to file): mix test test/ash_surface/adversarial + ported/rpc: 2235 tests,
0 failures, 213 skipped, rc=0. mix ash_surface.parity.tests: rc=0, unaccounted=0.
