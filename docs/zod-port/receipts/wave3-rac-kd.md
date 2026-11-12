# wave3-rac-kd

Standing: PASS

Evidence: PASS `mix test test/ash_surface/ported/typed_controller/router_introspection_test.exs`
rc=0 (un-piped), 19 tests, court file
`test/ash_surface/ported/typed_controller/router_introspection_test.exs`.

Reference: `~/ash_typescript/lib/ash_typescript/typed_controller/codegen/router_introspector.ex:137`
(`longest_common_suffix/1` reverses strings and takes a grapheme-wise common prefix, so
helpers `alpha`/`zeta` yield a shared suffix `a`).
