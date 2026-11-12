# RPC-PIPELINE-CORE

Standing: PASS

Non-actuating port of the ash_typescript RPC pipeline for the zod test port (lanes T7..T12).
It never actuates: no `Ash.read/create/update/destroy`, no data layer. Execution (stage 2 of the
reference pipeline) is not ported; callers supply the already-materialized result term.

## Modules (`lib/ash_surface/runtime_parity/rpc/`)

| module | reference counterpart | role |
|---|---|---|
| `Rpc.Pipeline` | `Rpc.Pipeline` stages 1,3,4 | `parse_request/2`, `process_result/2`, `format_output/1,2`, `run_with_result/4`, `error_response/1` |
| `Rpc.Request` | `Rpc.Request` | parsed request struct (`resource`, `action`, `input`, `select`, `load`, `extraction_template`, `get_by`, `pagination`, `sort`, `filter`, `identity`, `show_metadata`) |
| `Rpc.InputFormatter` | same | client input -> internal atoms (field-name and argument-name mapping, unions, embedded, tuple/keyword) |
| `Rpc.OutputFormatter` | same | internal record -> client keys |
| `Rpc.ResultProcessor` | same | apply the extraction template to a materialized result (pages, lists, resources, unions, typed maps) |
| `Rpc.ValueFormatter` | same | type-driven value formatting for all type kinds, both directions |
| `Rpc.FieldExtractor` | same | extraction helpers |
| `Rpc.ErrorBuilder` | same | typed refusal term -> structured error map (Ash errors go through `AshSurface.Errors`) |
| `Rpc.FieldFormatter` | `AshTypescript.FieldFormatter` | name formatting over `AshSurface.FieldName` + manifest mappings |
| `Rpc.Support` | `Helpers`, `Manifest.Custom`, `ActionIntrospection` | installed manifest handle + entry table, lookups, return-type classification |

Field selection (stage 1) is T5's `RuntimeParity.RequestedFieldsProcessor`; this core calls it.

## Install and entry table

`Support.install(handle, entries)` stores a prepared manifest handle
(`RequestedFields.Compat.prepare/1`) and the RPC entry table in `:persistent_term`. An entry is
built with `Pipeline.entry(name, resource, action, opts)`; options: `get?`, `get_by`,
`not_found_error?`, `enable_filter?`, `enable_sort?`, `allowed_loads`, `denied_loads`,
`show_metadata` (nil = all, false = none, list), `metadata_names`, `identities`.

## Calling from tests

Use the test entry `AshSurface.Ported.Rpc` (`test/support/ported/rpc.ex`; installs the fixture
domain manifest and the full entry table mirroring the reference `typescript_rpc` block):

```elixir
alias AshSurface.Ported.{Rpc, RpcFixtures}

# stage 1 only: {:ok, %Request{}} | {:error, term}
{:ok, request} = Rpc.parse(%{"action" => "mark_completed_task", "identity" => id,
                             "input" => %{"isCompleted" => true}, "fields" => ["id"]})
request.input  #=> %{is_task_completed_now?: true}; also request.load / .select / .get_by

# stages 1+3+4 over a materialized result (hand-built real struct, no data layer)
Rpc.run(%{"action" => "list_todos", "fields" => ["id", "title"]},
        [RpcFixtures.todo(title: "A")])
#=> %{"success" => true, "data" => [%{"id" => ..., "title" => "A"}]}

# refusal at parse time -> client failure envelope
Rpc.error(%{"action" => "list_todos", "fields" => ["nope"]})
#=> %{"success" => false, "errors" => [%{"type" => "unknown_field", ...}]}
```

`Rpc.run/3` takes optional `parse_opts` (`:validation_mode?`, `:actor`, `:tenant`, `:context`).
`RpcFixtures` (`test/support/ported/rpc_fixtures.ex`) builds `user/1`, `todo/1`, `comment/1`
with `struct/2`; unloaded fields stay `%Ash.NotLoaded{}`, so a test sets every loaded
calculation, aggregate and relationship it requests.

## Not ported (loud skips stay in the `*_gap_test.exs` files)

Action execution (read/create/update/destroy/generic run, bulk, identity filter building,
`validate_action` changeset validation), typed queries, channel/controller transport, and any
assertion on generated TypeScript text.

## See Also

`receipts/wave3-t6b.md` · `TEST-PORT-CONTRACT.md` · `receipts/wave3-t5.md`
