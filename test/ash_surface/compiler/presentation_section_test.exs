defmodule AshSurface.Compiler.PresentationSectionTest.Document do
  @moduledoc """
  Real inline Ash resource for presentation-section tests.

  Simple data layer (no Repo). `:publish_draft` exercises the humanize default
  on a multi-word action name.
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
    update(:publish_draft)
  end
end

defmodule AshSurface.Compiler.PresentationSectionTest do
  @moduledoc """
  First tests for `AshSurface.Compiler.Presentation`, the presentation section
  reader — the ONLY metadata ash_surface owns (ash_admin-style overrides).

  Law: with no presentation metadata the IR falls out of the action's own
  identity (label = humanized action name, group/format nil, order 0, widget
  "default"); explicit `custom.ash_surface` presentation overrides win; the
  widget vocabulary is admitted — an unknown or wrong-kind widget is a typed
  rejection; the reader touches zero business semantics (action identity +
  custom map only, no resource/domain/policy reads).
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.IR
  alias AshSurface.Compiler.Presentation

  @document AshSurface.Compiler.PresentationSectionTest.Document

  test "defaults: no presentation metadata yields humanized label and canonical defaults" do
    real = Ash.Resource.Info.action(@document, :publish_draft)

    assert {:ok, %IR.Presentation{} = presented} = Presentation.build(real, %{})

    assert presented == %IR.Presentation{
             label: "Publish draft",
             group: nil,
             order: 0,
             widget: "default",
             format: nil
           }
  end

  test "defaults hold when custom.ash_surface carries only id and profile" do
    custom = %{ash_surface: %{"id" => "x#read", "profile" => %{"consumer" => "web"}}}

    assert {:ok, presented} = Presentation.build(:read, custom)

    assert presented == %IR.Presentation{label: "Read"}
  end

  test "explicit presentation overrides win over defaults" do
    custom = %{
      ash_surface: %{
        "id" => "x#publish_draft",
        "profile" => %{},
        "presentation" => %{
          "label" => "Publish now",
          "group" => "editorial",
          "order" => 7,
          "widget" => "toggle",
          "format" => "short"
        }
      }
    }

    assert {:ok, presented} = Presentation.build(:publish_draft, custom)

    assert presented == %IR.Presentation{
             label: "Publish now",
             group: "editorial",
             order: 7,
             widget: "toggle",
             format: "short"
           }
  end

  test "envelope survives a JSON round-trip via the string ash_surface key" do
    custom = %{
      "ash_surface" => %{"presentation" => %{"label" => "New doc", "widget" => "textarea"}}
    }

    assert {:ok, presented} = Presentation.build(:create, custom)

    assert presented.label == "New doc"
    assert presented.widget == "textarea"
    # Unspecified keys keep their canonical defaults.
    assert presented.group == nil
    assert presented.order == 0
    assert presented.format == nil
  end

  test "unknown widget is a typed rejection naming the admitted vocabulary" do
    assert {:error, refusals} =
             Presentation.build(:read, %{
               ash_surface: %{"presentation" => %{"widget" => "hologram"}}
             })

    assert [%{code: "unknown_widget_presentation", detail: detail}] = refusals
    assert detail =~ "hologram"
    assert detail =~ "default"
  end

  test "wrong-kind widget is the same typed rejection" do
    assert {:error, [%{code: "unknown_widget_presentation", detail: detail}]} =
             Presentation.build(:read, %{ash_surface: %{"presentation" => %{"widget" => :toggle}}})

    assert detail =~ ":toggle"
  end

  test "zero business semantics touched: identity plus custom map only" do
    real = Ash.Resource.Info.action(@document, :publish_draft)

    assert {:ok, from_real} = Presentation.build(real, %{})
    assert {:ok, from_name} = Presentation.build(%{name: :publish_draft}, %{})
    assert {:ok, from_atom} = Presentation.build(:publish_draft, %{})

    assert from_real == from_name
    assert from_name == from_atom

    # Other extensions' custom keys are invisible to the presentation reader.
    assert {:ok, untouched} =
             Presentation.build(:read, %{other_extension: %{business: :semantics}})

    assert untouched == %IR.Presentation{label: "Read"}
  end

  test "malformed metadata is refused fail-closed" do
    assert {:error, [%{code: "invalid_presentation_compilation"}]} =
             Presentation.build(:read, :not_a_map)

    assert {:error, [%{code: "invalid_presentation_compilation"}]} =
             Presentation.build(%{title: "no name"}, %{})

    assert {:error, [%{code: "invalid_presentation_compilation"}]} =
             Presentation.build(:read, %{ash_surface: %{"presentation" => :not_a_map}})
  end
end
