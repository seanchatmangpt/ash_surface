defmodule AshSurface.Ported.Rpc.RunAction.KeywordGapTest do
  use ExUnit.Case, async: true

  describe "core ash functionality with keyword fields" do
    @tag skip:
           "T6b gap: the reference test executes the action through a data layer (Ash.create!/changeset validation); the RuntimeParity pipeline core is non-actuating (README: 'it never actuates'; operator decision D18)"
    test "creates todo with keyword options using Ash.create! directly" do
      :ok
    end

    @tag skip:
           "T6b gap: the reference test executes the action through a data layer (Ash.create!/changeset validation); the RuntimeParity pipeline core is non-actuating (README: 'it never actuates'; operator decision D18)"
    test "validates keyword field constraints using Ash directly" do
      :ok
    end
  end
end
