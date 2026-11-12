# Wave 3 Lane SK-fw Receipt

Standing: PARTIAL

Read-only audit of F1-fieldwire default-on camel_case. Scratch: /tmp/skfw (tar copy,
MIX_BUILD_ROOT=/tmp/skfw/_build2, MIX_ENV=test; probes /tmp/skfw/probe1-5.exs). Not run:
reference ash_typescript side-by-side, node+zod execution of emitted artifacts (UNVERIFIED).

## Failing inputs (real output)

1. Calc-argument collision not refused: `calculate :c1 ... argument :pre_fix; argument :preFix`
   compiles :ok; facts calculations args = `["preFix","preFix"]`. action_inverse covers
   fields+inputs only.
2. Destination collision not refused: `Kid` (no actions) with `foo_bar` + `fooBar`; `Top.read`
   facts relationships.primitive_fields = `["fooBar","fooBar","id","topId"]`, compile :ok.
   Only refused if Kid owns a compiled action.
3. Precedence split: resource with `typescript_field_names/0` (lists `a_x?`) AND
   `field_names(done?: "isDone")`: `FieldName.wire(R,:done?)` = "isDone" (compiler) but
   `format_field_for_client(:done?,R,:camel_case)` = "done" (runtime output). Verify also warns
   `a_x?` invalid despite the callback mapping.
4. Error path/field spelling != schema keys: path `[:__x,:a_1]` -> `["X","a1"]` (schema key
   `__x`); field `:x__` -> "x"; `:is_active?` -> "isActive?" (schema "isActive");
   `:is_task_completed_now?` -> vars.field "isTaskCompletedNow?" (argument_names says
   "isCompleted"). Probe built errors without resource context (resource-bound variant UNVERIFIED).
5. `FieldName.with_formatter/2` and `Compiler.compile` opt `:output_field_formatter` do not reach
   RPC (Support reads Config): under :snake_case compile, parse still resolves camel.
6. Rpc.parse accepts internal spellings (`archived?`, `-due_date`, `-DueDate`) and passes
   formatter-derived `isTaskCompletedNow` through as a string key unrefused (mapped name should win).

## Held

Round-trip facts["field_names"] correct for camel/pascal/snake/custom on url_id, a1_b2, __x,
unicode, `?`; `foo?`/`foo` and `fooBar`/`foo_bar` collisions refused at compile.
