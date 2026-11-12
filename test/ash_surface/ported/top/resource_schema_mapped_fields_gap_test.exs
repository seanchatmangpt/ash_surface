defmodule AshSurface.Ported.Top.ResourceSchemaMappedFieldsGapTest do
  @moduledoc """
  Loud skips for ash_typescript `resource_schema_mapped_fields_test.exs` behaviors ash_surface does
  not have. Not listed on a ledger row (the runnable half is the sibling test file).
  """
  use ExUnit.Case, async: true

  @tag skip:
         "GAP resource_schema_mapped_fields metadata: __type/__primitiveFields are TS type-level discriminators of the record schema; no Zod counterpart is emitted"
  test "resource schema has __type and __primitiveFields metadata with mapped names" do
    flunk("capability missing: record schema metadata discriminators")
  end

  @tag skip:
         "GAP resource_schema_mapped_fields action input keys: compiled action input Zod keeps raw names (archived?); per-action mapped-name keys (isArchived) are not applied (FieldName not wired into the compiler)"
  test "input schema includes mapped field names" do
    flunk("capability missing: FieldName mapping wired into compiled input Zod keys")
  end
end
