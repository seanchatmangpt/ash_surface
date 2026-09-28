defmodule AshSurface.CompilerCoverageTest do
  @moduledoc """
  Chicago state tests pinning the remaining laws of the compiler orchestrator,
  the ash TRUTH section, the ARIA contract reader, and the R2RML-delegated
  semantic builder.

  Laws pinned here:

    * **Raw-domain normalization.** DiscoverOnce over an `Ash.Domain` keeps
      only public arguments, marks optionality from `allow_nil?` and declared
      defaults, reads the type kind from Ash's own short-name registry (a type
      outside it is an honest `nil`), and carries declared metadata names as
      sorted outputs.
    * **Sections refusal.** A `:sections` option that is not a list is refused
      typed, never coerced.
    * **Ash truth refuses fabrication** at every nesting level, including the
      policy children, and names types outside the short-name registry by
      their inspected Ash type.
    * **ARIA reads, never guesses**: atom action ids, bare-string labels, and
      non-string labels are read literally; a malformed `inputs` carrier is
      refused.
    * **Semantic nil preservation** for a blank-node subject: no subject IRI
      is invented, while class and shape stay AshR2RML's delegated facts.

  Real inline Ash resources (ETS), real `AshR2RML.Resource` extension; no
  doubles except an inline pure section that returns its normalized entry.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler
  alias AshSurface.Compiler.{Aria, AshTruth}
  alias AshSurface.IR

  defmodule LedgerDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.CompilerCoverageTest.Ledger)
    end
  end

  defmodule Ledger do
    use Ash.Resource,
      domain: AshSurface.CompilerCoverageTest.LedgerDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:note, :string, public?: true)
    end

    actions do
      defaults([:read])

      create :record do
        accept([:note])

        argument(:note_text, :string, allow_nil?: false)
        argument(:tags, {:array, :string}, default: [])
        argument(:internal_hint, :string, public?: false)

        metadata(:receipt_token, :string)
        metadata(:audit_ref, :string)
      end
    end
  end

  defmodule BlankDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.CompilerCoverageTest.BlankSubject)
    end
  end

  defmodule BlankSubject do
    @moduledoc "Mapped by AshR2RML with a blank-node subject."

    use Ash.Resource,
      domain: AshSurface.CompilerCoverageTest.BlankDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshR2RML.Resource]

    r2rml do
      table_name("blank_subjects")

      class("https://vocab.example/Anonymous")

      subject do
        term_type(:blank_node)
      end

      property(:title, "https://vocab.example/title")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:title, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule EntrySection do
    @moduledoc "Pure section: its slice is the normalized entry it was handed."
    @behaviour AshSurface.Compiler.Section

    @impl true
    def build(action, _context), do: {:ok, action}
  end

  @entry_sections [
    ash: EntrySection,
    semantic: EntrySection,
    capability: EntrySection,
    presentation: EntrySection,
    schema: EntrySection
  ]

  describe "Compiler: raw Ash.Domain normalization" do
    setup do
      {:ok, irs} = Compiler.compile(LedgerDomain, sections: @entry_sections)
      {:ok, entries: Map.new(irs, &{&1.ash.id, &1.ash})}
    end

    test "only public arguments survive, name-sorted, with registry kinds and optionality",
         %{entries: entries} do
      record = Map.fetch!(entries, "AshSurface.CompilerCoverageTest.Ledger.record")

      assert record.inputs == [
               %{name: "note_text", type: "string", allow_nil: false, has_default: false},
               # {:array, :string} is outside Ash's short-name registry: UNKNOWN, not guessed.
               %{name: "tags", type: nil, allow_nil: true, has_default: true}
             ]

      refute Enum.any?(record.inputs, &(&1.name == "internal_hint"))
    end

    test "declared metadata names become the sorted outputs", %{entries: entries} do
      record = Map.fetch!(entries, "AshSurface.CompilerCoverageTest.Ledger.record")
      read = Map.fetch!(entries, "AshSurface.CompilerCoverageTest.Ledger.read")

      assert record.outputs == ["audit_ref", "receipt_token"]
      assert read.outputs == []
      assert read.inputs == []
    end

    test "the default pipeline mounts the normalized arguments into the schema boundary" do
      assert {:ok, irs} = Compiler.compile(LedgerDomain)

      record = Enum.find(irs, &(&1.ash.action == :record))
      assert record.schema.input |> Map.keys() |> Enum.sort() == ["note_text", "tags"]
    end
  end

  describe "compiled IR through the ARIA projector" do
    test "the schema section's list-form aria \"fields\" become the surface inputs (internal_hint stays private; tags allows nil)" do
      assert {:ok, irs} = Compiler.compile(LedgerDomain)
      assert {:ok, contract, _meta} = AshSurface.Projectors.ARIA.project_ir(irs)

      record =
        Enum.find(contract["surfaces"], &String.ends_with?(&1["id"], "Ledger.record"))

      assert Enum.map(record["inputs"], &{&1["name"], &1["required"]}) == [
               {"note_text", true},
               {"tags", false}
             ]
    end
  end

  describe "Compiler: :sections refusal" do
    test "a non-list :sections option is refused typed" do
      assert Compiler.compile(%Ash.Info.Manifest{entrypoints: []}, sections: :bogus) ==
               {:error, {:sections_must_bind_keys_to_modules, :bogus}}

      assert Compiler.compile(LedgerDomain, sections: %{ash: EntrySection}) ==
               {:error, {:sections_must_bind_keys_to_modules, %{ash: EntrySection}}}
    end

    test "a list that is not a keyword list is refused typed, never an ArgumentError" do
      assert Compiler.compile(%Ash.Info.Manifest{entrypoints: []}, sections: [:ash]) ==
               {:error, {:sections_must_bind_keys_to_modules, [:ash]}}

      assert Compiler.compile(LedgerDomain, sections: [{"ash", EntrySection}]) ==
               {:error, {:sections_must_bind_keys_to_modules, [{"ash", EntrySection}]}}
    end
  end

  describe "AshTruth" do
    test "section/1 renders with default opts, identical to section/2" do
      {:ok, node} = AshTruth.build(Ledger, :read)

      assert {:ok, section} = AshTruth.section(node)
      assert {:ok, ^section} = AshTruth.section(node, [])
      assert section.section == "ash"
      assert section.resource == inspect(Ledger)
    end

    test "a type outside the short-name registry is named by its inspected Ash type" do
      {:ok, node} = AshTruth.build(Ledger, :record)

      types = Map.new(node.inputs, &{&1.name, &1.type})

      assert types[:note_text] == "string"
      assert types[:tags] == inspect({:array, Ash.Type.String})
    end

    test "a fabricated key inside a policy condition is refused" do
      node = policy_node(conditions: [%{check: "C", opts: %{}, guess: :fabricated}], checks: [])

      assert AshTruth.section(node) ==
               {:error, {:fabricated_fact, :condition, [:check, :guess, :opts]}}
    end

    test "a fabricated key inside a policy check is refused" do
      node = policy_node(conditions: [], checks: [%{check: "C", kind: :filter, widget: "x"}])

      assert AshTruth.section(node) ==
               {:error, {:fabricated_fact, :check, [:check, :kind, :widget]}}
    end

    test "admitted policy children render" do
      node =
        policy_node(
          conditions: [%{check: "Always", opts: %{}}],
          checks: [%{check: "Actor", kind: :authorize_if}]
        )

      assert {:ok, %{policies: [policy]}} = AshTruth.section(node)
      assert policy.conditions == [%{check: "Always", opts: %{}}]
    end
  end

  describe "Aria" do
    defp aria_schema(action_id) do
      %Compiler.IR.Schema{
        action_id: action_id,
        inputs: [
          %Compiler.IR.Input{
            name: :note,
            type: :string,
            allow_nil?: false,
            description: "What was granted"
          },
          %Compiler.IR.Input{name: :done, type: :boolean, allow_nil?: true}
        ]
      }
    end

    test "mount/1 mounts the presentation-free contract at schema.aria" do
      schema = aria_schema("Wish.grant")

      assert {:ok, mounted} = Aria.mount(schema)
      assert {:ok, aria} = Aria.build(schema)
      assert mounted.aria == aria
      assert mounted.aria["note"]["label"] == nil
      assert mounted.aria["note"]["required"] == true
    end

    test "an atom action id is admitted and read as its string" do
      assert {:ok, aria} = Aria.build(aria_schema(:"Wish.grant"))
      assert aria["note"]["describedby"] == Aria.describedby_id("Wish.grant", :note)
      assert aria["note"]["describedby"] == "Wish-grant-note-description"
    end

    test "role_for_type/1 maps a non-atom, non-Type value to nil" do
      assert Aria.role_for_type("string") == nil
      assert Aria.role_for_type(42) == nil
    end

    test "an inputs carrier that is not a map is refused, not guessed from" do
      presentation = %{inputs: ["note"]}

      assert Aria.build(aria_schema("Wish.grant"), presentation) ==
               {:error, {:invalid_presentation, presentation}}
    end

    test "labels are read literally: bare string yes, non-string no" do
      presentation = %{"note" => "Grant note", "done" => %{label: 42}}

      assert {:ok, aria} = Aria.build(aria_schema("Wish.grant"), presentation)
      assert aria["note"]["label"] == "Grant note"
      assert aria["done"]["label"] == nil
    end
  end

  describe "Semantic nil preservation for a blank-node subject" do
    test "a blank-node subject carries no IRI; class and shape stay delegated facts" do
      mapping = AshR2RML.Resource.Info.mapping(BlankSubject)
      assert mapping.subject_map.term_type == :blank_node

      {:ok, shacl} =
        AshR2RML.SHACL.render(%AshR2RML.Mapping.Bundle{resources: [mapping]})

      section = Compiler.Semantic.build(BlankSubject, :read)

      assert section == %Compiler.IR.Semantic{
               subject_iri: nil,
               capability_iri: "https://vocab.example/Anonymous",
               predicates: ["https://vocab.example/title"],
               shape_id: "bnode_{id}Shape",
               ontology: []
             }

      # The shape identity is the NodeShape AshR2RML's own renderer declares.
      assert shacl =~ "<#{section.shape_id}> a sh:NodeShape ;"
    end
  end

  defp policy_node(children) do
    %IR.Ash{
      resource: Ledger,
      action: :read,
      action_type: :read,
      inputs: [],
      outputs: nil,
      policies: [
        %IR.Policy{
          bypass: false,
          conditions: Keyword.fetch!(children, :conditions),
          checks: Keyword.fetch!(children, :checks)
        }
      ]
    }
  end
end
