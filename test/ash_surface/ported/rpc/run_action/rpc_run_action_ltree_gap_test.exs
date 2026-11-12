defmodule AshSurface.Ported.Rpc.RunAction.LtreeGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "GU7 gap: the rejection is AshPostgres.Ltree's own cast error for the escape? constraint (message 'String input casting is not supported when the :escape? constraint is enabled'); ash_postgres is not a dependency and the in-test ltree-shaped fixture type is not the real type, so asserting it would verify the fixture"
  test "strict hierarchy rejects string input" do
    :ok
  end
end
