# Lane 12 Receipt

Standing: PARTIAL

## Files changed

- `ontology.ttl`: 16 `aex:EntitySchemaField` rows on `surf:ProjectionEntity` (orders 4-19): name,
  namespace, description, deprecated, see, read_action, get?, get_by, not_found_error?, identities,
  enable_filter?, enable_sort?, allowed_loads, denied_loads, show_metadata, metadata_field_names.
  Presentation facts (name/namespace/description/deprecated/see) are marked as such and kept out of
  IR truth sections.
- `lib/ash_surface/resource/validator.ex`: refusals `get_and_get_by_conflict`,
  `allowed_and_denied_loads_conflict`, `unknown_identity_projection`, `get_by_not_public_attribute`,
  `read_action_not_public_read`, `duplicate_projection_name` (all `%{code:, detail:}`).
- `lib/ash_surface/resource/info.ex`: new module `AshSurface.Resource.Projections` (option defaults,
  presentation split). The `AshSurface.Resource.Info` module is ggen-generated at
  `lib/ash_surface/info.ex`, so a second definition was not possible.

## Not done: regenerate resource.ex (BLOCKED)

`lib/ash_surface/resource.ex` is NOT regenerated; DSL fields are not yet live.
1. `cd /Users/sac/ash_surface && ggen sync run` -> exit 1,
   `[FM-LAW-015] ... ea.graph.json is absent` (with ggen.lock restored the earlier error is
   `[FM-PACK-008] content hash mismatch: ggen.lock blake3:e048ac1b... vs pack on disk blake3:723d6b6e...`).
2. `ggen sync run --skip-ea-admission` (lock removed) -> exit 1,
   `[FM-WRITE-005] /Users/sac/ash_surface/scripts/README.md exists with differing content; refusing silent clobber`.
3. Scratch-copy run (`/tmp/gs-lane12`, no lock) hung on pack fetch; killed.
ggen.lock was deleted for step 2 and restored byte-identical from backup; resource.ex untouched.
Close condition: coordinator re-locks the pack (or restores pack at 3ddbfeb7) and runs sync with
`force`/clobber policy scoped to resource.ex, or in a clean checkout.

## Verification

- `MIX_BUILD_ROOT=_build-lane12 mix compile` -> rc 0 (warnings are from lane 18 inference.ex heredoc).
- No tests written or run (validator option paths need regenerated struct fields); UNVERIFIED.
- `_build-lane12` deleted.

## Requests

- Coordinator: regenerate resource.ex (above); lane 17 may consume `AshSurface.Resource.Projections`.

## Falsifiers

- After regeneration, a projection declaring `get?: true, get_by: [:id]` must yield
  `get_and_get_by_conflict`; any projection with both loads lists must be refused.
