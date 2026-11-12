# wave3-cad

Standing: PARTIAL

Lane CAD (read-only skeptic) on lane CR embedded filter export. Real node + zod 4, build root
_build-cad (deleted). Fixtures were ad hoc in /tmp/cad/audit.exs (not committed).

Findings:
1. Same-short-name collision: `embedded_filters: [CAD.A.Item, CAD.B.Item]` returns
   `{:error, {:js_binding_collision, "ItemEmbeddedFilterSchema"}}` (typed refusal, nothing
   emitted, no escape hatch like :namespace_names for embedded exports). Legal inputs cannot
   be exported together.
2. Hostile names: field names `__proto__`, `constructor`, `a"b`, `a\b`, `x\ny` emitted as
   correctly escaped z.enum literals; all accepted; `toString` rejected; wrong value type
   rejected; JSON.parse'd `__proto__` accepted. No unsafe emission found.
3. Recursive embedded (self via :struct instance_of): projects in 384ms, 44868 bytes, no
   recursion. Recursion is flattened: `child` eq accepts any value (`"junk"` -> true).
4. Union/embedded/array-of-embedded attrs are `z.unknown()`: `e eq 5` accepted, `u eq {a:1}`
   (not int|string) accepted. Illegal accepted (type-loose, not unsafe).
5. Calculations are excluded: `{field:"c"}` rejected (embedded_filter_entries is
   attributes-only; calculations/aggregates unfilterable by design/doc).
6. Order: project_ir([Rich,Host]) == project_ir([Host,Rich]) byte-identical.
