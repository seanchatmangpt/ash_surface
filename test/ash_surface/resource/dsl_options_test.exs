defmodule AshSurface.Resource.DslOptionsTest.Doc do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
    attribute(:slug, :string, public?: true)
    attribute(:secret, :string, public?: false)
  end

  identities do
    identity(:by_slug, [:slug])
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Resource.DslOptionsTest do
  use ExUnit.Case, async: true

  alias AshSurface.Dsl.Projection
  alias AshSurface.Resource.{Projections, Validator}

  @doc_resource AshSurface.Resource.DslOptionsTest.Doc

  defp codes(projection) do
    case Validator.validate(%{resource: @doc_resource, surface: [projection]}) do
      :ok -> []
      {:error, refusals} -> Enum.map(refusals, & &1.code)
    end
  end

  test "all 16 projection options are fields of the generated DSL struct" do
    keys = Map.keys(struct(Projection, action: :read))

    for k <-
          ~w(name namespace description deprecated see read_action get? get_by not_found_error? identities enable_filter? enable_sort? allowed_loads denied_loads show_metadata metadata_field_names)a do
      assert k in keys
    end
  end

  test "defaults match Resource.Projections" do
    p = struct(Projection, action: :read)
    assert p.get? == false and Projections.option(p, :get?) == false
    assert p.not_found_error? == true and Projections.option(p, :not_found_error?) == true
    assert p.enable_filter? == true and p.enable_sort? == true
    assert Projections.option(p, :get_by) == []
    assert Projections.option(p, :identities) == []
    assert codes(p) == []
  end

  test "get? with get_by is refused" do
    assert "get_and_get_by_conflict" in codes(%{action: :read, get?: true, get_by: [:slug]})
  end

  test "unknown identity is refused, known identity admitted" do
    assert "unknown_identity_projection" in codes(%{action: :read, identities: [:nope]})
    assert [] == codes(%{action: :read, identities: [:by_slug]})
  end

  test "allowed_loads together with denied_loads is refused" do
    assert "allowed_and_denied_loads_conflict" in codes(%{
             action: :read,
             allowed_loads: [:a],
             denied_loads: [:b]
           })
  end

  test "get_by naming a non-public or missing attribute is refused" do
    assert "get_by_not_public_attribute" in codes(%{action: :read, get_by: [:secret]})
    assert "get_by_not_public_attribute" in codes(%{action: :read, get_by: [:missing]})
    assert [] == codes(%{action: :read, get_by: [:slug]})
  end
end
