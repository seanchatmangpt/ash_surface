# Wave 3 RBB Repair Receipt

Standing: PARTIAL

Lane RBB. New file `test/ash_surface/ported/rpc/rbb/field_selector_branches_test.exs` (inline
resources, no lib edits). Court `/tmp/rbb/court.py`: in-memory recompile of a mutated copy
(`mix run`, MIX_ENV=test, `_build-rbb`), shared lib never written; sha256 restore_eq=True.

Baseline: 6 tests, 0 failures. Mutations (field_selector.ex), all killed (1 failure each):
K-d any?->all?; K-e `args != nil && load_fields != []`->`load_fields != []`; K-f drop
`!is_complex_return_type`; K-b branch `has_non_empty_args && !calc_accepts_args` disabled;
K-g branch `calc_accepts_args && args == nil` disabled. K-b/K-g are reachable, not shadowed
(K-b: complex no-arg calc with non-empty args; K-g: optional-arg calc with nil args). No
equivalents.

SK-mutH re-run (unique anchors; 15 error/type test files, 286 tests):
- E-f2 (errors.ex generic/3 vars %{a: 1}): killed (3 failures).
- E-f (errors.ex exposed/1 vars %{a: 1}): SURVIVES.
- S-d (type_facts.ex `resource?` false->true for struct with instance_of): SURVIVES.
E-f and S-d are not owned here: repair requests for their owners.

`mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0).
