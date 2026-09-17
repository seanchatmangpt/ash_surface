defmodule AshSurface.CompilerTest.Post do
  @moduledoc "Inline real resource so the manifest fixture carries true Ash modules."
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])
  end
end

# The ONLY doubles in this suite: minimal inline test-double sections.
# They implement the real `AshSurface.Compiler.Section` build/2 contract and
# record what they observed in the process dictionary (compile runs in the
# test process, so this is plain state, not message spying).

defmodule AshSurface.CompilerTest.CountingSection do
  @moduledoc "Counts build calls and distinct discovery tokens observed."

  def build(_action, %{discovery: %{token: token}} = _context) do
    {calls, tokens} = state()
    :erlang.put(__MODULE__, {calls + 1, [token | tokens]})
    {:ok, nil}
  end

  def reset, do: :erlang.put(__MODULE__, {0, []})

  def state do
    case :erlang.get(__MODULE__) do
      {calls, tokens} -> {calls, tokens}
      :undefined -> {0, []}
    end
  end

  def build_calls, do: state() |> elem(0)

  def discovery_tokens, do: state() |> elem(1) |> MapSet.new()

  def record_token(token) do
    {calls, tokens} = state()
    :erlang.put(__MODULE__, {calls, [token | tokens]})
  end
end

defmodule AshSurface.CompilerTest.Rec do
  @moduledoc "Shared log for the section-order recorders."

  def log(tag) do
    tail =
      case :erlang.get(__MODULE__) do
        :undefined -> []
        log -> log
      end

    :erlang.put(__MODULE__, [tag | tail])
    :ok
  end

  def log do
    case :erlang.get(__MODULE__) do
      :undefined -> []
      log -> Enum.reverse(log)
    end
  end
end

defmodule AshSurface.CompilerTest.Rec.AshSection do
  alias AshSurface.CompilerTest.Rec
  alias AshSurface.IR

  def build(action, context) do
    Rec.log({context.action_id, :ash})

    {:ok,
     %IR.Ash{
       resource: action.resource_name,
       action: to_string(action.action),
       action_type: action.action_type,
       inputs: action.inputs,
       outputs: action.outputs,
       policies: []
     }}
  end
end

defmodule AshSurface.CompilerTest.Rec.SemanticSection do
  alias AshSurface.CompilerTest.Rec
  alias AshSurface.IR

  def build(action, context) do
    Rec.log({context.action_id, :semantic})

    {:ok,
     %IR.Semantic{
       subject_iri: "urn:ash:#{action.resource_name}",
       capability_iri: "urn:ash:capability:#{action.id}",
       predicates: [],
       shape_id: action.id,
       ontology: "dfcm"
     }}
  end
end

defmodule AshSurface.CompilerTest.Rec.CapabilitySection do
  alias AshSurface.CompilerTest.Rec
  alias AshSurface.IR

  def build(action, context) do
    Rec.log({context.action_id, :capability})

    {:ok,
     %IR.Capability{
       capability_id: action.id,
       consequence_class: action.action_type,
       authority_required: action.action_type != :read,
       receipt_required: true
     }}
  end
end

defmodule AshSurface.CompilerTest.Rec.PresentationSection do
  alias AshSurface.CompilerTest.Rec
  alias AshSurface.IR

  def build(action, context) do
    Rec.log({context.action_id, :presentation})

    {:ok,
     %IR.Presentation{
       label: to_string(action.action),
       group: action.resource_name,
       order: 0,
       widget: "default",
       format: "json"
     }}
  end
end

defmodule AshSurface.CompilerTest.Rec.SchemaSection do
  alias AshSurface.CompilerTest.Rec
  alias AshSurface.IR

  def build(action, context) do
    Rec.log({context.action_id, :schema})

    {:ok,
     %IR.Schema{
       input: action.inputs,
       output: action.outputs,
       zod: nil,
       aria: nil
     }}
  end
end

defmodule AshSurface.CompilerTest.FailingSection do
  def build(_action, _context), do: {:error, :boom}
end

defmodule AshSurface.CompilerTest do
  @moduledoc """
  Chicago-style state tests for the `AshSurface.Compiler` orchestrator.

  The compiler's law is DiscoverOnce -> Normalize -> per-action section
  builders -> IR assembly. These tests prove each stage from returned state
  and recorded section observations (real inline doubles implementing the
  real `build/2` behaviour): exactly one discovery pass whatever the number
  of actions and sections, section invocation in the declared order, one
  assembled `%AshSurface.IR{}` per action with each section's result in its
  own field, and digest stability over the normalized action map.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Argument, Entrypoint, Metadata}
  alias AshSurface.Compiler
  alias AshSurface.IR

  import AshSurface.CompilerTest.CountingSection,
    only: [reset: 0, build_calls: 0, discovery_tokens: 0]

  defp entry(resource, name, type, opts \\ []) do
    %Entrypoint{
      resource: resource,
      action: %Action{
        name: name,
        type: type,
        inputs: Keyword.get(opts, :inputs, []),
        metadata: Keyword.get(opts, :metadata, []),
        custom: %{}
      }
    }
  end

  defp manifest do
    %Manifest{
      entrypoints: [
        entry(AshSurface.CompilerTest.Post, :read, :read),
        entry(AshSurface.CompilerTest.Post, :create, :create,
          inputs: [
            %Argument{name: :title, allow_nil?: false, has_default?: false, required?: true}
          ],
          metadata: [%Metadata{name: :id, allow_nil?: false}]
        ),
        entry(AshSurface.CompilerTest.Post, :update, :update)
      ]
    }
  end

  defp rec_sections do
    [
      ash: AshSurface.CompilerTest.Rec.AshSection,
      semantic: AshSurface.CompilerTest.Rec.SemanticSection,
      capability: AshSurface.CompilerTest.Rec.CapabilitySection,
      presentation: AshSurface.CompilerTest.Rec.PresentationSection,
      schema: AshSurface.CompilerTest.Rec.SchemaSection
    ]
  end

  defp counting_sections do
    [
      ash: AshSurface.CompilerTest.CountingSection,
      semantic: AshSurface.CompilerTest.CountingSection,
      capability: AshSurface.CompilerTest.CountingSection,
      presentation: AshSurface.CompilerTest.CountingSection,
      schema: AshSurface.CompilerTest.CountingSection
    ]
  end

  describe "single discovery" do
    test "a counting double records exactly one discovery call for N actions" do
      reset()

      assert {:ok, irs} = Compiler.compile(manifest(), sections: counting_sections())
      # 3 actions x 5 sections: every build saw the same one discovery pass.
      assert build_calls() == 15
      assert MapSet.size(discovery_tokens()) == 1
      assert length(irs) == 3
    end

    test "discovery happens once for a domain source" do
      reset()

      assert {:ok, irs} =
               Compiler.compile(AshSurface.Fixtures.Domain, sections: counting_sections())

      # 2 public fixture actions x 5 sections, still exactly one discovery.
      assert build_calls() == 10
      assert MapSet.size(discovery_tokens()) == 1
      assert length(irs) == 2
    end
  end

  describe "section invocation order" do
    test "sections run in the declared keyword order, per action" do
      assert {:ok, irs} = Compiler.compile(manifest(), sections: rec_sections())
      assert length(irs) == 3

      log = AshSurface.CompilerTest.Rec.log()

      # Per action: ash -> semantic -> capability -> presentation -> schema.
      for action_id <- [
            "AshSurface.CompilerTest.Post.create",
            "AshSurface.CompilerTest.Post.read",
            "AshSurface.CompilerTest.Post.update"
          ] do
        assert Enum.filter(log, &match?({^action_id, _}, &1)) ==
                 Enum.map(
                   [:ash, :semantic, :capability, :presentation, :schema],
                   &{action_id, &1}
                 )
      end

      # Actions are compiled in id order.
      assert Enum.map(log, fn {id, _} -> id end)
             |> Enum.uniq() ==
               [
                 "AshSurface.CompilerTest.Post.create",
                 "AshSurface.CompilerTest.Post.read",
                 "AshSurface.CompilerTest.Post.update"
               ]
    end

    test "a reordered binding list reorders invocation" do
      reversed =
        rec_sections()
        |> Enum.reverse()

      assert {:ok, _irs} = Compiler.compile(manifest(), sections: reversed)

      assert Enum.take(AshSurface.CompilerTest.Rec.log(), 5) ==
               Enum.map(
                 Enum.reverse(rec_sections()),
                 fn {key, _mod} -> {"AshSurface.CompilerTest.Post.create", key} end
               )
    end
  end

  describe "IR assembly" do
    test "one IR per action, each section's result in its own field" do
      assert {:ok, [create, read, update] = irs} =
               Compiler.compile(manifest(), sections: rec_sections())

      assert Enum.all?(irs, &match?(%IR{}, &1))
      assert Enum.all?(irs, &(&1.version == "26.9.17"))

      assert create.ash == %IR.Ash{
               resource: "AshSurface.CompilerTest.Post",
               action: "create",
               action_type: :create,
               inputs: [%{name: "title", type: nil, allow_nil: false, has_default: false}],
               outputs: ["id"],
               policies: []
             }

      assert create.semantic.shape_id == "AshSurface.CompilerTest.Post.create"

      assert create.semantic.capability_iri ==
               "urn:ash:capability:AshSurface.CompilerTest.Post.create"

      assert create.capability.authority_required == true
      assert read.capability.authority_required == false
      assert update.presentation.label == "update"
      assert read.schema.input == []
      assert read.schema.output == []
    end

    test "domain source compiles the fixture domain's public actions" do
      assert {:ok, irs} = Compiler.compile(AshSurface.Fixtures.Domain, sections: rec_sections())

      assert Enum.map(irs, & &1.semantic.shape_id) == [
               "AshSurface.Fixtures.VolunteerMilestone.read",
               "AshSurface.Fixtures.VolunteerMilestone.record"
             ]

      assert Enum.map(irs, & &1.ash.action_type) == [:read, :create]
    end
  end

  describe "digest stability" do
    test "stable across compiles and entrypoint order" do
      assert {:ok, first} = Compiler.compile(manifest(), sections: rec_sections())
      assert {:ok, second} = Compiler.compile(manifest(), sections: rec_sections())

      reordered = %Manifest{manifest() | entrypoints: Enum.reverse(manifest().entrypoints)}
      assert {:ok, reversed} = Compiler.compile(reordered, sections: rec_sections())

      assert Enum.map(first, & &1.digest) == Enum.map(second, & &1.digest)
      assert Enum.map(first, & &1.digest) == Enum.map(reversed, & &1.digest)
      assert first == reversed

      digest = hd(first).digest
      assert byte_size(digest) == 64
      assert digest == String.downcase(digest)
      assert Enum.all?(first, &(&1.digest == digest))
    end

    test "sensitive to action facts" do
      assert {:ok, base} = Compiler.compile(manifest(), sections: rec_sections())

      renamed =
        %Manifest{
          manifest()
          | entrypoints: [
              entry(AshSurface.CompilerTest.Post, :read, :read),
              entry(AshSurface.CompilerTest.Post, :publish, :create,
                inputs: [
                  %Argument{name: :title, allow_nil?: false, has_default?: false, required?: true}
                ],
                metadata: [%Metadata{name: :id, allow_nil?: false}]
              ),
              entry(AshSurface.CompilerTest.Post, :update, :update)
            ]
        }

      retyped =
        %Manifest{
          manifest()
          | entrypoints: [
              entry(AshSurface.CompilerTest.Post, :read, :read),
              entry(AshSurface.CompilerTest.Post, :create, :update,
                inputs: [
                  %Argument{name: :title, allow_nil?: false, has_default?: false, required?: true}
                ],
                metadata: [%Metadata{name: :id, allow_nil?: false}]
              ),
              entry(AshSurface.CompilerTest.Post, :update, :update)
            ]
        }

      assert {:ok, renamed_irs} = Compiler.compile(renamed, sections: rec_sections())
      assert {:ok, retyped_irs} = Compiler.compile(retyped, sections: rec_sections())

      assert hd(renamed_irs).digest != hd(base).digest
      assert hd(retyped_irs).digest != hd(base).digest
    end
  end

  describe "fail-closed refusals" do
    test "unadmitted sources are refused with a typed error" do
      assert Compiler.compile("nope", sections: rec_sections()) ==
               {:error, {:unsupported_source, "nope"}}

      assert {:error, {:unsupported_source, 42}} =
               Compiler.compile(42, sections: rec_sections())

      assert {:error, {:unsupported_source, AshSurface.CompilerTest.Post}} =
               Compiler.compile(AshSurface.CompilerTest.Post, sections: rec_sections())
    end

    test "unknown section keys and non-conforming modules are refused" do
      assert Compiler.compile(manifest(),
               sections: [bogus: AshSurface.CompilerTest.Rec.AshSection]
             ) ==
               {:error, {:unknown_section_keys, [:bogus]}}

      assert Compiler.compile(manifest(), sections: [ash: String]) ==
               {:error, {:invalid_section_module, :ash, String}}

      # An IR record is whole: a partial binding is refused, not nil-filled.
      assert Compiler.compile(manifest(),
               sections: [ash: AshSurface.CompilerTest.Rec.AshSection]
             ) ==
               {:error, {:missing_section_keys, [:semantic, :capability, :presentation, :schema]}}
    end

    test "a failing section aborts the compile with the action and section named" do
      sections = Keyword.put(rec_sections(), :schema, AshSurface.CompilerTest.FailingSection)

      assert Compiler.compile(manifest(), sections: sections) ==
               {:error,
                {:section_failed, "AshSurface.CompilerTest.Post.create", {:schema, :boom}}}
    end
  end
end
