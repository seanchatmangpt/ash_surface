# Wave 3 RAQ: repair of E and S survivors

Standing: PARTIAL_ALIVE

Source: wave3-skmutf.md repair requests 6 and 7. Files (live paths are rpc/a and rpc/d):
`test/ash_surface/ported/rpc/a/error_redaction_surface_test.exs`,
`test/ash_surface/ported/rpc/d/struct_argument_test.exs`.

Added exact assertions: table type + shortMessage for Policy, TenantRequired, Changes.Required,
ReadActionRequiresActor (Pipeline.error_response and Errors.classify); exposed UnknownError
envelope; embedded `resource?`/`resource`/`module`; User struct-arg closure names (incl. `id`);
RouteSettings `field_names`.

Shim-court (scratch /tmp/raq, harness mut.py, sha256 restore byte-exact, restore_eq True x9),
all mutations re-confirmed applying, baseline 33 tests 0 failures:

| id | result |
|---|---|
| E1 E2 E3 E4 E6 | killed (1 failure each) |
| S2 S3 S4 | killed (1 failure each) |
| S5 | SURVIVES: equivalent, `Support.action_input_field_types/1` is a stub returning nil, so the `types ->` branch is unreachable |

Gate: `MIX_BUILD_ROOT=_build-raq mix ash_surface.parity.tests` rc=0 (broken=0, unaccounted=0).
Live: 33 tests, 0 failures. No lib edits.
