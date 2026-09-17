defmodule AshSurface.Compiler.BoundaryLedgerTest do
  @moduledoc """
  Reader-pinned tripwire for `AshSurface.Compiler.IR.Boundary`
  (gapfix-test-surface-015; dead-code ledger retired at integration).

  Law: the Boundary slice is the canonical v07 shape (compiler/ir.ex) and the
  schema section's output (`AshSurface.Compiler.Schema.build/2` constructs it
  at the ledgered site). It is exercised field-complete by
  `AshSurface.Compiler.SchemaSectionTest` (zod, input, output, aria). The
  intended production reader — the orchestrator-facing
  `AshSurface.Compiler.Section.Schema` adapter (compiler.ex's default
  binding) — has landed (gapfix-adapters-001 at integration) and mounts these
  slices into compiled IRs.

  The dead-code ledger that pinned the pending state was retired per the
  original rows' own prescription ("when the adapter lands, retire this
  ledger and pin the real reader"). Retirement is pinned, not silent:

    * if the slice's shape changes owner (no longer built as `IR.Boundary`),
      or
    * if the landed reader stops referencing the Boundary struct,

      the rows below fail and force the comment in
      lib/ash_surface/compiler/schema.ex and this file to be re-pointed.
      Losing the reader silently — without re-pointing this tripwire — is the
      failure mode being guarded.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.Schema

  @ledgered_schema_source Path.expand("../../../lib/ash_surface/compiler/schema.ex", __DIR__)
  @canonical_ir_source Path.expand("../../../lib/ash_surface/compiler/ir.ex", __DIR__)
  @lib_dir Path.expand("../../../lib", __DIR__)

  defp action(id, args), do: %{"id" => id, "arguments" => args, "returns" => nil}

  defp arg(name, kind),
    do: %{"name" => name, "type" => %{"kind" => kind}, "allow_nil?" => false}

  test "build/2 output is field-complete AshSurface.Compiler.IR.Boundary structs" do
    assert {:ok, ir, %{action_count: 1, argument_count: 2}} =
             Schema.build(%{
               "actions" => [action("Act#go", [arg("a", "string"), arg("b", "integer")])]
             })

    slice = Map.fetch!(ir, "Act#go")
    assert %AshSurface.Compiler.IR.Boundary{} = slice

    assert slice.input == %{
             "a" => %{"type" => %{"kind" => "string"}, "allow_nil?" => false},
             "b" => %{"type" => %{"kind" => "integer"}, "allow_nil?" => false}
           }

    assert slice.output == nil
    assert is_binary(slice.zod) and slice.zod =~ "Act_go_inputSchema"
    assert %{"actionId" => "Act#go"} = slice.aria
  end

  test "reader pinned: the Section.Schema adapter landed and reads IR.Boundary" do
    # The intended reader exists (gapfix-adapters-001 at integration) and is
    # the production reader of the Boundary struct (source-level proof,
    # mirroring the no-second-discovery proof style of this suite).
    assert {:module, AshSurface.Compiler.Section.Schema} =
             Code.ensure_loaded(AshSurface.Compiler.Section.Schema)

    referencing =
      for path <- Path.wildcard(@lib_dir <> "/**/*.ex"),
          path not in [@ledgered_schema_source, @canonical_ir_source],
          content = File.read!(path),
          content =~ ~r/AshSurface\.Compiler\.IR\.Boundary/ do
        Path.relative_to(path, @lib_dir)
      end

    assert referencing == ["ash_surface/compiler/section/schema.ex"],
           "IR.Boundary reader changed: #{inspect(referencing)} — re-point the reader pin " <>
             "(lib/ash_surface/compiler/schema.ex + this file)"
  end
end
