defmodule AshSurface.IRTest do
  use ExUnit.Case, async: true
  alias AshSurface.IR

  test "constructs the empty IR and every embedded section without enforced keys" do
    ir = %IR{}

    assert ir.version == nil
    assert ir.digest == nil
    assert ir.ash == nil
    assert ir.semantic == nil
    assert ir.capability == nil
    assert ir.presentation == nil
    assert ir.schema == nil

    # @enforce_keys is none across the family: bare construction must work.
    assert %IR.Ash{} == %IR.Ash{}
    assert %IR.Semantic{} == %IR.Semantic{}
    assert %IR.Capability{} == %IR.Capability{}
    assert %IR.Presentation{} == %IR.Presentation{}
    assert %IR.Schema{} == %IR.Schema{}
  end

  test "pins the wave-wide shape of the IR family" do
    assert field_names(%IR{}) ==
             [:ash, :capability, :digest, :presentation, :schema, :semantic, :version]

    assert field_names(%IR.Ash{}) ==
             [:action, :action_type, :inputs, :outputs, :policies, :resource]

    assert field_names(%IR.Semantic{}) ==
             [:capability_iri, :ontology, :predicates, :shape_id, :subject_iri]

    assert field_names(%IR.Capability{}) ==
             [:authority_required, :capability_id, :consequence_class, :receipt_required]

    assert field_names(%IR.Presentation{}) == [:format, :group, :label, :order, :widget]

    assert field_names(%IR.Schema{}) == [:aria, :input, :output, :zod]
  end

  defp field_names(struct) do
    struct |> Map.from_struct() |> Map.keys() |> Enum.sort()
  end

  test "embedded defaults are nil and false, nothing else" do
    ash = %IR.Ash{}

    for struct <- [%IR.Ash{}, %IR.Semantic{}, %IR.Presentation{}, %IR.Schema{}] do
      for {key, value} <- Map.from_struct(struct) do
        assert value == nil, "expected nil default for #{inspect(struct.__struct__)}.#{key}"
      end
    end

    assert ash.resource == nil and ash.action == nil and ash.action_type == nil
    assert ash.inputs == nil and ash.outputs == nil and ash.policies == nil

    capability = %IR.Capability{}

    for {key, value} <- Map.from_struct(capability) do
      assert value in [nil, false],
             "expected nil/false default for IR.Capability.#{key}, got #{inspect(value)}"
    end

    assert capability.capability_id == nil
    assert capability.consequence_class == nil
    assert capability.authority_required == false
    assert capability.receipt_required == false
  end

  test "new/0 and new/1 construct from the admitted top-level fields only" do
    assert %IR{} = IR.new()

    ash = %IR.Ash{resource: AshSurface.Fixtures.VolunteerMilestone, action: :read}
    ir = IR.new(version: "26.9.16", digest: "deadbeef", ash: ash)

    assert ir.version == "26.9.16"
    assert ir.digest == "deadbeef"
    assert ir.ash == ash
    assert ir.semantic == nil

    assert_raise KeyError, fn -> IR.new(telepathy: true) end
  end

  test "section/1 returns the five embedded struct types" do
    assert IR.sections() == [:ash, :semantic, :capability, :presentation, :schema]

    assert IR.section(:ash) == IR.Ash
    assert IR.section(:semantic) == IR.Semantic
    assert IR.section(:capability) == IR.Capability
    assert IR.section(:presentation) == IR.Presentation
    assert IR.section(:schema) == IR.Schema

    semantic_mod = IR.section(:semantic)
    assert semantic_mod == IR.Semantic
    assert struct(semantic_mod, subject_iri: "zoe:Need#42").subject_iri == "zoe:Need#42"

    assert_raise FunctionClauseError, fn -> IR.section(:nope) end
  end

  test "section/2 reads the five embedded structs back out of a populated IR" do
    ash = %IR.Ash{resource: "Need", action: "assign", action_type: :update}
    semantic = %IR.Semantic{subject_iri: "zoe:Need#42", capability_iri: "cap:assign_need"}

    capability = %IR.Capability{
      capability_id: "assign_need",
      consequence_class: :COMPENSATABLE,
      authority_required: true,
      receipt_required: true
    }

    presentation = %IR.Presentation{label: "Assign need", group: "needs", order: 3}
    schema = %IR.Schema{zod: "z.object({ role: z.string() })"}

    ir = %IR{
      version: "26.9.16",
      ash: ash,
      semantic: semantic,
      capability: capability,
      presentation: presentation,
      schema: schema
    }

    assert %IR.Ash{} = IR.section(ir, :ash)
    assert IR.section(ir, :ash) == ash
    assert IR.section(ir, :semantic) == semantic
    assert IR.section(ir, :capability) == capability
    assert IR.section(ir, :presentation) == presentation
    assert IR.section(ir, :schema) == schema

    empty = IR.new()
    assert IR.section(empty, :ash) == nil

    assert_raise FunctionClauseError, fn -> IR.section(ir, :telepathy) end
  end

  test "carries admitted facts without deciding them" do
    ir = %IR{
      semantic: %IR.Semantic{
        subject_iri: "zoe:KingdomNeed#need_42",
        capability_iri: "cap:intercede",
        predicates: %{"status" => "active"},
        shape_id: "shape:need:v3",
        ontology: "zoe"
      },
      capability: %IR.Capability{
        capability_id: "intercede",
        consequence_class: :UNKNOWN,
        authority_required: true,
        receipt_required: true
      }
    }

    # Recorded requirements are facts about the source, not grants held here.
    assert ir.capability.consequence_class == :UNKNOWN
    assert ir.capability.authority_required == true
    assert ir.semantic.subject_iri == "zoe:KingdomNeed#need_42"
    assert ir.semantic.predicates["status"] == "active"
  end

  test "moduledoc states the IR invariant verbatim" do
    {:docs_v1, _, _, _, %{"en" => doc}, _, _} = Code.fetch_docs(IR)

    assert doc =~ "IR determines NOTHING about existence, meaning, or DO-authority"
    assert doc =~ "carries admitted facts from its five sources"
  end
end
