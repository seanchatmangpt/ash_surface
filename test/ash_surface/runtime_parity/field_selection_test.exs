defmodule AshSurface.RuntimeParity.FieldSelectionTest do
  use ExUnit.Case, async: true

  alias AshSurface.RuntimeParity.FieldSelection, as: FS

  @admitted [:id, :first_name, :last_name, :owner]

  describe "atomize_requested_fields (Rpc.FieldProcessing.Atomizer)" do
    test "client names resolve against the admitted set, nested maps recurse, unknowns are preserved" do
      assert FS.atomize_requested_fields(
               ["id", "firstName", %{"owner" => ["id", "nope"]}],
               :camel_case,
               @admitted
             ) == [:id, :first_name, %{owner: [:id, "nope"]}]
    end

    test "atomizing never mints atoms" do
      # Structural proof (no global atom_count: concurrent async tests mint atoms).
      # Hostile names are built at runtime so no literal in this module interns them;
      # after atomizing, none of them (nor their snake_case form) may exist as an atom.
      uniq = System.unique_integer([:positive])
      names = ["zzAtomizerProbe#{uniq}", "zz_atomizer_probe_#{uniq}", "zzNested#{uniq}Key"]

      assert FS.atomize_requested_fields(names, :camel_case, @admitted) == names

      assert FS.atomize_requested_fields(
               [%{"zzMapProbe#{uniq}" => [hd(names)]}],
               :camel_case,
               @admitted
             ) ==
               [%{"zzMapProbe#{uniq}" => [hd(names)]}]

      hostile =
        names ++
          [
            "zz_atomizer_probe_#{uniq}",
            "zz_nested_#{uniq}_key",
            "zzMapProbe#{uniq}",
            "zz_map_probe_#{uniq}"
          ]

      for n <- hostile do
        assert_raise ArgumentError, fn -> String.to_existing_atom(n) end
      end
    end
  end

  describe "check_for_duplicates (FieldSelector.Validation)" do
    test "duplicates after formatter normalisation are refused with path" do
      assert {:error, {:duplicate_field, :first_name, ["owner"]}} =
               FS.check_for_duplicates(
                 ["firstName", :first_name],
                 ["owner"],
                 :camel_case,
                 @admitted
               )
    end

    test "map keys count, tuples count, unique selections pass, bad entries are typed" do
      assert {:error, {:duplicate_field, :owner, []}} =
               FS.check_for_duplicates(
                 [%{"owner" => ["id"]}, {:owner, 1}],
                 [],
                 :camel_case,
                 @admitted
               )

      assert :ok = FS.check_for_duplicates(["id", "firstName"], [], :camel_case, @admitted)

      assert {:error, {:invalid_field_type, 5, ["x"]}} =
               FS.check_for_duplicates([5], ["x"], :camel_case, @admitted)
    end
  end

  describe "validate_non_empty (FieldSelector.Validation)" do
    test "non-list and empty nested selections are typed refusals" do
      assert {:error, {:requires_field_selection, :owner, ["a"]}} =
               FS.validate_non_empty([], :owner, ["a"])

      assert {:error, {:unsupported_field_combination, :owner, "x", []}} =
               FS.validate_non_empty("x", :owner, [])

      assert :ok = FS.validate_non_empty(["id"], :owner, [])
    end
  end

  describe "select (FieldSelector selection validation)" do
    test "admitted selection resolves; unknown, denied and duplicate selections are refused" do
      assert {:ok, [:id, :first_name]} =
               FS.select(["id", "firstName"], @admitted, [], :camel_case)

      assert {:error, {:unknown_field, "bogus", []}} =
               FS.select(["bogus"], @admitted, [], :camel_case)

      assert {:error, {:denied_field, :last_name, []}} =
               FS.select(["lastName"], @admitted, [:last_name], :camel_case)

      assert {:error, {:duplicate_field, :id, []}} =
               FS.select(["id", "id"], @admitted, [], :camel_case)
    end
  end

  describe "extract (Rpc.FieldExtractor)" do
    test "maps, structs, keyword lists, atom and string keys; absent is :error" do
      assert {:ok, 1} = FS.extract(%{id: 1}, :id)
      assert {:ok, 1} = FS.extract(%{"id" => 1}, :id)
      assert {:ok, 1} = FS.extract(%{id: 1}, "id")
      assert {:ok, 2} = FS.extract([id: 2], :id)
      assert {:ok, _} = FS.extract(%URI{host: "h"}, :host)
      assert :error = FS.extract(%{id: 1}, :nope)
      assert :error = FS.extract(5, :id)
    end
  end

  describe "format_value (Rpc.ValueFormatter / OutputFormatter / InputFormatter)" do
    test "output renames nested keys through lists, leaves structs and scalars alone" do
      out =
        FS.format_value(
          %{first_name: "a", owner: [%{last_name: "b"}], at: ~D[2026-01-01]},
          :output,
          :camel_case
        )

      assert out == %{
               "firstName" => "a",
               "owner" => [%{"lastName" => "b"}],
               "at" => ~D[2026-01-01]
             }
    end

    test "input resolves admitted names, preserves unknown keys, and round-trips" do
      internal = %{first_name: "a", owner: %{last_name: "b"}}
      client = FS.format_value(internal, :output, :camel_case)
      assert FS.format_value(client, :input, :camel_case, @admitted) == internal
      assert FS.format_value(%{"bogus" => 1}, :input, :camel_case, @admitted) == %{"bogus" => 1}
    end
  end
end
