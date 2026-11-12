# Wave 3 SK-mutG: mutation skeptic over RAD / RAL / RAP repairs

Standing: PARTIAL

Scratch /tmp/skmg (tar of live repo, deps/node_modules symlinked, build root /tmp/skmg/_b,
deps ebin copied from canonical _build/test). Each mutation: sha256 baseline == restore
(restore_eq=yes for all 47); no NOOP mutations; `mix test <file>` rc un-piped via court.sh.
No lib edits in the canonical checkout. typed_query.ex untouched (RAO). Baselines green
(pagination file 14 tests, 0 failures).

## Results (K = killed, S = survived)

| id | file : mutation | verdict |
|---|---|---|
| P1 | pipeline.ex pagination_not_supported :unsupported -> :disabled | K |
| P2 | pipeline.ex `{:invalid_pagination, invalid}` payload -> nil | S |
| P3 | pipeline.ex unknown_page_keys payload not stringified | S |
| P4 | pipeline.ex validate_top_level_page drops action_supports_pagination? | S |
| P6 | pipeline.ex validate_top_level_param :disabled -> :unsupported | S |
| F1 | result_processor.ex extract_resource_field ForbiddenField -> acc (key dropped) | S |
| F2 | result_processor.ex nested ForbiddenField -> acc | S |
| F3 | result_processor.ex normalize_primitive(ForbiddenField) -> :redacted | S |
| F4 | result_processor.ex normalize_primitive(NotLoaded) -> :skip | S |
| F5 | result_processor.ex extract_value(NotLoaded) :skip -> nil | S |
| E8,E10,E18,E19,E22 | errors.ex InvalidChanges short, Policy short, field_list, path_of, Action.InvalidArgument short | K |
| E9,E11-E15 | errors.ex ForbiddenField type, InvalidKeyset, InvalidPage, TenantRequired, InvalidPrimaryKey, ReadActionRequiresActor | S |
| E17 | errors.ex InvalidChanges removed from @bare_message_types | S |
| E20 | errors.ex scrub Module.split last -> join | S (possibly equivalent) |
| E21 | errors.ex vars drop :count | S |
| N1-N4,N6,N7 | action_manifest.ex nil-reject, uniq, sort, entry-vs-resource order, to_string, key removal | K (all 6) |
| C1-C3 | config.ex zod_import_path, zod_import_into_generated, show_raised_errors defaults | K |
| C4-C7 | config.ex zod_schema_suffix, zod_object_mode, zod_infer_types, show_policy_breakdowns defaults | S (not asserted) |
| K1,K2 | field_selector.ex has_non_empty_args, invalid_calculation_args path | K |
| K3 | has_any_arguments? -> length(args) > 1 | S |
| K4 | has_required_arguments? -> false | S (RAP C2, no required-arg fixture) |
| K5 | load_spec `args != nil && load_fields != []` -> `load_fields != []` | S |
| K6 | load_spec `{name, args}` -> bare name | S |
| K7 | invalid_field_selection guard -> false | S |

Notable: F1-F5 all survive, so the RAD ForbiddenField coverage does not pin the
struct-field redaction branches (only extract_value(ForbiddenField)). RAL namespace manifest
fully killed incl. nil/duplicate/unsorted/entry-vs-resource override.

## Namespaces probe

- `namespaces` handles nil (rejected), duplicates (uniq), order (sorted), entry override
  (entry > resource > domain): pinned by namespace_manifest_surface_test (N1-N4 killed).
- Key-set pins: manifest_generator_surface_test.exs:106 already expects
  ["actions","namespaces","resources","version"]; projector_hardening_test.exs:286 is the Expo
  projector's own `namespaces`, unrelated. No conformance vector, parity file or lib consumer
  other than tests references ActionManifest output keys.
- Untested edge: empty-string namespace passes the nil-reject and appears in the list.

## Repair requests

1. test/ash_surface/ported/rpc/d/rpc_validate_action_surface_test.exs: kill P2 (invalid_pagination
   payload, pipeline.ex parse_pagination non-map page), P3 (stringified unknown_page_keys), P4
   (list read without pagination support refused, validate_top_level_page), P6 (disabled vs
   unsupported top-level param).
2. test/ash_surface/ported/rpc/a/forbidden_field_redaction_test.exs: kill F1/F2 (ForbiddenField
   attribute and nested one keep the key with nil: result_processor.ex extract_resource_field /
   extract_resource_nested_field), F3 (normalize_primitive(ForbiddenField) == nil), F4
   (normalize_primitive(NotLoaded) == nil), F5 (extract_value(NotLoaded) == :skip).
3. test/ash_surface/ported/rpc/a/error_protocol_surface_test.exs: exact type/short_message for
   ForbiddenField (E9), InvalidKeyset (E11), InvalidPage (E12), TenantRequired (E13),
   InvalidPrimaryKey (E14), ReadActionRequiresActor (E15); bare-message path for InvalidChanges
   (E17); vars include :count (E21); scrub of Elixir module atoms (E20, may be equivalent).
4. test/ash_surface/ported/rpc/b/manifest_generator_config_test.exs: assert defaults of
   zod_schema_suffix, zod_object_mode, zod_infer_types, show_policy_breakdowns (C4-C7).
5. test/ash_surface/ported/rpc/a/calculation_field_selection_test.exs: kill K3 (calc with exactly
   one argument), K5/K6 (load spec shapes {name, {args, fields}} and {name, args}), K7 (fields on
   a non-complex calculation -> invalid_field_selection); K4 needs a required-arg calculation
   fixture (open from RAP C2).
6. RAL optional: empty-string namespace case.

Not run: full-suite gate (UNVERIFIED).
