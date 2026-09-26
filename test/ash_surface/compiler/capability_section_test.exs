defmodule AshSurface.Compiler.CapabilitySectionTest do
  @moduledoc """
  Chicago tests for the capability-section builder's delegation to ash_a2a.

  The subject is a real inline Ash resource that registers the `AshA2A`
  extension and declares real `a2a skill` overrides, plus a real unregistered
  resource. No mocks: every expectation is stated either against
  `AshA2A.Info` itself (proving pure projection) or against ash_a2a's
  published consequence law (proving the builder invents nothing).

  gapfix-adapters-001 conformed the builder to the canonical
  `AshSurface.Compiler.Section` behaviour: build/2, one normalized action
  entry per call (the resource-enumerating build/1 is retired).
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

  # The compiler's normalized action entry + shared context, as the canonical
  # build/2 behaviour receives them.
  defp entry(resource, action) do
    context = %{
      discovery: %{token: :erlang.unique_integer([:positive]), kind: :domain, actions: 1},
      action_id: "#{inspect(resource)}.#{action}",
      source: resource
    }

    action_entry = %{
      id: context.action_id,
      resource: resource,
      resource_name: inspect(resource),
      action: action,
      action_type: Ash.Resource.Info.action(resource, action).type,
      custom: %{},
      inputs: [],
      outputs: []
    }

    {action_entry, context}
  end

  defp build(resource, action) do
    {action_entry, context} = entry(resource, action)
    Compiler.Capability.build(action_entry, context)
  end

  describe "build/2 on the registered resource" do
    test "is a pure projection of AshA2A.Info's derived index" do
      derived = AshA2A.Info.capability_index(Stockpile)
      derived_ids = Map.new(derived, &{&1.id, &1})

      for action <- Ash.Resource.Info.public_actions(Stockpile) do
        id = capability_id(action.name)

        case Map.fetch(derived_ids, id) do
          {:ok, skill} ->
            # The same entry ash_a2a derived for this action -- the section
            # adds no capability and reorders nothing.
            assert {:ok, section} = build(Stockpile, action.name)
            assert section.capability_id == skill.id

          # An expose?: false override: no entry in the index, no section.
          :error ->
            assert build(Stockpile, action.name) == {:ok, nil}
        end
      end
    end

    test "every capability_id is ash_a2a's derived id, never a surface invention" do
      for action <- [:read, :create, :update, :destroy, :courier_notify, :recount_projection] do
        assert {:ok, section} = build(Stockpile, action)
        assert section.capability_id == inspect(Stockpile) <> ".#{action}"
      end
    end

    test "an expose?: false override removes a public action from the section" do
      # :audit_peek is a public Ash action, but ash_a2a's derived index drops
      # it; the section must mirror the index, not public_actions directly.
      assert {:ok, nil} = build(Stockpile, :audit_peek)
    end

    test "consequence classes come from ash_a2a's law, not from this repo" do
      assert {:ok, %{consequence_class: :observe}} = build(Stockpile, :read)
      assert {:ok, %{consequence_class: :change}} = build(Stockpile, :create)
      assert {:ok, %{consequence_class: :change}} = build(Stockpile, :update)
      assert {:ok, %{consequence_class: :change}} = build(Stockpile, :destroy)
      assert {:ok, %{consequence_class: :external_do}} = build(Stockpile, :courier_notify)
      assert {:ok, %{consequence_class: :unknown}} = build(Stockpile, :recount_projection)
    end

    test "authority/receipt requirements follow the consequence semantics" do
      # :observe -- CommandBus admits with no authority, anchors no receipt.
      assert {:ok, observe} = build(Stockpile, :read)
      refute observe.authority_required
      refute observe.receipt_required

      # :change -- refused :authority_required on nil authority;
      # RECEIPT_ANCHORED mandatory before DO.
      for action <- [:create, :update, :destroy] do
        assert {:ok, change} = build(Stockpile, action)
        assert change.authority_required
        assert change.receipt_required
      end

      # :external_do -- same consequence-bearing admission law.
      assert {:ok, external} = build(Stockpile, :courier_notify)
      assert external.authority_required
      assert external.receipt_required
    end

    test "an unclassified generic action keeps the fail-closed fence, no fabricated booleans" do
      assert {:ok, unknown} = build(Stockpile, :recount_projection)

      assert unknown.consequence_class == :unknown
      # CommandBus refuses :unknown as :consequence_unclassified before any
      # authority question; the section must not invent an answer either.
      assert is_nil(unknown.authority_required)
      assert is_nil(unknown.receipt_required)
    end

    test "IR entries are the canonical Capability shape" do
      assert {:ok, %Capability{}} = build(Stockpile, :read)
    end
  end

  describe "build/2 on an unregistered resource" do
    test "preserves nil -- no fabricated capability truth" do
      assert AshA2A.Info.capability_index(UnregisteredLedger) == nil

      for action <- [:read, :create] do
        assert build(UnregisteredLedger, action) == {:ok, nil}
      end
    end
  end

  describe "the Section behaviour" do
    test "the canonical behaviour is build/2; Capability conforms to it" do
      # gapfix-adapters-001: the resource-enumerating build/1 is retired; the
      # builder claims the canonical per-action behaviour.
      assert AshSurface.Compiler.Section.behaviour_info(:callbacks) == [build: 2]

      assert AshSurface.Compiler.Section in (Compiler.Capability.module_info()[:attributes][
                                               :behaviour
                                             ] || [])

      assert function_exported?(Compiler.Capability, :build, 2)
      refute function_exported?(Compiler.Capability, :build, 1)
    end

    test "a malformed action entry is refused typed, never coerced" do
      assert {:error, {:invalid_action_entry, :not_a_map}} =
               Compiler.Capability.build(:not_a_map, %{})

      assert {:error, {:invalid_action_entry, %{resource: "not_a_module"}}} =
               Compiler.Capability.build(%{resource: "not_a_module"}, %{})
    end
  end

  defp capability_id(action) do
    AshA2A.CapabilityIndex.Compiler.capability_id(Stockpile, action)
  end
end
