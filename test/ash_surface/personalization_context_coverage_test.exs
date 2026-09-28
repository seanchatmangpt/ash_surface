defmodule AshSurface.PersonalizationContextCoverageTest do
  @moduledoc """
  Refusal and normalization laws of `AshSurface.PersonalizationContext`:
  string-dialect source/standing vocabulary normalizes to the atom identity;
  anything outside the vocabulary (unknown atom, known-but-foreign atom, or a
  string naming no atom at all) is refused with the same `unknown <field>`
  message; duplicate facet identities, non-map facets, missing or empty
  required fields, and non-string ref lists are refused — personalization is
  never projected from malformed facets.
  """

  use ExUnit.Case, async: true

  alias AshSurface.PersonalizationContext

  @facet %{dimension: "goal", value_ref: "profile:goal:consistency", source: :USER_STATED}

  test "string source and standing normalize to the atom-dialect identity" do
    atom_ctx = PersonalizationContext.create("s", [Map.put(@facet, :standing, :ALIVE)])

    string_ctx =
      PersonalizationContext.create("s", [
        %{"dimension" => "goal", "valueRef" => "profile:goal:consistency"}
        |> Map.put("source", "user_stated")
        |> Map.put("standing", "alive")
      ])

    assert string_ctx.state_digest == atom_ctx.state_digest
    assert [%{"source" => "USER_STATED", "standing" => "ALIVE"}] = string_ctx.facets
  end

  test "duplicate facet identities are refused" do
    assert_raise ArgumentError, "personalization facet ids must be unique", fn ->
      PersonalizationContext.create("s", [@facet, @facet])
    end
  end

  test "an unknown context standing is refused" do
    assert_raise ArgumentError, "unknown standing: :GLORIOUS", fn ->
      PersonalizationContext.create("s", [@facet], standing: :GLORIOUS)
    end
  end

  test "a non-map facet is refused" do
    assert_raise ArgumentError, "personalization facet must be a map", fn ->
      PersonalizationContext.create("s", ["goal"])
    end
  end

  test "an empty required string is refused" do
    assert_raise ArgumentError, "dimension must be a non-empty string", fn ->
      PersonalizationContext.create("s", [%{@facet | dimension: ""}])
    end
  end

  test "a missing required field is refused by key" do
    assert_raise ArgumentError, "personalization facet missing source", fn ->
      PersonalizationContext.create("s", [Map.delete(@facet, :source)])
    end
  end

  test "an atom source outside the vocabulary is refused" do
    assert_raise ArgumentError, "unknown source: :GUESSED", fn ->
      PersonalizationContext.create("s", [%{@facet | source: :GUESSED}])
    end
  end

  test "a string source naming an existing but foreign atom is refused as the original string" do
    assert_raise ArgumentError, ~s(unknown source: "alive"), fn ->
      PersonalizationContext.create("s", [%{@facet | source: "alive"}])
    end
  end

  test "a string source naming no existing atom is refused with the same message" do
    assert_raise ArgumentError, ~s(unknown source: "zz_never_an_atom_qx"), fn ->
      PersonalizationContext.create("s", [%{@facet | source: "zz_never_an_atom_qx"}])
    end
  end

  test "ref lists must be lists of strings" do
    assert_raise ArgumentError, "evidence_refs must contain only strings", fn ->
      PersonalizationContext.create("s", [Map.put(@facet, :evidence_refs, [:e])])
    end

    assert_raise ArgumentError, "evidence_refs must be a list", fn ->
      PersonalizationContext.create("s", [@facet], evidence_refs: "e")
    end
  end
end
