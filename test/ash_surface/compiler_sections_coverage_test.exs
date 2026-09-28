defmodule AshSurface.CompilerSectionsCoverageTest do
  @moduledoc """
  Chicago state tests for the default `AshSurface.Compiler.Section.*`
  adapters' carry and refusal laws.

  Laws pinned here:

    * **Verbatim carry.** For a real `AshA2A`-registered resource and a real
      `AshR2RML`-mapped resource, the capability and semantic adapters mount
      exactly the fields the edge-owner builders project — which are, in
      turn, the owners' own facts (`AshA2A.Info`, the R2RML mapping).
    * **Typed refusal.** Every adapter refuses a non-map action entry with
      `{:invalid_action_entry, entry}`; the capability, presentation and
      schema adapters propagate their builder's typed rejections unchanged.
    * **Schema carry of UNKNOWN kinds.** An input with no discovered kind
      reaches the boundary with no invented type.

  Delegation subjects are real inline Ash resources registering the real
  extensions (TESTING.md section 3); no fakes of either extension.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler
  alias AshSurface.Compiler.Section

  defmodule DeckDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.CompilerSectionsCoverageTest.Crate)
      resource(AshSurface.CompilerSectionsCoverageTest.Shelf)
    end
  end

  defmodule Crate do
    @moduledoc "Registered subject: real Ets resource with the AshA2A extension."

    use Ash.Resource,
      domain: AshSurface.CompilerSectionsCoverageTest.DeckDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshA2A]

    attributes do
      uuid_primary_key(:id)
      attribute(:sku, :string, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read, create: [:sku]])
    end
  end

  defmodule Shelf do
    @moduledoc "Mapped subject: real Ets resource with the AshR2RML extension."

    use Ash.Resource,
      domain: AshSurface.CompilerSectionsCoverageTest.DeckDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshR2RML.Resource]

    r2rml do
      table_name("shelves")
      class("https://vocab.example/Shelf")

      subject do
        template("https://data.example/shelves/{id}")
      end

      property(:label, "https://vocab.example/label")
      graph("https://vocab.example/graph")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defp entry(resource, action, extra \\ %{}) do
    Map.merge(
      %{
        id: "#{inspect(resource)}.#{action}",
        resource: resource,
        resource_name: inspect(resource),
        action: action,
        action_type: Ash.Resource.Info.action(resource, action).type,
        custom: %{},
        inputs: [],
        outputs: []
      },
      extra
    )
  end

  @context %{discovery: %{token: 1, kind: :domain, actions: 1}, action_id: "x", source: nil}

  @adapters [
    Section.Ash,
    Section.Capability,
    Section.Presentation,
    Section.Schema,
    Section.Semantic
  ]

  describe "every adapter" do
    test "refuses a non-map action entry typed, never coerced" do
      for adapter <- @adapters, entry <- [:not_a_map, "Crate.read", nil] do
        assert adapter.build(entry, @context) == {:error, {:invalid_action_entry, entry}}
      end
    end
  end

  describe "Section.Capability over a real AshA2A resource" do
    test "mounts the builder's projection verbatim as the canonical IR.Capability" do
      for action <- [:read, :create] do
        action_entry = entry(Crate, action)

        assert {:ok, %Compiler.IR.Capability{} = builder} =
                 Compiler.Capability.build(action_entry, @context)

        assert {:ok, %AshSurface.IR.Capability{} = mounted} =
                 Section.Capability.build(action_entry, @context)

        assert Map.from_struct(mounted) == Map.from_struct(builder)

        # ...and the builder's id is ash_a2a's own derived id.
        [skill] =
          Enum.filter(AshA2A.Info.capability_index(Crate), &(&1.id == builder.capability_id))

        assert mounted.consequence_class == skill.consequence
      end
    end

    test "consequence classes are ash_a2a's derived defaults" do
      assert {:ok, %{consequence_class: :observe, authority_required: false}} =
               Section.Capability.build(entry(Crate, :read), @context)

      assert {:ok, %{consequence_class: :change, receipt_required: true}} =
               Section.Capability.build(entry(Crate, :create), @context)
    end

    test "propagates the builder's typed refusal for a malformed entry" do
      malformed = %{resource: "not_a_module", action: :read}

      assert Section.Capability.build(malformed, @context) ==
               Compiler.Capability.build(malformed, @context)

      assert Section.Capability.build(malformed, @context) ==
               {:error, {:invalid_action_entry, malformed}}
    end
  end

  describe "Section.Semantic over a real AshR2RML resource" do
    test "mounts the builder's section verbatim as the canonical IR.Semantic" do
      builder = Compiler.Semantic.build(Shelf, :read)

      assert {:ok, %AshSurface.IR.Semantic{} = mounted} =
               Section.Semantic.build(entry(Shelf, :read), @context)

      assert Map.from_struct(mounted) == Map.from_struct(builder)

      mapping = AshR2RML.Resource.Info.mapping(Shelf)
      assert mounted.capability_iri == hd(mapping.class_iris)
      assert mounted.subject_iri == mapping.subject_map.value
      assert mounted.predicates == ["https://vocab.example/label"]
      assert mounted.ontology == ["https://vocab.example/graph"]
    end
  end

  describe "Section.Presentation" do
    test "propagates the reader's unadmitted-widget rejection unchanged" do
      custom = %{ash_surface: %{"presentation" => %{"widget" => "hologram"}}}
      action_entry = entry(Crate, :read, %{custom: custom})

      assert {:error, [%{code: "unknown_widget_presentation"}]} =
               Section.Presentation.build(action_entry, @context)

      assert Section.Presentation.build(action_entry, @context) ==
               Compiler.Presentation.build(:read, custom)
    end

    test "a non-map custom.ash_surface envelope is refused by the reader" do
      assert Compiler.Presentation.build(:read, %{ash_surface: "presentation"}) ==
               {:error,
                [
                  %{
                    code: "invalid_presentation_compilation",
                    detail: "custom.ash_surface must be a map"
                  }
                ]}

      assert Section.Presentation.build(
               entry(Crate, :read, %{custom: %{"ash_surface" => [:not, :a, :map]}}),
               @context
             ) ==
               {:error,
                [
                  %{
                    code: "invalid_presentation_compilation",
                    detail: "custom.ash_surface must be a map"
                  }
                ]}
    end
  end

  describe "Section.Schema" do
    test "an entry without a binary id is refused" do
      action_entry = entry(Crate, :read, %{id: :"Crate.read"})

      assert Section.Schema.build(action_entry, @context) ==
               {:error, {:invalid_action_entry, action_entry}}
    end

    test "an input that is not a named map is refused" do
      for bad_inputs <- [["sku"], [%{name: :sku}]] do
        action_entry = entry(Crate, :create, %{inputs: bad_inputs})

        assert Section.Schema.build(action_entry, @context) ==
                 {:error, {:invalid_action_entry, action_entry}}
      end
    end

    test "an input with no discovered kind carries no invented type" do
      inputs = [
        %{name: "sku", type: "string", allow_nil: false, has_default: false},
        %{name: "blob", type: nil, allow_nil: true, has_default: false}
      ]

      assert {:ok, %AshSurface.IR.Schema{} = schema} =
               Section.Schema.build(entry(Crate, :create, %{inputs: inputs}), @context)

      assert Map.keys(schema.input) |> Enum.sort() == ["blob", "sku"]
      refute Map.has_key?(schema.input["blob"], "type")
      assert schema.input["sku"]["type"] == %{"kind" => "string"}
      assert schema.zod =~ "z.unknown()"
    end
  end
end
