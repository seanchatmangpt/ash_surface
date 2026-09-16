defmodule AshSurface.Compiler.AriaSectionTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Compiler.AriaSectionTest.Wish)
  end
end

defmodule AshSurface.Compiler.AriaSectionTest.Wish do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Compiler.AriaSectionTest.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:note, :string, public?: true, allow_nil?: false)
    attribute(:done, :boolean, public?: true, allow_nil?: true)
    attribute(:hours, :integer, public?: true, allow_nil?: true)
  end

  actions do
    defaults([:read])

    create :grant do
      accept([:note, :done, :hours])
    end
  end
end

defmodule AshSurface.Compiler.AriaSectionTest do
  @moduledoc """
  State-based (Chicago school) verification of `AshSurface.Compiler.Aria`.

  Real modules, real returns: the pure tests drive the actual section against
  the canonical IR structs and real `Ash.Info.Manifest.Type` values; the
  integration test derives an ARIA contract from a real generated Ash manifest
  (domain + ETS resource defined inline, registered under a dedicated otp_app
  key). Assertions target returned data only — this section renders nothing,
  so no DOM, no components, no mocks.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest.Type
  alias AshSurface.Compiler.{Aria, IR}

  @otp_app :ash_surface_aria_section_test
  @wish "AshSurface.Compiler.AriaSectionTest.Wish"

  setup do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Compiler.AriaSectionTest.Domain])

    on_exit(fn ->
      Application.delete_env(@otp_app, :ash_domains)
    end)

    :ok
  end

  defp input(name, kind, opts \\ []) do
    %IR.Input{
      name: name,
      type: %Type{kind: kind, values: Keyword.get(opts, :values, nil)},
      allow_nil?: Keyword.get(opts, :allow_nil?, true),
      description: Keyword.get(opts, :description, nil)
    }
  end

  defp schema(inputs, action_id \\ "Demo.Resource#create") do
    %IR.Schema{action_id: action_id, inputs: inputs}
  end

  test "section name mounts its output at schema.aria" do
    assert Aria.name() == :aria
    base = schema([input(:lane, :string)])
    assert base.aria == nil

    assert {:ok, %IR.Schema{} = mounted} = Aria.mount(base, %{"lane" => %{"label" => "Lane"}})

    assert mounted.aria == %{
             "lane" => %{
               "role" => "textbox",
               "required" => false,
               "label" => "Lane",
               "describedby" => nil
             }
           }

    # Pure derivation: the source schema is never mutated.
    assert base.aria == nil
  end

  test "type to role mapping table is conservative and complete" do
    assert Aria.role_for_type(%Type{kind: :string}) == "textbox"
    assert Aria.role_for_type(%Type{kind: :ci_string}) == "textbox"
    assert Aria.role_for_type(%Type{kind: :boolean}) == "checkbox"
    assert Aria.role_for_type(%Type{kind: :enum, values: [:bronze, :silver]}) == "switch"
    assert Aria.role_for_type(%Type{kind: :integer}) == "slider"

    # Unmapped kinds stay nil; the section never invents a role.
    for kind <- [:float, :decimal, :uuid, :date, :atom, :term, :map, :unknown] do
      assert Aria.role_for_type(%Type{kind: kind}) == nil
    end

    assert Aria.role_for_type(%Type{kind: nil}) == nil
    assert Aria.role_for_type(nil) == nil

    # The table is the single source: build/2 agrees with role_for_type/1.
    {:ok, aria} =
      Aria.build(
        schema([
          input(:note, :string),
          input(:done, :boolean),
          input(:tier, :enum, values: [:on, :off])
        ])
      )

    assert aria["note"]["role"] == "textbox"
    assert aria["done"]["role"] == "checkbox"
    assert aria["tier"]["role"] == "switch"
  end

  test "required propagates from allow_nil? and from nothing else" do
    {:ok, aria} =
      Aria.build(
        schema([
          input(:hard, :string, allow_nil?: false),
          input(:soft, :string, allow_nil?: true),
          input(:unknown, :string, allow_nil?: nil)
        ])
      )

    assert aria["hard"]["required"] == true
    assert aria["soft"]["required"] == false
    # Missing allow_nil? information is not fabricate into requiredness.
    assert aria["unknown"]["required"] == false
  end

  test "describedby ids are stable per action_id and never collide across actions" do
    described = fn action_id ->
      schema([input(:lane, :string, description: "Which lane to toll")], action_id)
      |> Aria.build()
      |> then(fn {:ok, aria} -> aria["lane"]["describedby"] end)
    end

    assert described.("Demo.Resource#record") == described.("Demo.Resource#record")
    assert described.("Demo.Resource#record") == "Demo-Resource-record-lane-description"
    assert described.("Demo.Resource#void") == "Demo-Resource-void-lane-description"
    assert described.("Demo.Resource#record") != described.("Demo.Resource#void")

    assert Aria.describedby_id("Demo.Resource#record", :lane) ==
             "Demo-Resource-record-lane-description"

    # Deterministic across builds: same action, same inputs, identical contract.
    {:ok, one} = Aria.build(schema([input(:lane, :string, description: "d")]))
    {:ok, two} = Aria.build(schema([input(:lane, :string, description: "d")]))
    assert one == two
  end

  test "labels come only from the presentation section's output" do
    inputs = [input(:lane, :string), input(:fare, :integer), input(:note, :string)]

    presentation = %{"lane" => %{"label" => "Toll lane"}, :fare => %{label: "Fare (cents)"}}

    {:ok, aria} = Aria.build(schema(inputs), presentation)

    assert aria["lane"]["label"] == "Toll lane"
    assert aria["fare"]["label"] == "Fare (cents)"
    # No presentation entry for this input: nil, not a humanized guess.
    assert aria["note"]["label"] == nil

    # The presentation output may arrive wrapped under "inputs"/:inputs.
    {:ok, wrapped} = Aria.build(schema(inputs), %{inputs: presentation})
    assert wrapped == aria

    # Without presentation passed in, every label stays nil.
    {:ok, bare} = Aria.build(schema(inputs))
    assert bare["lane"]["label"] == nil
  end

  test "nils stay nil: no fabricated roles, labels, or describedby targets" do
    {:ok, aria} =
      Aria.build(schema([input(:mystery, :duration), input(:blank, :string, description: "")]))

    assert aria["mystery"] == %{
             "role" => nil,
             "required" => false,
             "label" => nil,
             "describedby" => nil
           }

    # An id with no descriptive content behind it would be a dangling reference.
    assert aria["blank"]["describedby"] == nil
  end

  test "refuses schemas without an action identity and non-map presentation" do
    assert {:error, :missing_action_id} = Aria.build(%IR.Schema{action_id: nil, inputs: []})

    assert {:error, {:invalid_presentation, :garbage}} =
             Aria.build(schema([input(:lane, :string)]), :garbage)
  end

  test "derives an ARIA contract from a real generated Ash manifest" do
    assert {:ok, surface} = AshSurface.from_app(@otp_app)

    entrypoint =
      Enum.find(surface.manifest.entrypoints, &(&1.action.name == :grant))

    schema = %IR.Schema{
      action_id: AshSurface.action_id(entrypoint),
      inputs: entrypoint.action.inputs
    }

    assert {:ok, aria} = Aria.build(schema, %{"note" => %{"label" => "Wish note"}})

    assert aria["note"]["role"] == "textbox"
    assert aria["note"]["required"] == true
    assert aria["note"]["label"] == "Wish note"

    assert aria["done"]["role"] == "checkbox"
    assert aria["done"]["required"] == false

    assert aria["hours"]["role"] == "slider"
    assert aria["hours"]["required"] == false

    # The facet mounts on the canonical schema as plain data.
    assert {:ok, %IR.Schema{aria: mounted}} =
             Aria.mount(schema, %{"note" => %{"label" => "Wish note"}})

    assert mounted == aria
    assert @wish <> "#grant" == schema.action_id
  end

  test "an action with no inputs yields an empty contract, not an error" do
    assert {:ok, %{}} = Aria.build(schema([]))
  end
end
