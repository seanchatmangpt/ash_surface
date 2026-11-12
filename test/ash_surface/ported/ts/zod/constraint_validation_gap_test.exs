defmodule AshSurface.Ported.TS.Zod.ConstraintValidationGapTest do
  @moduledoc """
  Loud skips for behaviors of ash_typescript `test/ts/zod/**` that ash_surface does not have.
  Not listed on a ledger row (the rows' runnable halves are the sibling `*_test.exs` files).
  """
  use ExUnit.Case, async: true

  @tag skip:
         "GAP zod custom type mapping: a type with typescript_type_name (Todo.PriorityScore) emits z.unknown() without an explicit zod_mapping_overrides entry; the reference derives z.number() from the type automatically"
  test "testPriorityScoreStringRejected without an override" do
    flunk("capability missing: zod fragment derived from typescript_type_name")
  end

  @tag skip:
         "GAP zod third-party type: AshMoney.Types.Money emits z.unknown() without an explicit zod_mapping_overrides entry; the reference derives { amount: string; currency: string } automatically"
  test "testMoneyMissingAmount without an override" do
    flunk("capability missing: AshMoney.Types.Money default zod mapping")
  end
end
