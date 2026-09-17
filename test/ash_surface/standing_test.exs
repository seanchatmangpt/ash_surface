defmodule AshSurface.StandingTest do
  @moduledoc """
  F3 (finish-standing-022): the single canonical owner of the standing
  vocabulary.

  Pins the admitted base set {ALIVE, PARTIAL_ALIVE, BLOCKED, BUILD_BROKEN,
  UNSUPPORTED}, the open REFUSED class (`:REFUSED`, `:"REFUSED_*"`), the
  refusal of `:UNKNOWN` and every off-vocabulary value, and the constructor
  contract (`validate!/1`) that projection constructors MUST route caller
  assertions through.
  """

  use ExUnit.Case, async: true
  alias AshSurface.Standing

  @base_standings [:ALIVE, :PARTIAL_ALIVE, :BLOCKED, :BUILD_BROKEN, :UNSUPPORTED]

  describe "base vocabulary" do
    test "admits exactly the F3 base standings, in canonical order" do
      assert Standing.base_standings() == @base_standings
    end

    test "every base member is valid, not a refusal, and survives validate!" do
      for standing <- @base_standings do
        assert Standing.valid?(standing)
        refute Standing.refused?(standing)
        assert Standing.validate!(standing) == standing
      end
    end
  end

  describe "REFUSED class" do
    test "admits bare :REFUSED and every :REFUSED_* atom, classified as refusals" do
      for standing <- [
            :REFUSED,
            :REFUSED_NO_AUTHORITY,
            :REFUSED_UNKNOWN_ACTION,
            :REFUSED_INVALID_SUBJECT
          ] do
        assert Standing.valid?(standing)
        assert Standing.refused?(standing)
        assert Standing.validate!(standing) == standing
      end
    end

    test "the prefix is exact: refused-ish atoms outside the class are not admitted" do
      refute Standing.valid?(:REFUSEDISH)
      refute Standing.valid?(:AUTHORITY_REFUSED)
      refute Standing.refused?(:ALIVE)
    end
  end

  describe "off-vocabulary refusals" do
    test ":UNKNOWN is not a standing (post-dispatch outcome, never a standing)" do
      refute Standing.valid?(:UNKNOWN)

      assert_raise ArgumentError, ~r/invalid standing :UNKNOWN/, fn ->
        Standing.validate!(:UNKNOWN)
      end
    end

    test "non-atoms are refused, never coerced" do
      for bad <- ["ALIVE", "REFUSED_NO_AUTHORITY", 7, nil, %{}, {:ALIVE}] do
        refute Standing.valid?(bad)

        assert_raise ArgumentError, ~r/invalid standing/, fn ->
          Standing.validate!(bad)
        end
      end
    end

    test "the refusal message names the offender and the admitted vocabulary" do
      error =
        assert_raise ArgumentError, ~r/invalid standing :BOGUS/, fn ->
          Standing.validate!(:BOGUS)
        end

      message = Exception.message(error)

      assert message =~ ":BOGUS"
      assert message =~ ":ALIVE"
      assert message =~ ":PARTIAL_ALIVE"
      assert message =~ "REFUSED"
    end
  end
end
