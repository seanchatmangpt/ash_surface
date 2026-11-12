# wave3-ct

Standing: PARTIAL

Lane CT audit of fold.ex constraint allowlist vs Ash 3.33.11 `Ash.Type.constraints/1`.

False refusals (Ash-lawful, refused `:unknown_constraint`): string/ci_string `length_count`;
atom `unsafe_to_atom?`; map/struct `preserve_nil_values?`; utc_datetime `cast_dates_as`,
`timezone`; duration `signs`, `units`.

False admissions (known key, wrong kind or value, admitted `:ok`): integer with `match`,
`casing`, `one_of: 5`, `items: "junk"`, `storage_type: 1`; boolean with `min_items: "z"`,
`precision: []`; array with `min_items: -5`, `max_items: "x"`, `unique_items?: "no"`.
Cause: keys in `@other_keys` hit the catch-all `check_constraint/3` with no kind or value check.
