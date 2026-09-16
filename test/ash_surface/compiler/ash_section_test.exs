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
  First-ever tests for `AshSurface.Compiler.Ash`, the ash section of the
  compiler: it populates `IR.Ash` from REAL Ash metadata only
  (`Ash.Resource.Info.public_actions/1`, `action_inputs/2`, action returns,
  resource policies). No semantics, no capability, no presentation — those are
  sibling sections; every assertion here pins the exact metadata Ash itself
  reports for the inline resource above.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler
  alias AshSurface.IR

  @document AshSurface.Compiler.AshSectionTest.Document
  @plain AshSurface.Compiler.AshSectionTest.Plain
  @not_a_resource AshSurface.Compiler.AshSectionTest.NotAResource

  # The exact public action names, in the order Ash reports them
  # (defaults expand in reverse declaration order).
  @public_actions [:update, :create, :read, :by_title, :publish, :archive_summary]

  # Exact accepted-input keys per public action, from Ash's own persisted
  # action_inputs (arguments plus accepted attributes; publish accepts none).
  @expected_inputs %{
    update: [:body, :title],
    create: [:title],
    read: [],
    by_title: [:title],
    publish: [:note],
    archive_summary: [:since]
  }

  @expected_action_types %{
    update: :update,
    create: :create,
    read: :read,
    by_title: :read,
    publish: :update,
    archive_summary: :action
  }

  test "every public action yields a section with exact inputs, action type, and outputs" do
    assert {:ok, sections} = Compiler.Ash.build(@document)

    assert Enum.map(sections, & &1.action) == @public_actions

    assert Enum.map(sections, & &1.action) ==
             Enum.map(Ash.Resource.Info.public_actions(@document), & &1.name)

    for section <- sections do
      assert %IR.Ash{} = section
      assert section.resource == @document
      assert section.action_type == @expected_action_types[section.action]
      assert section.inputs == @expected_inputs[section.action]
    end

    # Only the generic action declares returns; CRUD actions return the record
    # and carry no :returns metadata, so outputs is nil for them.
    outputs = sections |> Map.new(&{&1.action, &1.outputs})
    assert outputs[:archive_summary] == Ash.Type.String
    assert outputs[:update] == nil
    assert outputs[:create] == nil
    assert outputs[:read] == nil
    assert outputs[:by_title] == nil
    assert outputs[:publish] == nil

    # One full struct, exact against real Ash metadata for :publish.
    assert %IR.Ash{
             resource: @document,
             action: :publish,
             action_type: :update,
             inputs: [:note],
             outputs: nil,
             policies: Ash.Policy.Info.policies(@document)
           } in sections
  end

  test "IR.Ash has the canonical six-field section shape" do
    assert {:ok, [section | _]} = Compiler.Ash.build(@document)

    assert section |> Map.from_struct() |> Map.keys() |> Enum.sort() == [
             :action,
             :action_type,
             :inputs,
             :outputs,
             :policies,
             :resource
           ]
  end

  # Until the shared lib/ash_surface/ir.ex lands, the IR is declared locally
  # in the compiler file; this pins that declaration to the canonical shape so
  # integration extracts it verbatim instead of discovering drift.
  test "locally declared IR matches the canonical top-level shape" do
    assert {:ok, [facet | _]} = Compiler.Ash.build(@document)

    assert struct!(IR, ash: facet) |> Map.from_struct() |> Map.keys() |> Enum.sort() == [
             :ash,
             :capability,
             :digest,
             :presentation,
             :schema,
             :semantic,
             :version
           ]

    # The ash facet is the root: an IR cannot be constructed without one.
    assert_raise ArgumentError, ~r/the following keys must also be given when building/, fn ->
      struct!(IR, version: 1)
    end

    assert %IR{version: 1, digest: nil, ash: ^facet} = struct!(IR, ash: facet)
  end

  test "declared-but-private actions are excluded" do
    assert {:ok, sections} = Compiler.Ash.build(@document)

    refute :shred in Enum.map(sections, & &1.action)

    assert %{name: :shred, public?: false} in Enum.map(
             Ash.Resource.Info.actions(@document),
             &Map.take(&1, [:name, :public?])
           )

    assert length(sections) == length(Ash.Resource.Info.public_actions(@document))
  end

  test "policies are carried read-only from the authorizer onto every section" do
    assert {:ok, sections} = Compiler.Ash.build(@document)
    real_policies = Ash.Policy.Info.policies(@document)

    assert length(real_policies) == 2
    assert Enum.all?(real_policies, &match?(%Ash.Policy.Policy{}, &1))

    # Carried verbatim — the authorizer's own structs, not a reinterpretation.
    for section <- sections do
      assert section.policies == real_policies
    end

    # Read-only: building the section does not mutate the resource's policies.
    assert Ash.Policy.Info.policies(@document) == real_policies
  end

  test "resource without the policy authorizer carries empty policies, not an error" do
    assert {:ok, sections} = Compiler.Ash.build(@plain)

    assert Enum.map(sections, & &1.action) == [:read]

    for section <- sections do
      assert section.policies == []
    end
  end

  test "non-Ash source is refused with a typed refusal" do
    assert {:error, refusals} = Compiler.Ash.build(@not_a_resource)
    assert [%{code: "not_an_ash_resource", detail: detail}] = refusals
    assert detail =~ inspect(@not_a_resource)

    assert {:error, [%{code: "not_an_ash_resource"}]} = Compiler.Ash.build(String)
  end
end
