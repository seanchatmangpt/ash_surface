defmodule AshSurface.Resource.ValidatorTest.Document do
  @moduledoc """
  Real inline Ash resource for admission-law tests.

  Simple data layer (no Repo). Exact public action set: `[:create, :publish, :read]`.
  `:archive` is declared but `public?: false`, so it is outside the public set.
  """

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read, create: [:title]])
    update(:publish)
    destroy(:archive, public?: false)
  end
end

defmodule AshSurface.Resource.ValidatorTest do
  @moduledoc """
  First-ever tests for `AshSurface.Resource.Validator`, the admission-law delegate
  (`aex:validateDelegateModule` in ontology.ttl).

  Admission law: projection metadata validates against the EXACT public action set
  of the resource. Admitted metadata passes; metadata naming a non-existent (or
  declared-but-not-public) action is refused; wrong transport/offline-class kinds
  are refused; validated projections store as `custom.ash_surface` on the real
  manifest.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Resource.Validator

  @document AshSurface.Resource.ValidatorTest.Document
  @document_id "AshSurface.Resource.ValidatorTest.Document"

  test "admitted projection metadata passes against the exact public action set" do
    assert :ok =
             Validator.validate(%{
               resource: @document,
               surface: [
                 %{action: :read, consumer: :web, transport: :http, offline: :cache_last},
                 %{
                   action: :create,
                   consumer: :mobile,
                   transport: :phoenix_channel,
                   offline: :queue_reconcile
                 },
                 %{action: :publish, transport: :auto, offline: :online_only}
               ]
             })

    # Optional metadata may be omitted entirely; the action alone must be admitted.
    assert :ok = Validator.validate(%{resource: @document, surface: [%{action: :read}]})
  end

  test "projection naming an action outside the exact public action set is refused" do
    assert {:error, refusals} =
             Validator.validate(%{
               resource: @document,
               surface: [%{action: :read}, %{action: :obliterate}]
             })

    assert [%{code: "unknown_action_projection", detail: detail}] = refusals
    assert detail =~ "obliterate"
  end

  test "declared but non-public action is outside the exact public action set" do
    assert {:error, refusals} =
             Validator.validate(%{resource: @document, surface: [%{action: :archive}]})

    assert [%{code: "unknown_action_projection", detail: detail}] = refusals
    assert detail =~ "archive"
  end

  test "wrong transport kind is refused" do
    assert {:error, refusals} =
             Validator.validate(%{
               resource: @document,
               surface: [%{action: :read, transport: :carrier_pigeon}]
             })

    assert [%{code: "unknown_transport_projection", detail: detail}] = refusals
    assert detail =~ "carrier_pigeon"

    # Kinds are atoms; a string spelling of an admitted transport is still wrong kind.
    assert {:error, [%{code: "unknown_transport_projection"}]} =
             Validator.validate(%{
               resource: @document,
               surface: [%{action: :read, transport: "http"}]
             })
  end

  test "wrong offline-class kind is refused" do
    assert {:error, refusals} =
             Validator.validate(%{
               resource: @document,
               surface: [%{action: :read, offline: :sometimes}]
             })

    assert [%{code: "unknown_offline_class_projection", detail: detail}] = refusals
    assert detail =~ "sometimes"
  end

  test "duplicate action projections remain refused" do
    assert {:error, refusals} =
             Validator.validate(%{
               resource: @document,
               surface: [%{action: :read}, %{action: :read, transport: :http}]
             })

    assert [%{code: "duplicate_action_projection", detail: detail}] = refusals
    assert detail =~ ":read"
  end

  test "malformed compiled state is refused fail-closed" do
    assert {:error, [%{code: "invalid_surface_compilation"}]} = Validator.validate(%{})

    assert {:error, [%{code: "invalid_surface_compilation"}]} =
             Validator.validate(%{surface: :not_a_list})

    # Projections without a resource reference cannot be checked against an
    # exact public action set, so they are refused instead of trusted.
    assert {:error, [%{code: "invalid_surface_compilation"}]} =
             Validator.validate(%{surface: [%{action: :read}]})

    assert {:error, [%{code: "invalid_surface_compilation"}]} =
             Validator.validate(%{resource: @document, surface: [%{title: "no action"}]})
  end

  test "every refusal is reported, none silently pruned" do
    assert {:error, refusals} =
             Validator.validate(%{
               resource: @document,
               surface: [
                 %{action: :read, transport: :carrier_pigeon},
                 %{action: :obliterate, offline: :sometimes}
               ]
             })

    assert Enum.map(refusals, & &1.code) |> Enum.sort() == [
             "unknown_action_projection",
             "unknown_offline_class_projection",
             "unknown_transport_projection"
           ]
  end

  test "validated projections store as custom.ash_surface on the real manifest" do
    compiled = %{resource: @document, surface: [%{action: :read, consumer: :web}]}
    assert :ok = Validator.validate(compiled)

    assert {:ok, manifest} =
             Ash.Info.Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {@document, :read},
                 {@document, :create}
               ]
             )

    assert {:ok, surface} =
             AshSurface.from_manifest(manifest,
               profile: %{actions: %{"#{@document_id}#read" => %{consumer: "web"}}}
             )

    read =
      Enum.find(
        surface.manifest.entrypoints,
        &(&1.resource == @document and &1.action.name == :read)
      )

    create =
      Enum.find(
        surface.manifest.entrypoints,
        &(&1.resource == @document and &1.action.name == :create)
      )

    assert read.action.custom.ash_surface == %{
             "id" => "#{@document_id}#read",
             "profile" => %{"consumer" => "web"}
           }

    assert create.action.custom.ash_surface == %{
             "id" => "#{@document_id}#create",
             "profile" => %{}
           }

    assert surface.manifest.custom.ash_surface["schemaVersion"] == AshSurface.schema_version()
  end
end
