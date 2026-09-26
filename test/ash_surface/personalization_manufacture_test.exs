defmodule AshSurface.PersonalizationManufactureTest do
  use ExUnit.Case, async: true

  alias AshSurface.{ManufactureTrace, PersonalizationContext}

  test "USER_STATED profile facet remains distinct from inference and subject-private" do
    context =
      PersonalizationContext.create(
        "person:demo",
        [
          %{
            dimension: "life:outcome",
            value_ref: "life:outcome:consistency",
            source: :USER_STATED,
            standing: :ALIVE,
            evidence_refs: ["evidence:user-selection"]
          }
        ],
        consent_ref: "consent:subject-only",
        standing: :ALIVE
      )

    map = PersonalizationContext.to_map(context)
    [facet] = map["facets"]

    assert facet["source"] == "USER_STATED"
    assert facet["standing"] == "ALIVE"
    assert map["privacyScope"] == "SUBJECT_PRIVATE"
    assert map["shareScope"] == "SUBJECT_ONLY"
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["doAuthority"] == false
  end

  test "INFERRED profile facet requires an explicit falsifier" do
    assert_raise ArgumentError, ~r/requires a falsifier/, fn ->
      PersonalizationContext.create(
        "person:demo",
        [
          %{
            dimension: "life:outcome",
            value_ref: "life:outcome:consistency",
            source: :INFERRED,
            standing: :UNKNOWN
          }
        ]
      )
    end
  end

  test "personalization context digest is invariant to facet order" do
    left = %{
      dimension: "life:outcome",
      value_ref: "life:outcome:consistency",
      source: :USER_STATED,
      standing: :ALIVE
    }

    right = %{
      dimension: "practice:preference",
      value_ref: "practice:audio",
      source: :OBSERVED,
      standing: :PARTIAL_ALIVE
    }

    a = PersonalizationContext.create("person:demo", [left, right])
    b = PersonalizationContext.create("person:demo", [right, left])

    assert a.state_digest == b.state_digest
  end

  test "A=mu(O*) refuses an O* reference outside the full admitted intersection" do
    assert_raise ArgumentError, ~r/every O\* reference/, fn ->
      ManufactureTrace.create(
        "person:demo",
        "artifact:devotional-candidate",
        "manufacturer:semantic-map",
        observed_refs: ["o:goal"],
        admitted_refs: ["o:goal"],
        grounded_refs: ["o:goal"],
        bounded_refs: [],
        aligned_refs: ["o:goal"],
        o_star_refs: ["o:goal"]
      )
    end
  end

  test "ALIVE manufacture trace requires a receipt" do
    assert_raise ArgumentError, ~r/requires at least one receipt/, fn ->
      ManufactureTrace.create(
        "person:demo",
        "artifact:devotional-candidate",
        "manufacturer:semantic-map",
        observed_refs: ["o:goal"],
        admitted_refs: ["o:goal"],
        grounded_refs: ["o:goal"],
        bounded_refs: ["o:goal"],
        aligned_refs: ["o:goal"],
        o_star_refs: ["o:goal"],
        standing: :ALIVE
      )
    end
  end

  test "receipted A=mu(O*) trace exposes provenance without gaining authority" do
    trace =
      ManufactureTrace.create(
        "person:demo",
        "artifact:devotional-candidate",
        "manufacturer:semantic-map",
        observed_refs: ["o:goal"],
        admitted_refs: ["o:goal"],
        grounded_refs: ["o:goal"],
        bounded_refs: ["o:goal"],
        aligned_refs: ["o:goal"],
        o_star_refs: ["o:goal"],
        receipt_refs: ["receipt:manufacture:001"],
        falsifiers: ["goal admission is withdrawn"],
        human_summary: "Built from the admitted goal and devotional semantics.",
        standing: :ALIVE
      )

    map = ManufactureTrace.to_map(trace)

    assert map["equation"] == "A=mu(O*)"
    assert map["oStarRefs"] == ["o:goal"]
    assert map["receiptRefs"] == ["receipt:manufacture:001"]
    assert map["standing"] == "ALIVE"
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["doAuthority"] == false
  end
end
