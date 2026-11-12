# wave3-cae

Standing: PASS

Lane CAE: fixes for wave3-cad embedded-filter defects. Gate:
`MIX_BUILD_ROOT=_build-cae mix test test/ash_surface/projectors test/ash_surface/compiler`
(un-piped to file) exit 0, 416 tests, 0 failures, 2 skipped. Build root deleted.

Changes:
1. Collision: `js.ex` `admit_embedded` export stem honours `:namespace_names` (key =
   `inspect(mod)`); a short name shared by several modules is qualified by the full module path
   (`CAEAItemEmbeddedFilterSchema`). Both export.
2. Typing: `ResourceFacts.embedded_filter_entries/1` (embedded path only; resource-level
   entries unchanged) adds `"zod"` / `"element_zod"` for embedded, union, struct, map and
   array-of-container attributes via `EmbeddedSchema.render` with `cycle_depth: 2`;
   `FilterSchema` uses it as the eq/neq/in/has value schema. Unrenderable types are withheld
   (filterable false), never `z.unknown()`. Self-referential `child` is bounded: expansion ends
   at an object-only record at depth 2 (depth-cut objects are accepted, scalars rejected).
3. Calculations and aggregates are included in embedded entries (typed, functions metadata).

Tests (node+zod, js_embedded_filter_export_test.exs): both-namespace export + namespace_names;
`e eq {n:5}`, `u eq {i:5}|{s:"x"}`, `c eq "x"` accepted; `e eq 5`, `u eq 5`, `u eq {a:1}`,
`c eq 5` rejected; `child eq "junk"|5` rejected, `{name:"n"}` accepted.

Notes: union wire form is the tagged-object form of ash_surface's union schema (`{i: 5}`);
~/ash_typescript parity not separately re-read (UNVERIFIED). Concurrent CZ edits to
filter_schema.ex: targeted Edits only; `mix format` run over the three touched lib/test files.
Aggregates not exercised by a court (UNVERIFIED).
