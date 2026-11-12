defmodule AshSurface.Ported.Manifest.RelationshipQueryCapabilitiesSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/relationship_query_capabilities_test`.

  Facts come from `AshSurface.Compiler.ResourceFacts.build/2` (relationship facts) and
  `ResourceFacts.relationship_read_action/1` over the real ported Todo fixture.

  Per-test note: "many-relationships to non-RPC destinations are not stamped" has no
  ash_surface counterpart, see `manifest_relationship_query_capabilities_gap_test.exs`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ResourceFacts

  @todo AshSurface.Ported.Todo

  defp rel(name), do: Ash.Resource.Info.relationship(@todo, name)

  defp fact(name) do
    facts = AshSurface.Ported.AshNames.facts(@todo, Ash.Resource.Info.action(@todo, :read))
    Enum.find(facts.relationships, &(&1["name"] == to_string(name)))
  end

  test "many-relationship is stamped with pagination and read_action" do
    assert fact(:comments)["pagination"] == "mixed"
    assert ResourceFacts.relationship_read_action(rel(:comments)) == :read
  end

  test "relationship read_action override drives the pagination derivation" do
    assert fact(:unpaginated_comments)["pagination"] == "none"
    assert ResourceFacts.relationship_read_action(rel(:unpaginated_comments)) == :read_unpaginated
  end

  test "filterable?/sortable? flags are carried on the relationship facts" do
    refute fact(:unfilterable_comments)["filterable"]
    refute fact(:unsortable_comments)["sortable"]
    assert fact(:comments)["filterable"]
    assert fact(:comments)["sortable"]
  end

  test "pure offset/keyset pagination variants are decorated" do
    assert fact(:offset_comments)["pagination"] == "offset"
    assert ResourceFacts.relationship_read_action(rel(:offset_comments)) == :read_offset_only
    assert fact(:keyset_comments)["pagination"] == "keyset"
    assert ResourceFacts.relationship_read_action(rel(:keyset_comments)) == :read_keyset_only
  end

  test "many_to_many relationships are stamped like has_many" do
    assert fact(:commenters)["cardinality"] == "many"
    assert fact(:commenters)["pagination"] == "mixed"
    assert ResourceFacts.relationship_read_action(rel(:commenters)) == :read
  end

  test "to-one relationships are not stamped" do
    assert fact(:user)["cardinality"] == "one"
    assert fact(:user)["pagination"] == "none"
    assert ResourceFacts.relationship_read_action(rel(:user)) == nil
  end
end
