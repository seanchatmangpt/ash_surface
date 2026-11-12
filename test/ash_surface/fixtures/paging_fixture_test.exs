defmodule AshSurface.Fixtures.PagingFixtureTest do
  use ExUnit.Case, async: true
  alias AshSurface.ZodFixtures.Paging.Row

  defp pag(name), do: Ash.Resource.Info.action(Row, name).pagination

  test "pagination shapes" do
    assert %{offset?: true, keyset?: false, required?: false} = pag(:offset_only)
    assert %{offset?: false, keyset?: true} = pag(:keyset_only)
    assert %{offset?: true, keyset?: true, countable: true} = pag(:mixed)
    assert %{required?: true} = pag(:required_paged)
    assert %{offset?: true, required?: false} = pag(:optional_paged)
    assert pag(:list_all) == false or is_nil(pag(:list_all))
  end

  test "filterable / sortable variants" do
    assert %{filterable?: false, sortable?: false} = Ash.Resource.Info.attribute(Row, :secret)
    assert %{filterable?: true, sortable?: false} = Ash.Resource.Info.attribute(Row, :only_filter)
    assert %{filterable?: false, sortable?: true} = Ash.Resource.Info.attribute(Row, :only_sort)
  end
end
