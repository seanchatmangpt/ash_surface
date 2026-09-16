defmodule AshSurface.Compiler.SemanticSectionTest do
  @moduledoc """
  Chicago-school, table-driven state tests of the semantic section builder
  (`AshSurface.Compiler.Semantic.build/2`).

  Law under test — the delegation law:

    1. **Delegation.** For a resource mapped through AshR2RML's mapping
       surface, the section carries the mapping's own subject IRI contract,
       class IRI, predicate IRIs, SHACL NodeShape identity (as AshR2RML's
       SHACL renderer itself emits it), and named-graph provenance — byte for
       byte, in the mapping's own order. ash_surface re-derives nothing.
    2. **Nil preservation.** For a resource AshR2Rml does not map, every
       action yields `nil`. No IRIs, no predicates, no shape, no ontology are
       fabricated from Ash attribute names, action names, or any other
       local re-derivation.
    3. **Action invariance.** AshR2RML maps resources, not actions; every
       action of a mapped resource projects the identical section.

  The golden section below is FROZEN. Any drift in IRI, predicate ordering,
  shape identity, or provenance must break this build.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.IR
  alias AshSurface.Compiler.Semantic

  # ---------------------------------------------------------------------------
  # Fixtures: one minimal inline mapped resource, one unmapped resource.
  # ---------------------------------------------------------------------------

  defmodule MappedDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.Compiler.SemanticSectionTest.MappedProject)
      resource(AshSurface.Compiler.SemanticSectionTest.UnmappedTask)
    end
  end

  defmodule MappedProject do
    use Ash.Resource,
      domain: MappedDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshR2RML.Resource]

    r2rml do
      table_name("projects")

      class("https://vocab.example/Project")

      subject do
        template("https://data.example/projects/{id}")
      end

      property(:title, "https://vocab.example/title")
      property(:status, "https://vocab.example/status")

      graph("https://vocab.example/graph")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true, allow_nil?: false)
      attribute(:status, :string, public?: true)
    end

    actions do
      defaults([:read])

      create :register do
        accept([:title, :status])
      end
    end
  end

  defmodule UnmappedTask do
    use Ash.Resource,
      domain: MappedDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read])

      create :open do
        accept([:label])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Frozen golden section: mapped resource, byte-for-byte from the mapping.
  # ---------------------------------------------------------------------------

  @golden_section %IR.Semantic{
    subject_iri: "https://data.example/projects/{id}",
    capability_iri: "https://vocab.example/Project",
    predicates: ["https://vocab.example/status", "https://vocab.example/title"],
    shape_id: "https://data.example/projects/{id}Shape",
    ontology: ["https://vocab.example/graph"]
  }

  test "mapped resource yields the exact semantic section from the mapping" do
    assert Semantic.build(MappedProject, :register) == @golden_section
  end

  test "every action of a mapped resource projects the identical section (upstream maps resources, not actions)" do
    section = Semantic.build(MappedProject, :read)

    assert section == Semantic.build(MappedProject, :register)
    assert section == @golden_section
  end

  test "predicates are the mapping's own predicate IRIs, in the mapping's normalized order" do
    section = Semantic.build(MappedProject, :read)

    assert length(section.predicates) == 2

    assert section.predicates == [
             "https://vocab.example/status",
             "https://vocab.example/title"
           ]
  end

  test "shape identity is what AshR2RML's own SHACL renderer emits for the mapping" do
    {:ok, shacl} =
      AshR2RML.SHACL.render(%AshR2RML.Mapping.Bundle{
        resources: [AshR2RML.Resource.Info.mapping(MappedProject)]
      })

    assert Semantic.build(MappedProject, :read).shape_id ==
             "https://data.example/projects/{id}Shape"

    # The delegated shape identity is a NodeShape AshR2RML itself declares
    # targeting the mapped class — nothing re-derived locally.
    assert shacl =~
             "<https://data.example/projects/{id}Shape> a sh:NodeShape ;"
  end

  # ---------------------------------------------------------------------------
  # Nil preservation: no mapping, no section — for any action, ever.
  # ---------------------------------------------------------------------------

  @unmapped_actions [:read, :open, :destroy, :never_declared_upstream]

  test "unmapped resource preserves nil for every action — UNKNOWN is honest, never invented" do
    for action <- @unmapped_actions do
      section = Semantic.build(UnmappedTask, action)

      assert is_nil(section)

      # The guard against fabrication: no field of the absent section may be
      # reconstructed from Ash attribute names, action names, or module names.
      assert AshR2RML.Resource.Info.mapping(UnmappedTask) == nil
    end
  end

  test "non-Spark module preserves nil rather than raising" do
    assert Semantic.build(AshSurface, :read) == nil
  end

  # ---------------------------------------------------------------------------
  # Section behaviour conformance: integrated truth after the local behaviour
  # was superseded by the canonical compiler.ex declaration.
  # ---------------------------------------------------------------------------

  test "Semantic carries its documented build/2 subject contract" do
    behaviours =
      Semantic.module_info(:attributes)
      |> Keyword.get(:behaviour, [])

    # The branch-local Section behaviour was superseded by the canonical one
    # (build(action_map, context_map)); Semantic's build/2 is
    # (resource, action) -> IR.Semantic.t() | nil — a different subject
    # contract — so it honestly does not declare the behaviour. Conformance is
    # owed by the adapter that normalizes the subject mapping.
    assert AshSurface.Compiler.Section not in behaviours
    assert function_exported?(Semantic, :build, 2)
  end
end
