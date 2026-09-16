defmodule AshSurface.AshSectionTruthTest.Gadget do
  @moduledoc """
  Rich real inline Ash resource for ash-section truth tests.

  Simple data layer (no Repo). Covers all five action types (read/create/
  update/destroy/action), all six mission type families as typed arguments
  (atom/string/integer/boolean/uuid/map), required-vs-optional arguments,
  declared defaults, and declared policies. `:hidden` is declared but
  `public?: false`, so it is outside the exact public action set.
  """

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    authorizers: [Ash.Policy.Authorizer]

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true, allow_nil?: false)
    attribute(:rank, :integer, public?: true, default: 0)
    attribute(:live, :boolean, public?: true, default: false)
    attribute(:status, :atom, public?: true, constraints: [one_of: [:draft, :shipped]])
  end

  actions do
    read :search do
      argument(:status, :atom, allow_nil?: false)
      argument(:term, :string)
      argument(:limit, :integer, default: 25)
      argument(:verified, :boolean)
      argument(:owner, :uuid, allow_nil?: false)
      argument(:filters, :map, default: %{})
    end

    create :forge do
      accept([])
      argument(:name, :string, allow_nil?: false)
      argument(:rank, :integer, default: 0)
    end

    update :annotate do
      accept([])
      argument(:note, :string, allow_nil?: false)
      argument(:bump, :integer, default: 1)
    end

    destroy :discard do
      argument(:reason, :string)
    end

    action :ping do
      argument(:loud, :boolean, allow_nil?: false)
      returns(:string)
    end

    destroy(:hidden, public?: false)
  end

  policies do
    policy always() do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(actor_present())
    end

    policy [action(:forge), action(:discard)] do
      forbid_unless(actor_present())
    end
  end
end

defmodule AshSurface.AshSectionTruthTest do
  @moduledoc """
  TRUTH tests for the `ash` section: `AshSurface.Compiler.AshTruth` compiling a rich
  real inline Ash resource into `AshSurface.IR.Ash` and rendering it through the
  `AshSurface.Section` behaviour.

  Goldens are exact per-action sections over the five action types. The ash
  section carries only witnessed facts: typed arguments with required-vs-optional
  derived from `allow_nil?`, declared defaults surfaced verbatim, declared
  `returns` as outputs, and policies read-only. It NEVER includes presentation
  (labels, placeholders, widgets, ordering) or semantic guesses (inferred
  formats, examples, domain meaning the resource never declared).
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.AshTruth

  @gadget AshSurface.AshSectionTruthTest.Gadget
  @public_actions [:annotate, :discard, :forge, :ping, :search]

  # Witnessed policy facts: declared scope (conditions) and declared check set,
  # never evaluations. Identical across sections because policies are declared
  # at the resource level; scope lives in the condition facts.
  @policies [
    %{
      bypass: false,
      checks: [%{check: "Ash.Policy.Check.Static", kind: :authorize_if}],
      conditions: [%{check: "Ash.Policy.Check.Static", opts: %{result: true}}]
    },
    %{
      bypass: false,
      checks: [%{check: "Ash.Policy.Check.ActorPresent", kind: :authorize_if}],
      conditions: [%{check: "Ash.Policy.Check.ActionType", opts: %{type: [:read]}}]
    },
    %{
      bypass: false,
      checks: [%{check: "Ash.Policy.Check.ActorPresent", kind: :forbid_unless}],
      conditions: [
        %{check: "Ash.Policy.Check.Action", opts: %{action: [:forge]}},
        %{check: "Ash.Policy.Check.Action", opts: %{action: [:discard]}}
      ]
    }
  ]

  # Presentation and semantic-guess facts a consumer surface might be tempted
  # to synthesize. None of these is declared by the resource; none may appear.
  @banned_keys [
    :description,
    :display,
    :example,
    :format,
    :group,
    :guess,
    :help,
    :hint,
    :icon,
    :label,
    :meaning,
    :order,
    :placeholder,
    :semantic,
    :subtitle,
    :title,
    :tooltip,
    :ui,
    :widget
  ]

  # Types a guessing layer might infer from a string/atom argument. The
  # resource declared none of them, so the section must never carry them.
  @guessed_types ["color", "date", "datetime", "email", "phone", "text", "textarea", "url"]

  defp section_for(action) do
    assert {:ok, ir} = AshTruth.build(@gadget, action)
    assert {:ok, section} = AshTruth.section(ir, [])
    section
  end

  # Fact keys of the section tree. `:opts` (condition opts) and `:default`
  # (argument defaults) carry verbatim author-declared payloads, not section
  # facts, so they are walked as leaves.
  defp all_keys(map) when is_map(map) do
    Enum.flat_map(map, fn
      {:opts, _payload} -> [:opts]
      {:default, _payload} -> [:default]
      {key, value} -> [key | all_keys(value)]
    end)
  end

  defp all_keys(list) when is_list(list), do: Enum.flat_map(list, &all_keys/1)
  defp all_keys(_other), do: []

  test "golden section: read carries all six typed argument families" do
    assert section_for(:search) == %{
             section: "ash",
             resource: "AshSurface.AshSectionTruthTest.Gadget",
             action: :search,
             action_type: :read,
             inputs: [
               %{name: :status, type: "atom", required: true, default: nil},
               %{name: :term, type: "string", required: false, default: nil},
               %{name: :limit, type: "integer", required: false, default: 25},
               %{name: :verified, type: "boolean", required: false, default: nil},
               %{name: :owner, type: "uuid", required: true, default: nil},
               %{name: :filters, type: "map", required: false, default: %{}}
             ],
             outputs: nil,
             policies: @policies
           }
  end

  test "golden section: create" do
    assert section_for(:forge) == %{
             section: "ash",
             resource: "AshSurface.AshSectionTruthTest.Gadget",
             action: :forge,
             action_type: :create,
             inputs: [
               %{name: :name, type: "string", required: true, default: nil},
               %{name: :rank, type: "integer", required: false, default: 0}
             ],
             outputs: nil,
             policies: @policies
           }
  end

  test "golden section: update" do
    assert section_for(:annotate) == %{
             section: "ash",
             resource: "AshSurface.AshSectionTruthTest.Gadget",
             action: :annotate,
             action_type: :update,
             inputs: [
               %{name: :note, type: "string", required: true, default: nil},
               %{name: :bump, type: "integer", required: false, default: 1}
             ],
             outputs: nil,
             policies: @policies
           }
  end

  test "golden section: destroy" do
    assert section_for(:discard) == %{
             section: "ash",
             resource: "AshSurface.AshSectionTruthTest.Gadget",
             action: :discard,
             action_type: :destroy,
             inputs: [%{name: :reason, type: "string", required: false, default: nil}],
             outputs: nil,
             policies: @policies
           }
  end

  test "golden section: generic action surfaces declared returns, nothing invented" do
    assert section_for(:ping) == %{
             section: "ash",
             resource: "AshSurface.AshSectionTruthTest.Gadget",
             action: :ping,
             action_type: :action,
             inputs: [%{name: :loud, type: "boolean", required: true, default: nil}],
             outputs: %{returns: "string"},
             policies: @policies
           }
  end

  test "required-vs-optional follows allow_nil? mechanically and defaults surface verbatim" do
    inputs = section_for(:search).inputs

    assert %{
             :status => status,
             :owner => owner,
             :term => term,
             :limit => limit,
             :filters => filters
           } =
             Map.new(inputs, &{&1.name, &1})

    # allow_nil?: false -> required; no interpretation of type or name.
    assert status.required == true
    assert owner.required == true
    # allow_nil? defaults to true -> optional.
    assert term.required == false

    # Declared defaults surfaced verbatim; absence is nil, never invented.
    assert limit.default == 25
    assert filters.default == %{}
    assert term.default == nil
  end

  test "argument types are the witnessed Ash type names, never guessed formats" do
    types = section_for(:search).inputs |> Enum.map(& &1.type) |> Enum.sort()

    assert types == ["atom", "boolean", "integer", "map", "string", "uuid"]
    refute Enum.any?(types, &(&1 in @guessed_types))
  end

  test "every section fact is inside the admitted truth vocabulary" do
    vocabulary =
      MapSet.new(
        AshTruth.admitted_keys().section ++
          AshTruth.admitted_keys().input ++
          AshTruth.admitted_keys().output ++
          AshTruth.admitted_keys().policy ++ [:check, :kind, :opts]
      )

    for action <- @public_actions do
      keys = section_for(action) |> all_keys() |> MapSet.new()

      assert MapSet.subset?(keys, vocabulary),
             "#{inspect(action)} section carries facts outside the admitted truth vocabulary"
    end
  end

  test "the ash section never includes presentation or semantic-guess facts" do
    for action <- @public_actions do
      section = section_for(action)
      keys = all_keys(section)
      banned = Enum.filter(keys, &(&1 in @banned_keys))

      assert banned == [], "#{inspect(action)} section carries banned facts: #{inspect(banned)}"

      # Presentation also hides in values: a UI string like "Title" or
      # "text field" has no declared source. Every string in the section must
      # be a witnessed module name, type name, or the section name itself.
      strings =
        section
        |> all_strings()
        |> MapSet.new()

      assert MapSet.subset?(
               strings,
               MapSet.new(
                 ["ash", "atom", "boolean", "integer", "map", "string", "uuid"] ++
                   witness_modules()
               )
             )
    end
  end

  test "policies are read-only declared facts with exactly three admitted facts" do
    for action <- @public_actions do
      policies = section_for(action).policies

      assert policies == @policies

      assert Enum.all?(
               policies,
               &(Map.keys(&1) |> Enum.sort() == [:bypass, :checks, :conditions])
             )
    end
  end

  test "admission law: unknown and non-public actions are refused, never guessed" do
    assert {:error, {:unknown_public_action, :obliterate, @public_actions}} =
             AshTruth.build(@gadget, :obliterate)

    # Declared but public?: false stays outside the exact public action set.
    assert {:error, {:unknown_public_action, :hidden, @public_actions}} =
             AshTruth.build(@gadget, :hidden)

    assert {:error, {:not_an_ash_resource, Enum}} = AshTruth.build(Enum, :search)
  end

  defp witness_modules do
    [
      "AshSurface.AshSectionTruthTest.Gadget",
      "Ash.Policy.Check.Static",
      "Ash.Policy.Check.ActorPresent",
      "Ash.Policy.Check.ActionType",
      "Ash.Policy.Check.Action"
    ]
  end

  defp all_strings(map) when is_map(map), do: Enum.flat_map(map, fn {_k, v} -> all_strings(v) end)
  defp all_strings(list) when is_list(list), do: Enum.flat_map(list, &all_strings/1)
  defp all_strings(binary) when is_binary(binary), do: [binary]
  defp all_strings(_other), do: []
end
