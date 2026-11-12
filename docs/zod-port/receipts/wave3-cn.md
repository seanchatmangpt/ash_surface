# Wave 3 Lane CN Receipt

Standing: PASS

- I16: `js_safeparse_test.exs` gains an Elixir twin (2 tests): real node run of the projected
  `dispatchIntent` pins issue keys, code and dot-joined path against `AshSurface.Vocabulary`
  (`issue_shape_keys/0`, `issue_refusal_codes/0`); a projector-source scan pins the emitted keys.
- I17: `js_declaration_order_test.exs` diamond cases now run on real `TypedContainers.NodeA`
  (via `RecordSchema.render/1`, node+zod); `js_mapped_fields_test.exs` real cases run on
  `MappedNames.Gadget`. Synthetic edge cases (array wrap, missing dep, cycles, key ordering)
  stay synthetic. The hand-built quoted-key test was re-pinned: the renderer now normalizes
  `is_active?` to `isActive` (premise rot, not a regression).
- Command: `MIX_BUILD_ROOT=_build-cn mix test` on the 4 files: exit 0, 22 tests, 0 failures,
  2 skipped (loud skips retained; F1-fieldwire skips untouched).
- Not run: full suite (UNVERIFIED).
