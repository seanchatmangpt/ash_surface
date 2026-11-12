defmodule AshSurface.Ported.Rpc.RunAction.FieldMappingGapTest do
  use ExUnit.Case, async: true

  describe "error cases with mapped names" do
    @tag skip:
           "T6b gap: the reference test executes the action through a data layer (Ash.create!/changeset validation); the RuntimeParity pipeline core is non-actuating (README: 'it never actuates'; operator decision D18)"
    test "validation error with missing required argument" do
      :ok
    end
  end
end
