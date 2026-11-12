# wave3-rp

Standing: PASS

Lane RP (build root `_build-rp`, deleted at finish). Item: wave3-skfw item 5 (formatter scope did
not reach RPC). Failure re-confirmed before the edit (camel resolved under a snake scope).

## Design

The smaller option: `FieldName.with_formatter/2` (the scope of Compiler option
`:output_field_formatter`) now applies to RPC in-process, input and output.

- `field_name.ex`: added `scoped_formatter/0`, `input_formatter/0` (additive; RO owns precedence).
- `rpc/support.ex`: `output_field_formatter/0` -> `FieldName.output_formatter/0`;
  `input_field_formatter/0` -> `FieldName.input_formatter/0`.
- `requested_fields/{field_selector,atomizer}.ex`: `Config.input_field_formatter()` ->
  `FieldName.input_formatter()`.
- `rpc/pipeline.ex`: `check_scoped_spellings/2` refuses (typed `unknown_field`) a top-level
  requested field spelled by the Config formatter but not by the scoped one; explicit
  field_names overrides exempt. Only active inside an explicit scope; no scope = unchanged
  reference behavior (the reference's snake parse is lenient to camel). Nested paths: UNVERIFIED
  (still lenient). The IR/manifest-carried-identity option and the manifest-vs-Config refusal were
  not built. No Ash.read/create/update/destroy added.

## Courts

`test/ash_surface/divergence_close/rpc_formatter_scope_test.exs` (5 tests): snake scope parses
`created_at`, camel `createdAt` -> `{:error, {:unknown_field, :created_at, ...}}`; converse
pascal scope parses `CreatedAt`, refuses `createdAt`; snake scope emits snake output keys; scope
restores after the block; default camel resolves.

## Commands

- `mix test .../rpc_formatter_scope_test.exs`: rc=0, 5 tests, 0 failures.
- `mix test test/ash_surface/ported/rpc test/ash_surface/divergence_close
  test/ash_surface/no_local_do_test.exs`: rc=0 (un-piped), 1812 tests, 0 failures, 213 skipped.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.

## Falsifier

A scoped parse that accepts a Config-spelled field, or scope leaking past `with_formatter`.
