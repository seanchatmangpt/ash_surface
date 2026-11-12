defmodule AshSurface.RuntimeParity.ManifestDslTest do
  use ExUnit.Case, async: false

  alias AshSurface.Manifest.Dsl

  defmodule Doc do
    @moduledoc false
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:field_1, :string, public?: true)
      attribute(:title, :string, public?: true)
    end

    actions do
      read :read do
        argument(:arg_1, :string)
      end
    end

    surface do
      type_name("DocType")
      namespace("docs")
      field_names(field_1: "field1")
      argument_names(read: [arg_1: "arg1"])
      show_raised_errors?(true)

      projection :read do
        show_metadata(false)
      end

      typed_query :doc_list, :read do
        description("Docs")
        result_type_name("DocListResult")
        fields_const_name("docListFields")
        fields([:id, :title])
      end
    end
  end

  defmodule Plain do
    @moduledoc false
    use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key(:id, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defp manifest(entrypoints) do
    {:ok, m} = Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: entrypoints)
    m
  end

  test "DSL -> manifest -> JSON -> read-back is identical and digest-stable" do
    {:ok, surface} = AshSurface.from_manifest(manifest([{Doc, :read}]))

    expected = Dsl.serialize(Doc)
    assert expected["type_name"] == "DocType"
    assert expected["namespace"] == "docs"
    assert expected["field_names"] == %{"field_1" => "field1"}
    assert expected["argument_names"] == %{"read" => %{"arg_1" => "arg1"}}
    assert expected["show_raised_errors?"] == true

    assert [
             %{
               "name" => "doc_list",
               "fields" => ["id", "title"],
               "result_type_name" => "DocListResult"
             }
           ] =
             expected["typed_queries"]

    key = inspect(Doc)
    assert Dsl.read(surface.manifest) == %{key => expected}

    decoded = surface.contract |> Jason.encode!() |> Jason.decode!()
    assert Dsl.read(decoded) == %{key => expected}

    # action-level options travel in the action custom entry
    [ep] = surface.manifest.entrypoints
    assert ep.action.custom.ash_surface["show_metadata"] == false

    # re-ingesting the decorated manifest yields the identical compiled state
    {:ok, again} = AshSurface.from_manifest(surface.manifest)
    assert again.digest == surface.digest
    assert AshSurface.digest(again.contract) == AshSurface.digest(surface.contract)
  end

  test "digest covers the declarations and ignores stale custom data; undeclared resources add no dsl entry" do
    {:ok, with_dsl} = AshSurface.from_manifest(manifest([{Doc, :read}]))
    {:ok, plain} = AshSurface.from_manifest(manifest([{Plain, :read}]))
    assert Dsl.read(plain.manifest) == %{}
    refute Map.has_key?(plain.manifest.custom.ash_surface, "dsl")

    mutated =
      put_in(with_dsl.manifest.custom.ash_surface["dsl"][inspect(Doc)]["type_name"], "Other")

    {:ok, remade} = AshSurface.from_manifest(mutated.manifest)
    # from_manifest re-derives from the resource DSL, never trusting stale custom data
    assert remade.digest == with_dsl.digest
  end

  test "dropping the declarations from the DSL view changes the contract digest" do
    {:ok, with_dsl} = AshSurface.from_manifest(manifest([{Doc, :read}]))
    stripped = Map.delete(with_dsl.contract["surface"], "dsl")
    refute AshSurface.digest(stripped) == AshSurface.digest(with_dsl.contract["surface"])
  end
end
