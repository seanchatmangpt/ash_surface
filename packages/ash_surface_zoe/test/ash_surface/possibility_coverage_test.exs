defmodule AshSurface.PossibilityCoverageTest do
  @moduledoc """
  Pins the admission and canonicalization laws of `AshSurface.Possibility`
  and `AshSurface.PossibilitySet` against the real modules:

    * `create/3` is `create/4` with empty opts: the documented defaults
      (`:PRESERVED`, `:REVERSIBLE`, `:SELECT`, empty lists) and the identical
      identity and state digest;
    * string-list fields refuse non-lists and non-string members with a
      field-naming `ArgumentError`, never a silent coercion;
    * `expires_at` is canonicalized to ISO-8601: a `DateTime` and its
      ISO-8601 string are the same state (same digest, same wire value);
    * a set admits only `%Possibility{}` members and only the declared
      standings.
  """

  use ExUnit.Case, async: true

  alias AshSurface.{Possibility, PossibilitySet}

  @subject "zoe:event:holiday#north_gate"
  @capability "Zoe.Security.request_reinforcement"

  describe "Possibility" do
    test "create/3 applies the documented defaults and equals create/4 with []" do
      three = Possibility.create(@subject, @capability, "Reinforce")
      four = Possibility.create(@subject, @capability, "Reinforce", [])

      assert three == four
      assert three.status == :PRESERVED
      assert three.reversibility == :REVERSIBLE
      assert three.authority_ceiling == :SELECT
      assert three.requirements == []
      assert three.evidence_refs == []
      assert "pos_" <> suffix = three.possibility_id
      assert byte_size(suffix) == 16
      assert Possibility.to_map(three)["doAuthority"] == false
    end

    test "string-list fields refuse non-string members, naming the field" do
      assert_raise ArgumentError, "requirements must contain only strings", fn ->
        Possibility.create(@subject, @capability, "Reinforce", requirements: ["ok", :atom])
      end

      assert_raise ArgumentError, "evidence_refs must contain only strings", fn ->
        Possibility.create(@subject, @capability, "Reinforce", evidence_refs: [1])
      end
    end

    test "string-list fields refuse non-lists, naming the field" do
      assert_raise ArgumentError, "requirements must be a list", fn ->
        Possibility.create(@subject, @capability, "Reinforce", requirements: "badge")
      end

      assert_raise ArgumentError, "evidence_refs must be a list", fn ->
        Possibility.create(@subject, @capability, "Reinforce", evidence_refs: %{})
      end
    end

    test "a DateTime expires_at and its ISO-8601 string are the same state" do
      dt = ~U[2026-09-28 12:00:00Z]
      iso = DateTime.to_iso8601(dt)

      from_dt = Possibility.create(@subject, @capability, "Reinforce", expires_at: dt)
      from_iso = Possibility.create(@subject, @capability, "Reinforce", expires_at: iso)

      assert from_dt.state_digest == from_iso.state_digest
      assert from_dt.possibility_id == from_iso.possibility_id
      assert Possibility.to_map(from_dt)["expiresAt"] == "2026-09-28T12:00:00Z"
      assert Possibility.to_map(from_iso)["expiresAt"] == "2026-09-28T12:00:00Z"

      # Expiry is state, not identity: it moves the digest, never the id.
      none = Possibility.create(@subject, @capability, "Reinforce")
      assert none.possibility_id == from_dt.possibility_id
      refute none.state_digest == from_dt.state_digest
    end
  end

  describe "PossibilitySet" do
    setup do
      %{option: Possibility.create(@subject, @capability, "Reinforce")}
    end

    test "refuses members that are not Possibility values", %{option: option} do
      assert_raise ArgumentError,
                   "possibilities must contain only AshSurface.Possibility values",
                   fn ->
                     PossibilitySet.create(@subject, "keep gate safe", [
                       option,
                       Possibility.to_map(option)
                     ])
                   end
    end

    test "refuses an undeclared standing", %{option: option} do
      assert_raise ArgumentError, "unknown standing: :SELECTED", fn ->
        PossibilitySet.create(@subject, "keep gate safe", [option], standing: :SELECTED)
      end
    end

    test "string-list fields refuse non-string members, naming the field", %{option: option} do
      assert_raise ArgumentError, "constraints must contain only strings", fn ->
        PossibilitySet.create(@subject, "keep gate safe", [option], constraints: [:budget])
      end

      assert_raise ArgumentError, "source_episode_refs must contain only strings", fn ->
        PossibilitySet.create(@subject, "keep gate safe", [option], source_episode_refs: [nil])
      end
    end

    test "string-list fields refuse non-lists, naming the field", %{option: option} do
      assert_raise ArgumentError, "evidence_refs must be a list", fn ->
        PossibilitySet.create(@subject, "keep gate safe", [option], evidence_refs: "obs_1")
      end

      assert_raise ArgumentError, "constraints must be a list", fn ->
        PossibilitySet.create(@subject, "keep gate safe", [option], constraints: nil)
      end
    end
  end
end
