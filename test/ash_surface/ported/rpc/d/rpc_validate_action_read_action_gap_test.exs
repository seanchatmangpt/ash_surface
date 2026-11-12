defmodule AshSurface.Ported.Rpc.D.RpcValidateActionReadActionGapTest do
  use ExUnit.Case, async: true

  # The reference tests (CVE-3201 regression) assert that the update/destroy target is loaded
  # with the RPC action's configured `read_action` (`:read_incomplete`, `filter completed ==
  # false`): a completed todo must resolve to not-found. That outcome is the result of Ash
  # executing a filtered read against a data layer; the non-actuating pipeline has no `Ash.get`
  # and the entry table carries no `read_action` option, so both tests keep a loud skip.

  @tag skip:
         "T11 gap (needs execution): validate_action loads the update/destroy target through the rpc action's configured read_action (filter completed == false) via Ash.get against a data layer; AshSurface never performs that read (README: it never actuates) and the entry table carries no read_action option"
  test "validate_action honors read_action and hides a filtered-out record" do
    :ok
  end

  @tag skip:
         "T11 gap (needs execution): validate_action loads the update/destroy target through the rpc action's configured read_action (filter completed == false) via Ash.get against a data layer; AshSurface never performs that read (README: it never actuates) and the entry table carries no read_action option"
  test "validate_action still succeeds for a record the read_action admits" do
    :ok
  end
end
