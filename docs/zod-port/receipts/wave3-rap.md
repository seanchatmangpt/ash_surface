# Wave 3 RAP Repair Receipt

Standing: PARTIAL

Lane RAP, repair of SK-mutF requests 1 and 3. Owned: `manifest_generator_config_test.exs`
(new "zod/error config defaults" describe) and `calculation_field_selection_test.exs`
(new "calculation argument validation branches" describe). No lib edits.

Court: `/tmp/rap/court.sh`, build root `_build-rap`; in-place mutate, sha256 restore
byte-exact (`restore_eq True` x8). Baseline 25 tests, 0 failures.

| id | result |
|---|---|
| J4, J5, J6 | killed (1 failure each) |
| C1, C3, C4, C6 | killed (1 failure each) |
| C2 | survives: no Todo calculation has a required (non-nil) argument, so the branch is unreachable with current fixtures; needs a fixture edit outside owned files |

`mix ash_surface.parity.tests` rc=0 after edits.
