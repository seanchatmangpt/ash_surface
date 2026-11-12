defmodule AshSurface.Ported.Rpc.A.EntrypointResolutionSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `entrypoint_resolution_test.exs`. The reference resolves
  `rpc_action`s through `AshTypescript.entrypoints/0`; ash_surface's counterpart is the RPC
  entry table installed by `AshSurface.Ported.Rpc` (a list of `Pipeline.entry/4` maps), which
  `Support.install/2` keys by name - so name uniqueness is asserted on the list before it is
  collapsed into the table.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  alias AshSurface.RuntimeParity.Rpc.Support

  test "an rpc read still runs end-to-end after discovery searches entrypoints" do
    params = %{"action" => "list_todos", "fields" => ["id", "title"]}

    assert {:ok, request} = Rpc.parse(params)
    assert request.resource == AshSurface.Ported.Todo
    assert request.action.name == :read

    result = Rpc.run(params, [RpcFixtures.todo(title: "Entry Todo")])
    assert %{"success" => true} = result
    assert [%{"id" => id, "title" => "Entry Todo"} = row] = result["data"]
    assert id == RpcFixtures.todo_id()
    assert Map.keys(row) |> Enum.sort() == ["id", "title"]
  end

  test "every rpc_action name resolves to exactly one decorated entrypoint" do
    entries = Rpc.entries()
    names = Enum.map(entries, & &1.name)
    assert length(entries) > 0
    assert length(names) == length(Enum.uniq(names))

    # resource-qualified names are unique too (the reference's {resource, name} pairs)
    pairs = Enum.map(entries, &{&1.resource, &1.name})
    assert length(pairs) == length(Enum.uniq(pairs))

    # the installed table holds one entry per name and resolves each to a real action
    Rpc.install()
    table = Support.entry_table()
    assert map_size(table) == length(names)

    for entry <- entries do
      assert table[to_string(entry.name)] == entry
      assert Ash.Resource.Info.action(entry.resource, entry.action) != nil
    end
  end
end
