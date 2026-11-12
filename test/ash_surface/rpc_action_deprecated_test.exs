defmodule AshSurface.RpcActionDeprecatedTest.Doc do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
  end

  actions do
    defaults([:read])

    for name <- [:read_plain, :read_true, :read_false, :read_msg, :read_evil] do
      read(name)
    end
  end

  surface do
    projection :read_plain
    projection :read_true, do: deprecated(true)
    projection :read_false, do: deprecated(false)
    projection :read_msg, do: deprecated("use readPlain")
    projection :read_evil, do: deprecated("bad */ end")
  end
end

defmodule AshSurface.RpcActionDeprecatedTest do
  @moduledoc """
  Court for `dsl.rpc.entity.rpc_action.option.deprecated`: the option is carried through
  `AshSurface.from_manifest/2` into the action custom entry and the contract envelope as a
  JSDoc `@deprecated` line. Real manifest, real DSL; no doubles.
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest

  @doc_resource AshSurface.RpcActionDeprecatedTest.Doc
  @actions [:read_plain, :read_true, :read_false, :read_msg, :read_evil]

  defp surface do
    {:ok, m} =
      Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: Enum.map(@actions, &{@doc_resource, &1})
      )

    {:ok, s} = AshSurface.from_manifest(m, profile: %{})
    s
  end

  defp custom(s, action) do
    ep = Enum.find(s.manifest.entrypoints, &(&1.action.name == action))
    ep.action.custom[:ash_surface]
  end

  test "deprecated true carries a bare JSDoc @deprecated" do
    c = custom(surface(), :read_true)
    assert c["deprecated"] == true
    assert c["jsdoc"] == "@deprecated"
  end

  test "deprecated message carries the message into the JSDoc line" do
    c = custom(surface(), :read_msg)
    assert c["deprecated"] == "use readPlain"
    assert c["jsdoc"] == "@deprecated use readPlain"
  end

  test "a comment terminator in the message cannot close the JSDoc block" do
    refute custom(surface(), :read_evil)["jsdoc"] =~ "*/"
  end

  test "unset and false add no deprecation keys" do
    s = surface()

    for a <- [:read_plain, :read_false] do
      refute Map.has_key?(custom(s, a), "deprecated")
      refute Map.has_key?(custom(s, a), "jsdoc")
    end
  end
end
