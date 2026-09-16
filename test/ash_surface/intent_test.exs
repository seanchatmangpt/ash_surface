defmodule AshSurface.IntentTest do
  @moduledoc """
  Chicago suite for AshSurface.Intent, the SurfaceIntent consequence edge:

    * construction: the addressed triple lands in the struct with bookkeeping,
    * content-addressed identity: `intent_id` is the deterministic sha256 of
      the ordered triple (golden vector pinned), stable across time and
      sensitive to every element of the triple,
    * purity: `create` never mutates its inputs, `to_map` is a pure read, and
      repeated creation of the same triple is idempotent in identity,
    * the structural invariant: the module exports creation + inspection ONLY —
      no execute/submit/dispatch path exists.
  """

  use ExUnit.Case, async: true
  alias AshSurface.Intent

  @action_id "zoe:KingdomNeed#assign_role"
  @input %{"role" => "care_driver", "assignee" => "person_01"}
  @subject_ref "zoe:KingdomNeed#need_42"

  @vector_time ~U[2026-01-15 12:00:00Z]
  @later_time ~U[2026-06-01 08:30:00Z]

  # sha256 over Jason.encode!([@action_id, @input, @subject_ref]) — recorded 2026-09-15.
  @golden_intent_id "8e856f9e0f25d585bf47139094ed2605b36f8b1708befb551afc0d30f4d3943a"

  describe "construction" do
    test "records the addressed triple with content-addressed id and timestamp" do
      intent = Intent.create(@action_id, @input, @subject_ref, created_at: @vector_time)

      assert %Intent{} = intent
      assert intent.surface_action_id == @action_id
      assert intent.input == @input
      assert intent.subject_ref == @subject_ref
      assert intent.created_at == @vector_time
      assert intent.intent_id == @golden_intent_id
    end

    test "create/3 without opts defaults created_at to now" do
      before = DateTime.utc_now()
      intent = Intent.create(@action_id, @input, @subject_ref)
      after_now = DateTime.utc_now()

      assert %DateTime{} = intent.created_at
      assert DateTime.compare(intent.created_at, before) != :lt
      assert DateTime.compare(intent.created_at, after_now) != :gt
    end

    test "the struct carries exactly the five contract fields" do
      intent = Intent.create(@action_id, @input, @subject_ref)

      assert intent |> Map.delete(:__struct__) |> Map.keys() |> Enum.sort() == [
               :created_at,
               :input,
               :intent_id,
               :subject_ref,
               :surface_action_id
             ]
    end
  end

  describe "content-addressed intent_id" do
    test "is the sha256 hex of the canonical JSON of the ordered triple (golden vector)" do
      canonical_json = Jason.encode!([@action_id, @input, @subject_ref])
      expected = :crypto.hash(:sha256, canonical_json) |> Base.encode16(case: :lower)

      intent = Intent.create(@action_id, @input, @subject_ref, created_at: @vector_time)

      assert intent.intent_id == expected
      assert intent.intent_id == @golden_intent_id
      assert byte_size(intent.intent_id) == 64
      assert intent.intent_id =~ ~r/^[0-9a-f]{64}$/
    end

    test "is deterministic: same triple, same id, regardless of when recorded" do
      first = Intent.create(@action_id, @input, @subject_ref, created_at: @vector_time)
      second = Intent.create(@action_id, @input, @subject_ref, created_at: @later_time)
      third = Intent.create(@action_id, @input, @subject_ref)

      assert first.intent_id == second.intent_id
      assert second.intent_id == third.intent_id
      assert first.intent_id == @golden_intent_id
    end

    test "is sensitive to the surface_action_id element" do
      base = Intent.create(@action_id, @input, @subject_ref)
      moved = Intent.create("zoe:KingdomNeed#reassign_role", @input, @subject_ref)

      # sha256(["zoe:KingdomNeed#reassign_role", @input, @subject_ref]) — recorded 2026-09-15.
      assert moved.intent_id == "c95dc57cb7d4e3e90d75f4915d2bd5ee6c60f0175d7190ed2e447daeafd7f65d"
      assert moved.intent_id != base.intent_id
    end

    test "is sensitive to the input element" do
      base = Intent.create(@action_id, @input, @subject_ref)

      changed =
        Intent.create(
          @action_id,
          %{"role" => "intercessor", "assignee" => "person_01"},
          @subject_ref
        )

      # sha256([@action_id, %{"role" => "intercessor", ...}, @subject_ref]) — recorded 2026-09-15.
      assert changed.intent_id ==
               "1c7823c220604396540075c9e93f4202eb4b91a94966b145bbcf3abbc0a1b0bb"

      assert changed.intent_id != base.intent_id
    end

    test "is sensitive to the subject_ref element" do
      base = Intent.create(@action_id, @input, @subject_ref)
      retargeted = Intent.create(@action_id, @input, "zoe:KingdomNeed#need_43")

      # sha256([@action_id, @input, "zoe:KingdomNeed#need_43"]) — recorded 2026-09-15.
      assert retargeted.intent_id ==
               "0ac25477b7198f3bc53dd77e72165fcad8b5e170944ee359a4e3698be528f85e"

      assert retargeted.intent_id != base.intent_id
    end

    test "is sensitive to input value changes invisible to key sets" do
      base = Intent.create(@action_id, @input, @subject_ref)
      deepened = Intent.create(@action_id, Map.put(@input, "role", "care_driver+"), @subject_ref)

      assert deepened.intent_id != base.intent_id
    end

    test "is insensitive to input map key order (canonical JSON encoding)" do
      reordered =
        Intent.create(
          @action_id,
          %{"assignee" => "person_01", "role" => "care_driver"},
          @subject_ref
        )

      assert reordered.intent_id == @golden_intent_id
    end

    test "is sensitive to triple element order (position, not set, is identity)" do
      base = Intent.create(@action_id, @input, @subject_ref)

      # subject where the action was: a different edge, so a different id,
      # even though the multiset of arguments is the same shape.
      swapped = Intent.create(@subject_ref, @input, @action_id)

      assert swapped.intent_id != base.intent_id
    end
  end

  describe "purity" do
    test "create never mutates its input arguments" do
      input = %{"role" => "care_driver", "assignee" => "person_01"}
      _intent = Intent.create(@action_id, input, @subject_ref)

      assert input == %{"role" => "care_driver", "assignee" => "person_01"}
      assert map_size(input) == 2
    end

    test "to_map is a pure read: identical output, struct untouched" do
      intent = Intent.create(@action_id, @input, @subject_ref, created_at: @vector_time)

      first = Intent.to_map(intent)
      second = Intent.to_map(intent)

      assert first == second
      assert intent == Intent.create(@action_id, @input, @subject_ref, created_at: @vector_time)

      assert first == %{
               "surfaceActionId" => @action_id,
               "input" => @input,
               "subjectRef" => @subject_ref,
               "createdAt" => "2026-01-15T12:00:00Z",
               "intentId" => @golden_intent_id
             }
    end

    test "creating the same edge repeatedly yields identical ids (no hidden state)" do
      ids =
        for _ <- 1..5,
            into: MapSet.new(),
            do: Intent.create(@action_id, @input, @subject_ref).intent_id

      assert MapSet.size(ids) == 1
      assert Enum.member?(ids, @golden_intent_id)
    end
  end

  describe "structural invariant: creation + inspection only" do
    test "the module exports exactly create and to_map" do
      # defstruct machinery (__struct__/0,1) is not a module capability;
      # create/4 is the opts-carrying form of create/3.
      exports =
        Intent.__info__(:functions)
        |> Enum.reject(fn {name, _arity} -> name == :__struct__ end)
        |> Enum.sort()

      assert exports == [create: 3, create: 4, to_map: 1]
    end

    test "no execute/submit/dispatch path exists" do
      forbidden = [
        :execute,
        :submit,
        :dispatch,
        :run,
        :perform,
        :actuate,
        :fire,
        :invoke,
        :call,
        :apply,
        :send,
        :commit
      ]

      exports = Intent.__info__(:functions) |> Keyword.keys()

      assert Enum.filter(exports, &(&1 in forbidden)) == []
    end

    test "the struct carries no transport, receipt, or outcome channel" do
      intent = Intent.create(@action_id, @input, @subject_ref)

      refute Map.has_key?(intent, :transport)
      refute Map.has_key?(intent, :receipt)
      refute Map.has_key?(intent, :outcome)
      refute Map.has_key?(intent, :result)
    end
  end
end
