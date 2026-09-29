defmodule AshSurface.HumanSurfaceCoverageTest do
  @moduledoc """
  Pins the admission laws of `AshSurface.HumanSurface.create/2`: the 1-arity
  default is an empty PARTIAL_ALIVE OBSERVE-only surface over the five stable
  areas, and unknown standings, non-list collections and wrongly typed
  members are refused with precise `ArgumentError`s.
  """
  use ExUnit.Case, async: true

  alias AshSurface.{CommitmentBoundary, HumanSurface, ManufactureTrace, PersonalizationContext}

  test "create/1 defaults to an empty surface equal to create/2 with []" do
    surface = HumanSurface.create("person:1")

    assert surface == HumanSurface.create("person:1", [])
    assert surface.standing == :PARTIAL_ALIVE
    assert surface.authority_boundary == :OBSERVE
    assert surface.areas == [:TODAY, :BIBLE, :LIFE, :ZOE, :YOU]
    assert surface.you == %{"journeyRefs" => []}
    assert surface.zoe == %{"possibilitySetRefs" => [], "commitmentBoundaryRefs" => []}
    assert surface.surface_id == "hs_" <> binary_part(surface.state_digest, 0, 16)
    assert HumanSurface.to_map(surface)["doAuthority"] == false
  end

  test "the default LIFE area references admitted context and trace ids" do
    context = PersonalizationContext.create("person:1", [])
    trace = ManufactureTrace.create("person:1", "artifact:plan", "zoela:manufacturer")

    surface =
      HumanSurface.create("person:1",
        personalization_contexts: [context],
        manufacture_traces: [trace]
      )

    assert surface.life == %{
             "outcomeHypothesisRefs" => [],
             "personalizationContextRefs" => [context.context_id],
             "manufactureTraceRefs" => [trace.trace_id]
           }

    refute surface.state_digest == HumanSurface.create("person:1").state_digest
  end

  test "unknown standing is refused" do
    assert_raise ArgumentError, "unknown standing: :DONE", fn ->
      HumanSurface.create("person:1", standing: :DONE)
    end
  end

  test "struct collections must be lists of the exact struct type" do
    boundary = CommitmentBoundary.create("person:1", "Zoe.Plan.commit", "books the venue")

    assert_raise ArgumentError,
                 "possibility_sets must contain only AshSurface.PossibilitySet values",
                 fn -> HumanSurface.create("person:1", possibility_sets: [boundary]) end

    assert_raise ArgumentError, "journeys must be a list", fn ->
      HumanSurface.create("person:1", journeys: %{})
    end
  end

  test "evidence and receipt refs must be lists of strings" do
    assert_raise ArgumentError, "evidence_refs must contain only strings", fn ->
      HumanSurface.create("person:1", evidence_refs: [1])
    end

    assert_raise ArgumentError, "receipt_refs must be a list", fn ->
      HumanSurface.create("person:1", receipt_refs: "receipt_1")
    end
  end
end
