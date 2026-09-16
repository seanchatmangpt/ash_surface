# Semantic section of the ash_surface compiler.
#
# This file currently declares, locally, the canonical shapes that the
# compiler/ir.ex and compiler/section.ex owners will land later:
#
#   * `AshSurface.Compiler.Section` — the behaviour every compiler section
#     implements.
#   * `AshSurface.Compiler.IR` — the canonical IR shapes (`IR.Semantic` here).
#
# When those files land, these local declarations move there unchanged.



defmodule AshSurface.Compiler.Semantic do
  @moduledoc """
  Semantic section builder: pure delegation to AshR2RML's mapping surface.

  Laws under test (frozen):

    1. **Delegation, not derivation.** Subject IRIs, capability IRIs,
       predicates, SHACL shape identity, and ontology provenance are taken
       verbatim from AshR2RML's normalized mapping IR and its SHACL renderer.
       ash_surface never re-derives semantic meaning: the section is a
       projection of the mapping, and nothing else.
    2. **Nil preservation.** When AshR2RML yields no mapping for the resource
       — and therefore none for any of its actions — the section is `nil`.
       UNKNOWN semantics are honest, never invented.
    3. **Action scoping is upstream law.** AshR2RML maps resources, not
       actions ("Actions are not manufactured as RDF classes by default" —
       `AshR2RML.SemanticIR.Action`). Every action of a mapped resource
       therefore projects the same resource-scoped mapping, and per-action
       semantic variation waits on an AshR2RML surface that admits it. This
       module does not consult Ash action introspection to fake one.
  """


  alias AshR2RML.Mapping
  alias AshR2RML.Resource.Info, as: R2RMLInfo
  alias AshSurface.Compiler.IR

  # AshR2RML's SHACL renderer owns NodeShape identity. The pattern reads the
  # declared shape IRI back out of the renderer's own emission so that shape
  # identity is delegated fact, never re-derived locally.
  @node_shape ~r/<(?<shape>[^>]+)> a sh:NodeShape ;\n\s+sh:targetClass <(?<target>[^>]+)>/

  def build(resource, action) when is_atom(resource) and is_atom(action) do
    case R2RMLInfo.mapping(resource) do
      %Mapping.Resource{} = mapping -> project(mapping)
      nil -> nil
    end
  end

  defp project(%Mapping.Resource{} = mapping) do
    capability = capability_iri(mapping)

    %IR.Semantic{
      subject_iri: subject_iri(mapping),
      capability_iri: capability,
      predicates: predicates(mapping),
      shape_id: shape_id(mapping, capability),
      ontology: ontology(mapping)
    }
  end

  # Subject IRI contract exactly as mapped. A blank-node subject has no IRI;
  # that absence is preserved as nil, never papered over.
  defp subject_iri(%Mapping.Resource{subject_map: %{term_type: :iri, value: value}}), do: value
  defp subject_iri(%Mapping.Resource{subject_map: %{term_type: :blank_node}}), do: nil

  # The mapped class IRI is the capability the action operates on, taken in
  # the mapping's own normalized order.
  defp capability_iri(%Mapping.Resource{class_iris: [capability | _]}), do: capability
  defp capability_iri(%Mapping.Resource{class_iris: []}), do: nil

  # Every admitted predicate IRI — datatype properties then object
  # properties — verbatim and in the mapping's own normalized order.
  defp predicates(%Mapping.Resource{} = mapping) do
    Enum.map(mapping.predicate_object_maps, & &1.predicate_iri) ++
      Enum.map(mapping.reference_object_maps, & &1.predicate_iri)
  end

  # Ontology provenance: the named graphs the mapping admits.
  defp ontology(%Mapping.Resource{} = mapping) do
    Enum.map(mapping.graph_maps, & &1.value)
  end

  # SHACL shape identity delegated to AshR2RML's SHACL renderer: the section
  # carries whatever NodeShape IRI the renderer emits targeting the mapped
  # class. If the renderer emits none, the absence is preserved as nil.
  defp shape_id(%Mapping.Resource{} = mapping, capability) when is_binary(capability) do
    # The renderer is total over single-mapping bundles (`{:ok, ttl}`); a
    # non-match here fails loudly rather than silently fabricating absence.
    {:ok, shacl} = AshR2RML.SHACL.render(%Mapping.Bundle{resources: [mapping]})

    # Named groups in declaration order: [shape, target].
    @node_shape
    |> Regex.scan(shacl, capture: :all_names)
    |> Enum.find_value(fn [shape, target] ->
      if target == capability, do: shape
    end)
  end

  defp shape_id(_mapping, nil), do: nil
end
