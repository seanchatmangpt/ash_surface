defmodule AshSurface.Transformers.ManifestTransformersTest do
  @moduledoc """
  Courts for ash_typescript `BuildManifest` / `DecorateManifest`: a real manifest is
  generated from a real compiled resource, decorated, and the decorated manifest equals
  the generated one plus exactly the `custom.ash_surface` entries.
  """
  use ExUnit.Case, async: false

  defmodule Doc do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:title, :string, public?: true)
    end

    actions do
      read(:read)
    end

    surface do
      type_name("DocType")
      namespace("docs")

      projection :read do
        show_metadata(false)
      end

      typed_query :doc_list, :read do
        fields([:id, :title])
      end
    end
  end

  defp generated do
    {:ok, m} =
      Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: [{Doc, :read}])

    m
  end

  test "decorated manifest equals the generated manifest plus only ash_surface custom data" do
    base = generated()
    {:ok, surface} = AshSurface.from_manifest(base)
    decorated = surface.manifest

    assert decorated.resources == base.resources
    assert decorated.types == base.types
    assert length(decorated.entrypoints) == length(base.entrypoints)

    strip = fn m ->
      %{
        m
        | custom: Map.delete(m.custom, :ash_surface),
          entrypoints:
            Enum.map(m.entrypoints, fn ep ->
              %{
                ep
                | action: %{ep.action | custom: Map.delete(ep.action.custom, :ash_surface)}
              }
            end)
      }
    end

    assert strip.(decorated) == strip.(base)
    refute Map.has_key?(base.custom, :ash_surface)
  end

  test "decorated content carries id, profile, metadata options, dsl and typed queries" do
    {:ok, surface} = AshSurface.from_manifest(generated(), profile: %{"tier" => "gold"})
    [ep] = surface.manifest.entrypoints
    custom = ep.action.custom.ash_surface

    assert custom["id"] == AshSurface.action_id(ep)
    assert custom["profile"] == %{}
    assert custom["show_metadata"] == false

    root = surface.manifest.custom.ash_surface
    assert root["profile"] == %{"tier" => "gold"}
    assert %{"type_name" => "DocType", "namespace" => "docs"} = root["dsl"][inspect(Doc)]

    assert [%{"name" => "doc_list", "action" => "read"}] =
             root["dsl"][inspect(Doc)]["typed_queries"]
  end
end
