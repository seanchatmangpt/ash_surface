# Delegation truth for the capability section, proven against REAL ash_a2a
# (dep: github.com/seanchatmangpt/ash_a2a @ e25ed6e, test-only).
#
# Chicago discipline: no mocks, no hand-asserted doubles of ash_a2a logic.
# The oracle for every projection claim is ash_a2a's own API output --
# `AshA2A.Info.capability_index_result/1` (derived by
# `AshA2A.CapabilityIndex.Compiler` from `Ash.Resource.Info.public_actions/1`)
# and the real `AshA2A.CommandBus.run/4` admission/anchoring behavior.
#
# The three production-side declarations (IR, Section, Compiler.Capability)
# do not exist in lib/ yet; per file discipline they are declared locally in
# this test file only. Each mirrors exactly one upstream ash_a2a clause,
# cited inline; when they graduate to lib/ these tests travel with them.

defmodule AshSurface.CapabilityDelegationTest.IR do
  @moduledoc """
  Locally declared intermediate representation for delegated capability
  truth (pending lib-side graduation; see file header).
  """

  defmodule Capability do
    @moduledoc """
    One delegated capability as the consumer surface carries it.

    `capability_id` and `consequence_class` are NEVER invented here: they
    are `AshA2A.Skill.id`/`.consequence` exactly as
    `AshA2A.Info.capability_index_result/1` derives them.

    `authority_required`/`receipt_required` mirror the real
    `AshA2A.CommandBus` consequence protocol:

      * `:observe` -- `CommandBus.admit/2` returns `:ok` with NO Authority
        (command_bus.ex `defp admit(_command, :observe)`) and
        `prepare_receipt_anchor/3` anchors `{:ok, nil}` -- both false.
      * `:change`/`:external_do` -- admission demands a real `Authority`
        (`:authority_required` refusal without one) and a `Receipt.pending`
        outbox anchor is mandatory before DO -- both true.
      * `:unknown` -- the fail-closed class: `CommandBus` refuses it with
        `:consequence_unclassified` BEFORE any authority or receipt
        protocol applies, so requirement booleans are `nil` (undefined),
        never guessed. The class itself carries the refusal truth.
    """

    @enforce_keys [:capability_id, :consequence_class, :authority_required, :receipt_required]
    defstruct [:capability_id, :consequence_class, :authority_required, :receipt_required]

    @type consequence_class :: AshA2A.Skill.consequence() | nil

    @type t :: %__MODULE__{
            capability_id: String.t() | nil,
            consequence_class: consequence_class(),
            authority_required: boolean() | nil,
            receipt_required: boolean() | nil
          }
  end
end

defmodule AshSurface.CapabilityDelegationTest.Section do
  @moduledoc """
  Locally declared consumer-surface section for one Ash subject (pending
  lib-side graduation; see file header).

  `capabilities` is `nil` -- never an invented list -- when the subject is
  not an `AshA2A`-registered resource/domain
  (`AshA2A.Info.capability_index_result/1` -> `{:error, :not_compiled}`).
  """

  defstruct [:resource, :registered, :capabilities]

  @type t :: %__MODULE__{
          resource: module(),
          registered: boolean(),
          capabilities: [AshSurface.CapabilityDelegationTest.IR.Capability.t()] | nil
        }
end

defmodule AshSurface.CapabilityDelegationTest.Compiler.Capability do
  @moduledoc """
  Locally declared derivation of an `AshSurface.CapabilityDelegationTest.Section` from the REAL
  `AshA2A.Info` capability index (pending lib-side graduation; see file
  header). Ash remains the canonical capability source: this compiler
  projects, it never manufactures.
  """

  alias AshSurface.CapabilityDelegationTest.{IR, Section}

  @spec derive(module()) :: Section.t()
  def derive(resource) do
    case AshA2A.Info.capability_index_result(resource) do
      {:ok, skills} ->
        %Section{resource: resource, registered: true, capabilities: Enum.map(skills, &project/1)}

      {:error, :not_compiled} ->
        %Section{resource: resource, registered: false, capabilities: nil}
    end
  end

  defp project(skill) do
    %IR.Capability{
      capability_id: skill.id,
      consequence_class: skill.consequence,
      authority_required: requirement(skill.consequence, :authority),
      receipt_required: requirement(skill.consequence, :receipt)
    }
  end

  # AshA2A.CommandBus consequence protocol, mirrored clause by clause:
  # admit/2 demands an Authority for exactly [:change, :external_do];
  # prepare_receipt_anchor/3 anchors a Receipt for exactly those classes.
  defp requirement(consequence, _kind) when consequence in [:change, :external_do], do: true
  defp requirement(:observe, _kind), do: false

  # Fail-closed class: refused before either protocol applies -- undefined,
  # not guessed (see IR.Capability's @moduledoc).
  defp requirement(:unknown, _kind), do: nil
end

defmodule AshSurface.CapabilityDelegationTest.Registered do
  @moduledoc """
  Real Ash resource registered with the real `AshA2A` extension.

  Public actions need no `skill` declaration (zero-config projection); one
  residual override lifts the generic `:signal` action off the fail-closed
  `:unknown` default onto an explicit `:external_do` classification, and one
  private read stays unexposed by construction.
  """

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshA2A]

  attributes do
    uuid_primary_key(:id)
    attribute(:label, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])

    read :internal do
      public?(false)
    end

    create :enroll do
      accept([:label])
    end

    action :probe, :map do
      run(fn _input, _context -> {:ok, %{probe: true}} end)
    end

    action :signal, :map do
      run(fn _input, _context -> {:ok, %{signal: true}} end)
    end
  end

  a2a do
    skill(:signal, :signal, consequence: :external_do)
  end
end

defmodule AshSurface.CapabilityDelegationTest.Bare do
  @moduledoc "Same shape, NO AshA2A extension: the unregistered subject."

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:label, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])

    create :enroll do
      accept([:label])
    end
  end
end

defmodule AshSurface.CapabilityDelegationTest do
  @moduledoc """
  Delegation truth: the section carries capability id / consequence /
  authority+receipt requirements EXACTLY as real ash_a2a derives them.
  """

  use ExUnit.Case, async: true

  alias AshSurface.CapabilityDelegationTest.Compiler.Capability, as: CapabilityCompiler
  alias AshSurface.CapabilityDelegationTest.IR.Capability

  # The v23-pinned ash_a2a CommandBus claims receipts through a real
  # ReceiptStore.Memory GenServer; it must be supervised before run/4.
  setup do
    start_supervised!(AshA2A.ReceiptStore.Memory)
    :ok
  end

  @registered AshSurface.CapabilityDelegationTest.Registered
  @bare AshSurface.CapabilityDelegationTest.Bare

  defp cap!(section, action) do
    id = AshA2A.CapabilityIndex.Compiler.capability_id(@registered, action)

    Enum.find(section.capabilities, &(&1.capability_id == id)) ||
      flunk("no section capability for #{id}: #{inspect(section.capabilities)}")
  end

  describe "registered resource: section truth is ash_a2a's own derivation" do
    test "every section capability equals the real index entry, field for field" do
      section = CapabilityCompiler.derive(@registered)

      # The oracle is ash_a2a's own API output, not a fixture of ours.
      assert {:ok, skills} = AshA2A.Info.capability_index_result(@registered)
      assert length(section.capabilities) == length(skills)

      by_id = Map.new(section.capabilities, &{&1.capability_id, &1})

      for skill <- skills do
        assert Map.has_key?(by_id, skill.id)

        assert Map.fetch!(by_id, skill.id) == %Capability{
                 capability_id: skill.id,
                 consequence_class: skill.consequence,
                 authority_required: requirement(skill.consequence),
                 receipt_required: requirement(skill.consequence)
               }
      end
    end

    test "consequence classes are the real derived defaults, not ours" do
      section = CapabilityCompiler.derive(@registered)

      assert cap!(section, :read).consequence_class == :observe
      assert cap!(section, :enroll).consequence_class == :change
      # Generic :action with no override stays on the fail-closed default.
      assert cap!(section, :probe).consequence_class == :unknown
      # The one residual override we declared is honored by the real compiler.
      assert cap!(section, :signal).consequence_class == :external_do
    end

    test "the private action is never projected into the section" do
      section = CapabilityCompiler.derive(@registered)

      assert {:error, :skill_not_found} = AshA2A.Info.skill(@registered, :internal)

      refute Enum.any?(
               section.capabilities,
               &String.contains?(&1.capability_id, ".internal")
             )
    end

    test "single-skill lookup agrees with AshA2A.Info.skill/2" do
      section = CapabilityCompiler.derive(@registered)

      assert {:ok, skill} = AshA2A.Info.skill(@registered, :enroll)
      assert cap!(section, :enroll).capability_id == skill.id
      assert cap!(section, :enroll).consequence_class == skill.consequence
    end
  end

  describe "unregistered resource: nils, never invented" do
    test "ash_a2a itself reports no compiled index" do
      assert AshA2A.Info.capability_index(@bare) == nil
      assert {:error, :not_compiled} = AshA2A.Info.capability_index_result(@bare)
      refute AshA2A.Info.capability_index?(@bare)
    end

    test "section carries nils and admits no capability, however public its actions" do
      section = CapabilityCompiler.derive(@bare)

      assert section.registered == false
      assert section.capabilities == nil
      assert section.resource == @bare

      # The bare resource HAS public actions (ash_a2a just never registered
      # them); the section must not invent capability truth for them.
      assert Enum.any?(Ash.Resource.Info.public_actions(@bare), &(&1.name == :read))

      refute Enum.any?(List.wrap(section.capabilities), fn cap ->
               String.starts_with?(cap.capability_id, inspect(@bare))
             end)
    end
  end

  describe ":observe-class requires no authority (real CommandBus agrees)" do
    test "section says authority_required false; the real bus admits with zero authority" do
      section = CapabilityCompiler.derive(@registered)
      observe = cap!(section, :read)

      assert observe.consequence_class == :observe
      assert observe.authority_required == false
      assert observe.receipt_required == false

      command =
        AshA2A.Command.new(observe.capability_id,
          agent_id: "delegation-test-agent",
          principal_id: "anonymous",
          input: %{}
        )

      # No authority anywhere on this command.
      assert command.authority == nil

      assert {:ok, %AshA2A.Receipt{consequence: :observe}} =
               AshA2A.CommandBus.run(command, A2A.Message.new_user("read"), @registered)
    end
  end

  describe ":change-class authority and receipt truth (real CommandBus refusals)" do
    test "without authority the real bus refuses exactly :authority_required" do
      section = CapabilityCompiler.derive(@registered)
      change = cap!(section, :enroll)

      assert change.consequence_class == :change
      assert change.authority_required == true
      assert change.receipt_required == true

      command =
        AshA2A.Command.new(change.capability_id,
          agent_id: "delegation-test-agent",
          principal_id: "anonymous",
          input: %{"label" => "witness"}
        )

      assert command.authority == nil

      assert {:error, %{code: :authority_required}} =
               AshA2A.CommandBus.run(command, A2A.Message.new_user("enroll"), @registered)
    end

    test "with real authority the consequence crosses the receipt boundary" do
      change = cap!(CapabilityCompiler.derive(@registered), :enroll)

      command =
        AshA2A.Command.new(change.capability_id,
          agent_id: "delegation-test-agent",
          principal_id: "operator",
          input: %{"label" => "witness"},
          authority: AshA2A.Authority.from_verified_identity("operator", change.capability_id)
        )

      assert AshA2A.Authority.admits?(command.authority, command)

      # Whatever the data layer replies, a :change consequence can only
      # complete through a real Receipt -- anchoring is mandatory.
      assert {:ok, %AshA2A.Receipt{consequence: :change}} =
               AshA2A.CommandBus.run(command, A2A.Message.new_user("enroll"), @registered)
    end
  end

  describe ":unknown-class stays fail-closed with undefined requirements" do
    test "section carries nil booleans; the real bus refuses :consequence_unclassified" do
      section = CapabilityCompiler.derive(@registered)
      probe = cap!(section, :probe)

      assert probe.consequence_class == :unknown
      assert probe.authority_required == nil
      assert probe.receipt_required == nil

      command =
        AshA2A.Command.new(probe.capability_id,
          agent_id: "delegation-test-agent",
          principal_id: "operator",
          input: %{},
          authority: AshA2A.Authority.from_verified_identity("operator", probe.capability_id)
        )

      # Even WITH a real standing authority the unclassified class refuses.
      assert {:error, %{code: :consequence_unclassified}} =
               AshA2A.CommandBus.run(command, A2A.Message.new_user("probe"), @registered)
    end
  end

  # The oracle used by the field-for-field test: the requirement booleans
  # asserted against the compiler mirror must be derivable from ash_a2a's
  # own consequence protocol alone.
  defp requirement(consequence) when consequence in [:change, :external_do], do: true
  defp requirement(:observe), do: false
  defp requirement(:unknown), do: nil
end
