defmodule AshSurface.Ported.TS.Valibot.ValibotGapTest do
  @moduledoc """
  ash_typescript `test/ts/valibot/**`, `customValibotSchemas.ts`, `custom/nestedValibotSchemas.ts`
  and `runValibotTests.ts` exercise generated Valibot schemas. ash_surface projects Zod only:
  the `generate_valibot_schemas` / `valibot_*` config keys are accepted (config.ex) but no
  Valibot emitter exists, and README.md has no Valibot sentence to support a non_goal.
  Recorded as skipped_gap, operator decision requested (see receipts/wave3-t17.md).
  """
  use ExUnit.Case, async: true

  @tag skip: "T17-VALIBOT-GAP: no Valibot projector (Zod only); no README non_goal sentence"
  test "valibot shouldPass/constraintValidation: generated Valibot schemas accept valid constraints" do
    flunk("unreachable until a Valibot projector exists")
  end

  @tag skip: "T17-VALIBOT-GAP: no Valibot projector (Zod only); no README non_goal sentence"
  test "valibot shouldFail/constraintValidation: generated Valibot schemas reject invalid constraints" do
    flunk("unreachable until a Valibot projector exists")
  end

  @tag skip: "T17-VALIBOT-GAP: no Valibot projector (Zod only); no README non_goal sentence"
  test "valibot customTypeSchemas + customValibotSchemas + nestedValibotSchemas overrides" do
    flunk("unreachable until a Valibot projector exists")
  end

  @tag skip: "T17-VALIBOT-GAP: no Valibot projector (Zod only); no README non_goal sentence"
  test "runValibotTests runner executes the valibot cases under node" do
    flunk("unreachable until a Valibot projector exists")
  end
end
