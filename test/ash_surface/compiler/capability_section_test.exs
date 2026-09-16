defmodule AshSurface.Compiler.CapabilitySectionTest do
  @moduledoc """
  Chicago tests for the capability-section builder's delegation to ash_a2a.

  The subject is a real inline Ash resource that registers the `AshA2A`
  extension and declares real `a2a skill` overrides, plus a real unregistered
  resource. No mocks: every expectation is stated either against
  `AshA2A.Info` itself (proving pure projection) or against ash_a2a's
  published consequence law (proving the builder invents nothing).
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler
  alias AshSurface.Compiler.IR.Capability

  defmodule DeckDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.Compiler.CapabilitySectionTest.Stockpile)
      resource(AshSurface.Compiler.CapabilitySectionTest.UnregisteredLedger)
    end
  end

  defmodule Stockpile do
    @moduledoc """
    Registered subject: real Ets resource with the AshA2A extension.

    Covers every delegated truth the section must project: derived defaults
    (`:read` -> `:observe`, `:create`/`:update`/`:destroy` -> `:change`), an
    explicit `:external_do` override on a generic action, an unclassified
    generic action (ash_a2a's fail-closed `:unknown`), and an `expose?: false`
    override that removes a public action from the derived index.
    """

    use Ash.Resource,
      domain: DeckDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshA2A]

    attributes do
      uuid_primary_key(:id)
      attribute(:sku, :string, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read, :create, :update, :destroy])

      action :courier_notify, :string do
        description("Hands a restock notice to the outside courier API.")

        argument(:sku, :string, allow_nil?: false)

        run(fn input, _ctx ->
          {:ok, "courier notified for #{input.arguments.sku}"}
        end)
      end

      action :recount_projection, :integer do
        description("Pure arithmetic over persisted rows; author left it unclassified.")

        run(fn _input, _ctx -> {:ok, 0} end)
      end

      action :audit_peek, :string do
        run(fn _input, _ctx -> {:ok, "peeked"} end)
      end
    end

    a2a do
      skill :restock_courier, :courier_notify do
        consequence(:external_do)
      end

      skill :hidden_audit, :audit_peek do
        expose?(false)
      end
    end
  end

  defmodule UnregisteredLedger do
    @moduledoc "Plain Ash resource: public actions, but no AshA2A extension."

    use Ash.Resource,
      domain: DeckDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:entry, :string, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read, :create])
    end
  end

  describe "build/1 on the registered resource" do
    test "is a pure projection of AshA2A.Info's derived index" do
      derived = AshA2A.Info.capability_index(Stockpile)

      section = Compiler.Capability.build(Stockpile)

      assert is_list(section)
      # Same entries, same derived order -- the section adds no capability
      # and reorders nothing.
      assert Enum.map(section, & &1.capability_id) == Enum.map(derived, & &1.id)
    end

    test "every capability_id is ash_a2a's derived id, never a surface invention" do
      ids = Stockpile |> Compiler.Capability.build() |> MapSet.new(& &1.capability_id)

      assert (inspect(Stockpile) <> ".read") in ids
      assert (inspect(Stockpile) <> ".create") in ids
      assert (inspect(Stockpile) <> ".update") in ids
      assert (inspect(Stockpile) <> ".destroy") in ids
      assert (inspect(Stockpile) <> ".courier_notify") in ids
      assert (inspect(Stockpile) <> ".recount_projection") in ids
    end

    test "an expose?: false override removes a public action from the section" do
      # :audit_peek is a public Ash action, but ash_a2a's derived index drops
      # it; the section must mirror the index, not public_actions directly.
      refute Enum.any?(
               Compiler.Capability.build(Stockpile),
               &String.ends_with?(&1.capability_id, ".audit_peek")
             )
    end

    test "consequence classes come from ash_a2a's law, not from this repo" do
      by_action = index_by_action(Stockpile)

      assert by_action["read"].consequence_class == :observe
      assert by_action["create"].consequence_class == :change
      assert by_action["update"].consequence_class == :change
      assert by_action["destroy"].consequence_class == :change
      assert by_action["courier_notify"].consequence_class == :external_do
      assert by_action["recount_projection"].consequence_class == :unknown
    end

    test "authority/receipt requirements follow the consequence semantics" do
      by_action = index_by_action(Stockpile)

      # :observe -- CommandBus admits with no authority, anchors no receipt.
      observe = by_action["read"]
      refute observe.authority_required
      refute observe.receipt_required

      # :change -- refused :authority_required on nil authority;
      # RECEIPT_ANCHORED mandatory before DO.
      for action <- ["create", "update", "destroy"] do
        assert by_action[action].authority_required
        assert by_action[action].receipt_required
      end

      # :external_do -- same consequence-bearing admission law.
      external = by_action["courier_notify"]
      assert external.authority_required
      assert external.receipt_required
    end

    test "an unclassified generic action keeps the fail-closed fence, no fabricated booleans" do
      unknown = index_by_action(Stockpile)["recount_projection"]

      assert unknown.consequence_class == :unknown
      # CommandBus refuses :unknown as :consequence_unclassified before any
      # authority question; the section must not invent an answer either.
      assert is_nil(unknown.authority_required)
      assert is_nil(unknown.receipt_required)
    end

    test "IR entries are the canonical Capability shape" do
      assert [%Capability{} | _] = Compiler.Capability.build(Stockpile)
    end
  end

  describe "build/1 on an unregistered resource" do
    test "returns nil -- no fabricated capability truth" do
      assert AshA2A.Info.capability_index(UnregisteredLedger) == nil
      assert Compiler.Capability.build(UnregisteredLedger) == nil
    end
  end

  describe "the Section behaviour" do
    test "the canonical behaviour is build/2; Capability is a build/1 subject projection that does not yet claim it" do
      # v26.9.16 integration law: the canonical AshSurface.Compiler.Section
      # behaviour (build/2, per-action, owned by compiler.ex) landed with the
      # compiler orchestrator. Capability's build/1 subject projection predates
      # it and does not fake conformance; conforming it is owned by the
      # capability-section successor branch.
      assert AshSurface.Compiler.Section.behaviour_info(:callbacks) == [build: 2]

      assert is_nil(Compiler.Capability.module_info()[:attributes][:behaviour])
      assert function_exported?(Compiler.Capability, :build, 1)
      refute function_exported?(Compiler.Capability, :build, 2)
    end
  end

  defp index_by_action(resource) do
    resource
    |> Compiler.Capability.build()
    |> Map.new(fn entry ->
      # Action atoms contain no dot; the derived id is "#{inspect(resource)}.#{action}".
      action = entry.capability_id |> String.split(".") |> List.last()
      {action, entry}
    end)
  end
end
