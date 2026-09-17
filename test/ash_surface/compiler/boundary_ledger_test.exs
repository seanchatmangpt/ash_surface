defmodule AshSurface.Compiler.BoundaryLedgerTest do
  @moduledoc """
  The dead-code ledger for `AshSurface.Compiler.IR.Boundary`
  (gapfix-test-surface-015), as a permanent tripwire.

  Law: the Boundary slice is the canonical v07 shape (compiler/ir.ex) and the
  schema section's output (`AshSurface.Compiler.Schema.build/2` constructs it
  at the ledgered site). It is exercised field-complete by
  `AshSurface.Compiler.SchemaSectionTest` (zod, input, output, aria) — but it
  has NO production reader: the intended reader is the orchestrator-facing
  `AshSurface.Compiler.Section.Schema` adapter (compiler.ex's default
  binding), which has not landed yet.

  These rows pin that pending state so it can never rot silently:

    * if the slice's shape changes owner (no longer built as `IR.Boundary`),
      or
    * if any module becomes a reader of the Boundary struct,

      the rows below fail and force the ledger comment in
      lib/ash_surface/compiler/schema.ex and this file to be re-pointed at
      the real reader. Wiring a reader silently — without retiring this
      ledger — is the failure mode being guarded.
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

  test "ledger state: no production reader exists yet — the Section.Schema adapter has not landed" do
    # The intended reader must not exist yet; when it does, retire this row
    # and re-point the ledger comment at the concrete reader.
    refute match?({:module, _}, Code.ensure_loaded(AshSurface.Compiler.Section.Schema)),
           "AshSurface.Compiler.Section.Schema landed — retire the Boundary dead-code " <>
             "ledger (lib/ash_surface/compiler/schema.ex + this file) and pin the real reader"

    # And the built-but-unread state is real: no module outside the schema
    # section (its construction site) and the canonical IR declaration
    # references the Boundary struct (source-level proof, mirroring the
    # no-second-discovery proof style of this suite).
    referencing =
      for path <- Path.wildcard(@lib_dir <> "/**/*.ex"),
          path not in [@ledgered_schema_source, @canonical_ir_source],
          content = File.read!(path),
          content =~ ~r/AshSurface\.Compiler\.IR\.Boundary/ do
        Path.relative_to(path, @lib_dir)
      end

    assert referencing == [],
           "IR.Boundary gained a reader: #{inspect(referencing)} — retire the dead-code ledger"
  end
end
