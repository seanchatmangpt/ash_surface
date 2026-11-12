defmodule AshSurface.Ported.Top.FieldFormatterAtomSafetyTest do
  @moduledoc """
  Port of ash_typescript `field_formatter_atom_safety_test.exs` (CVE-3192 / CVE-3209): client-supplied
  field names never mint atoms. `FieldFormatter.resolve_field_name/2` maps to
  `AshSurface.FieldName.parse_input/2` (`{:ok, atom} | :error`, the unknown-name branch replaces
  the reference's "return the binary"); typed-struct selection goes through the real
  `AshSurface.Ported.RFP` requested-fields processor.
  """
  use ExUnit.Case, async: true

  alias AshSurface.FieldName
  alias AshSurface.Ported.RFP

  defp atom_exists?(name) when is_binary(name) do
    _ = String.to_existing_atom(name)
    true
  rescue
    ArgumentError -> false
  end

  test "resolves an existing field name to its atom" do
    _ = :user_name
    assert FieldName.parse_input("userName", :camel_case) == {:ok, :user_name}
  end

  test "passes atoms through unchanged" do
    assert FieldName.parse_input(:already_atom, :camel_case) == {:ok, :already_atom}
  end

  test "never mints a new atom for an unknown field name" do
    unique = "atom_bomb_field_name_#{System.unique_integer([:positive])}_xyz"
    camel = "atomBombFieldName#{System.unique_integer([:positive])}Xyz"

    refute atom_exists?(unique)
    assert FieldName.parse_input(camel, :camel_case) == :error
    refute atom_exists?(unique)
    refute atom_exists?(camel)
  end

  test "does not mint atoms for a batch of unique field names" do
    names = for i <- 1..1_000, do: "atomBombBatch#{i}_#{System.unique_integer([:positive])}"

    Enum.each(names, fn name ->
      assert FieldName.parse_input(name, :camel_case) == :error
      refute atom_exists?(name)
      refute atom_exists?(Macro.underscore(name))
    end)
  end

  test "does not raise on field names longer than the 255-char atom limit" do
    long = String.duplicate("a", 300)
    assert FieldName.parse_input(long, :camel_case) == :error
  end

  describe "typed struct field selection (CVE-3209)" do
    defp select_statistics_fields(fields) do
      RFP.process(AshSurface.Ported.Todo, :read, [%{"statistics" => fields}])
    end

    test "an unknown field name is rejected without minting an atom" do
      name = "zzAtomBombStat#{System.unique_integer([:positive])}"
      refute atom_exists?(Macro.underscore(name))

      assert {:error, {:unknown_field, unknown, "field_constrained_type", [:statistics]}} =
               select_statistics_fields([name])

      assert is_binary(unknown)
      refute atom_exists?(unknown)
    end

    test "a batch of unique unknown field names mints no atoms" do
      names = for i <- 1..500, do: "zzAtomBombBatch#{i}_#{System.unique_integer([:positive])}"

      Enum.each(names, fn name ->
        assert {:error, {:unknown_field, _, _, _}} = select_statistics_fields([name])
        refute atom_exists?(Macro.underscore(name))
      end)
    end

    test "valid field names still resolve, including mapped ones" do
      assert {:ok, {_select, _load, template}} =
               select_statistics_fields(["viewCount", "allCompleted"])

      assert [statistics: [:view_count, :all_completed?]] = template
    end
  end
end
