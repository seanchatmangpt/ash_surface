defmodule AshSurface.Intent.CandidateTest do
  use ExUnit.Case, async: true

  alias AshSurface.Intent
  alias AshSurface.Intent.Candidate
  alias AshSurface.Intent.IR

  describe "create/1 shapes (canonical-local declarations)" do
    test "SurfaceIntent.create/3 records the will-to-act with a content-addressed identity" do
      intent = Intent.create("volunteer.record", %{hours: 4}, "zoe:Member#member_7")

      assert %Intent{
               surface_action_id: "volunteer.record",
               input: %{hours: 4},
               subject_ref: "zoe:Member#member_7",
               created_at: %DateTime{},
               intent_id: id
             } = intent

      assert String.starts_with?(id, "intent_")

      twin = Intent.create("volunteer.record", %{hours: 4}, "zoe:Member#member_7")
      assert twin.intent_id == id
    end

    test "IR.create/3 defaults absent sections to nil" do
      assert %IR{action_id: "a1", capability: nil, semantic: nil} = IR.create("a1")
    end
  end

  describe "to_candidate/2 full-sections golden" do
    test "projects intent and full IR sections into the exact candidate envelope" do
      intent =
        Intent.create(
          "milestone.record",
          %{"member_id" => "m-7", "cost_physical" => 3},
          "zoe:Member#m-7"
        )

      ir =
        IR.create(
          "milestone.record",
          %{capability_id: "cap:milestone:record:v1"},
          %{semantic_id: "sem:milestone:record", subject_iri: "zoe:Member#m-7"}
        )

      assert Candidate.to_candidate(intent, ir) == %{
               capability_id: "cap:milestone:record:v1",
               subject_iri: "zoe:Member#m-7",
               input: %{"member_id" => "m-7", "cost_physical" => 3},
               semantic_id: "sem:milestone:record",
               standing: :candidate,
               authority: :none
             }
    end
  end

  describe "to_candidate/2 with nil sections" do
    test "nil sections carry nils honestly, never fabricated defaults" do
      intent = Intent.create("unknown.action", :pending, nil)
      ir = IR.create("unknown.action")

      envelope = Candidate.to_candidate(intent, ir)

      assert envelope.capability_id == nil
      assert envelope.subject_iri == nil
      assert envelope.semantic_id == nil
      assert envelope.standing == :candidate
      assert envelope.authority == :none
    end

    test "a present section missing a field still yields nil for that field" do
      intent = Intent.create("partial.action", %{}, "zoe:Member#m-9")

      ir =
        IR.create("partial.action", %{capability_id: "cap:partial:v1"}, %{
          subject_iri: "zoe:Member#m-9"
        })

      envelope = Candidate.to_candidate(intent, ir)

      assert envelope.capability_id == "cap:partial:v1"
      assert envelope.subject_iri == "zoe:Member#m-9"
      assert envelope.semantic_id == nil
    end
  end

  describe "to_candidate/2 input passthrough" do
    test "input passes through untransformed, including terms no encoder would survive" do
      raw = {:tuple, %{"nested" => [1, 2, %{deep: true}]}}
      intent = Intent.create("odd.action", raw, "zoe:Member#m-1")
      ir = IR.create("odd.action", %{capability_id: "c"}, %{semantic_id: "s", subject_iri: "i"})

      envelope = Candidate.to_candidate(intent, ir)

      assert envelope.input === raw
      assert envelope.input == {:tuple, %{"nested" => [1, 2, %{deep: true}]}}
    end
  end
end
