# Wave 3 F1-errcfg receipt

Standing: PASS

Scope: field_names in Errors, zod_object_mode helper, tenant default, ash_error? guard.

## Commands (MIX_BUILD_ROOT=_build-f1e)

- `mix test` f1e_errcfg, identity_schema, errors, errors_config, errors_s1b, error_schema,
  error_schema_deep, error_runtime, no_local_do: 84 tests, 0 failures.
- `mix format --check-formatted` on all changed files: exit 0.
- s1i_identity_selection_fieldname_test.exs: 1 failure (L8 custom formatter calls undefined
  `AshSurface.FieldNameTest.shout/1`); file not owned, untouched by this lane, pre-existing.

## Changes

1. `Errors.to_errors/2`: `:field_names` opt, else resource `field_names` (Info.field_names/1);
   applied via `ErrorFormatter.apply_field_names/3` to `fields`, `path`, `vars.field`.
   `apply_field_names` path segments now use the mapping too (operator law; ash_typescript
   formats path without mapping). Court: real Ash resource with `field_names(active?: "isActive")`.
2. New `AshSurface.Compiler.ObjectMode.suffix/1` (":strict" -> .strict(), :passthrough, :strip -> "").
   ash_typescript has no object-mode option (grep of lib: zero hits); default zod = strip.
   `ErrorSchema` and `IdentitySchema.render_get_schema/3` take an explicit `:object_mode` opt;
   unset keeps prior output byte-identical (passthrough errors, strict field errors/identities).
   Config accessor `zod_object_mode/0` is the default for `ObjectMode.suffix/0` only.
3. `IdentitySchema.render_tenant_schema/1` now defaults to `Config.require_tenant_parameters/0`
   (false); new `/2` takes explicit default. Existing test re-pinned (missing fact -> optional).
   Courts for both settings under node+zod.
4. Guard: behavioral court that non-table Ash errors (AssumptionFailed, UnknownError) yield the
   generic UUID error and never leak content.

## Files

lib/ash_surface/errors.ex, error_formatter.ex, compiler/error_schema.ex, compiler/identity_schema.ex,
compiler/object_mode.ex (new); tests: f1e_errcfg_test.exs (new), errors_config_test.exs,
compiler/identity_schema_test.exs. Config.ex not changed (accessor already existed).

## Follow-up consumers of ObjectMode (not edited, other lanes)

- compiler/embedded_schema.ex lines 166, 242 (`.strict()`)
- compiler/calculation_schema.ex lines 157, 165, 171, 174
- compiler/relationship_schema.ex lines 110, 203, 217, 221, 225
- compiler/section/schema.ex and filter/query schemas (not located by grep for `.strict()` in
  scanned paths; owners to check)
