defmodule AshSurface.Compiler.AshSectionTest.Document do
  @moduledoc """
  Real inline Ash resource for ash-section tests.

  Simple data layer (no Repo), policy authorizer on. Public action set:
  `[:update, :create, :read, :by_title, :publish, :archive_summary]`;
  `:shred` is declared but `public?: false`, so it is outside the public set.
  """

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    authorizers: [Ash.Policy.Authorizer]

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
    attribute(:body, :string, public?: true)
  end

  actions do
    defaults([:read, create: [:title], update: [:title, :body]])

    read(:by_title) do
      argument(:title, :string, allow_nil?: false)
    end

    update(:publish) do
      accept([])
      argument(:note, :string, allow_nil?: true)
    end

    action(:archive_summary, :string) do
      argument(:since, :integer, allow_nil?: false)
    end

    destroy(:shred, public?: false)
  end

  policies do
    policy always() do
      authorize_if(always())
    end

    policy action(:publish) do
      forbid_if(actor_attribute_equals(:role, "banned"))
    end
  end
end

defmodule AshSurface.Compiler.AshSectionTest.Plain do
  @moduledoc """
  Real inline Ash resource WITHOUT the policy authorizer: policies section of
  the IR must carry `[]`, never crash, never invent policy semantics.
  """

  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Compiler.AshSectionTest.NotAResource do
  @moduledoc false
end

defmodule AshSurface.Compiler.AshSectionTest do
  @moduledoc """
  Tests for the ash section of the compiler, re-pointed at gapfix-adapters-001
  from the RETIRED resource-enumerating rival `AshSurface.Compiler.Ash` to the
  integrated one-canon builder `AshSurface.Compiler.AshTruth` (the rival
  violated the `AshSurface.IR.Ash` @type: raw accepted-key atom lists as
  inputs, a raw `returns` type atom as outputs). Every assertion here pins the
  exact metadata Ash itself reports for the inline resource above, through the
  canon's typed sub-shapes (`%IR.Input{}`, `%IR.Output{}`, `%IR.Policy{}`).

  Reconciliation note (ledgered in HANDWRITTEN.md): the retired rival
  restated ACCEPTED ATTRIBUTES as inputs (`Ash.Resource.Info.action_inputs/2`);
  the canon restates DECLARED ARGUMENTS only (`act.arguments`), so the
  defaults-expanded CRUD actions here carry `[]` inputs — accepted attributes
  are input-contract facts the surface does not re-derive.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.AshTruth
  alias AshSurface.IR

  @document AshSurface.Compiler.AshSectionTest.Document
  @plain AshSurface.Compiler.AshSectionTest.Plain
  @not_a_resource AshSurface.Compiler.AshSectionTest.NotAResource

  # The exact public action names, in the order Ash reports them
  # (defaults expand in reverse declaration order).
  @public_actions [:update, :create, :read, :by_title, :publish, :archive_summary]

  # Exact declared-argument inputs per public action, typed through the
  # canon's sub-shape (required is the mechanical negation of `allow_nil?`;
  # defaults surface verbatim; accepted attributes are NOT restated).
  @expected_inputs %{
    update: [],
    create: [],
    read: [],
    by_title: [%IR.Input{name: :title, type: "string", required: true, default: nil}],
    publish: [%IR.Input{name: :note, type: "string", required: false, default: nil}],
    archive_summary: [%IR.Input{name: :since, type: "integer", required: true, default: nil}]
  }

  @expected_action_types %{
    update: :update,
    create: :create,
    read: :read,
    by_title: :read,
    publish: :update,
    archive_summary: :action
  }

  # Witnessed policy facts: declared scope (conditions) and declared check
  # set, projected read-only into the canon's %IR.Policy{} sub-shape.
  @expected_policies [
    %IR.Policy{
      bypass: false,
      checks: [%{check: "Ash.Policy.Check.Static", kind: :authorize_if}],
      conditions: [%{check: "Ash.Policy.Check.Static", opts: %{result: true}}]
    },
    %IR.Policy{
      bypass: false,
      checks: [%{check: "Ash.Policy.Check.ActorAttributeEquals", kind: :forbid_if}],
      conditions: [%{check: "Ash.Policy.Check.Action", opts: %{action: [:publish]}}]
    }
  ]

  defp section_for(action) do
    assert {:ok, section} = AshTruth.build(@document, action)
    section
  end

  test "every public action yields a conforming section with exact inputs, type, and outputs" do
    for action <- @public_actions do
      section = section_for(action)

      assert %IR.Ash{resource: @document} = section
      assert section.action == action
      assert section.action_type == @expected_action_types[action]
      assert section.inputs == @expected_inputs[action]
      assert section.outputs == outputs_for(action)
      assert section.policies == @expected_policies
    end

    assert Enum.map(@public_actions, &section_for(&1).action) ==
             Enum.map(Ash.Resource.Info.public_actions(@document), & &1.name)
  end

  test "outputs carry only the generic action's declared returns" do
    outputs = Map.new(@public_actions, &{&1, outputs_for(&1)})

    # Only the generic action declares returns; CRUD actions return the record
    # and carry no :returns metadata, so outputs is nil for them.
    assert outputs[:archive_summary] == %IR.Output{returns: "string"}
    assert outputs[:update] == nil
    assert outputs[:create] == nil
    assert outputs[:read] == nil
    assert outputs[:by_title] == nil
    assert outputs[:publish] == nil
  end

  test "IR.Ash has the canonical six-field section shape" do
    section = section_for(:read)

    assert section |> Map.from_struct() |> Map.keys() |> Enum.sort() == [
             :action,
             :action_type,
             :inputs,
             :outputs,
             :policies,
             :resource
           ]
  end

  test "canonical top-level IR shape owns the ash facet" do
    facet = section_for(:read)

    assert struct!(IR, ash: facet) |> Map.from_struct() |> Map.keys() |> Enum.sort() == [
             :ash,
             :capability,
             :digest,
             :presentation,
             :schema,
             :semantic,
             :version
           ]

    # Canonical law (v01): the empty IR is constructible — every section nil
    # is an honest UNKNOWN; `ash: nil` no longer raises. Unknown fields still
    # raise: the shape is law, not a suggestion.
    assert %IR{
             version: nil,
             digest: nil,
             ash: nil,
             semantic: nil,
             capability: nil,
             presentation: nil,
             schema: nil
           } = IR.new()

    assert_raise KeyError, ~r/not_a_section/, fn -> struct!(IR, not_a_section: true) end

    assert %IR{version: 1, digest: nil, ash: ^facet} = struct!(IR, ash: facet, version: 1)
  end

  test "declared-but-private actions are excluded" do
    # The canon refuses a non-public action with the exact public set named —
    # exclusion is a typed refusal, never a silently narrowed build.
    assert {:error,
            {:unknown_public_action, :shred,
             [:archive_summary, :by_title, :create, :publish, :read, :update]}} =
             AshTruth.build(@document, :shred)

    assert %{name: :shred, public?: false} in Enum.map(
             Ash.Resource.Info.actions(@document),
             &Map.take(&1, [:name, :public?])
           )

    assert length(Ash.Resource.Info.public_actions(@document)) == length(@public_actions)
  end

  test "policies are carried read-only from the authorizer onto every section" do
    real_policies = Ash.Policy.Info.policies(@document)

    assert length(real_policies) == 2
    assert Enum.all?(real_policies, &match?(%Ash.Policy.Policy{}, &1))

    # Projected read-only into %IR.Policy{} — scope and check set only, never
    # a reinterpretation or evaluation.
    for action <- @public_actions do
      assert section_for(action).policies == @expected_policies
    end

    # Read-only: building the section does not mutate the resource's policies.
    assert Ash.Policy.Info.policies(@document) == real_policies
  end

  test "resource without the policy authorizer carries empty policies, not an error" do
    assert {:ok, section} = AshTruth.build(@plain, :read)

    assert section.action == :read
    assert section.policies == []
  end

  test "non-Ash source is refused with a typed refusal" do
    assert {:error, {:not_an_ash_resource, @not_a_resource}} =
             AshTruth.build(@not_a_resource, :read)

    assert {:error, {:not_an_ash_resource, String}} = AshTruth.build(String, :read)
  end

  defp outputs_for(:archive_summary), do: %IR.Output{returns: "string"}
  defp outputs_for(_), do: nil
end
