defmodule AshSurface.IR do
  @moduledoc """
  Local declaration of the semantic-delegation IR.

  `lib/ash_surface/ir.ex`, `lib/ash_surface/compiler/semantic.ex`, and the
  Section carrier are not on disk yet; they are declared here so the
  delegation truth below is pinned before the projection lands. When the lib
  modules land, these local declarations are removed in the same change and
  this suite must stay green unchanged.
  """

  defmodule Semantic do
    @moduledoc """
    Delegated semantic facts for one resource.

    Every field is nilable: a field carries a value only when AshR2RML's own
    compiled mapping proves that fact. Absence stays nil; it is never filled
    with a default, a namespace guess, or an unrelated Ash identity.
    """

    defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

    @type t :: %__MODULE__{
            subject_iri: String.t() | nil,
            capability_iri: String.t() | nil,
            predicates: [String.t()] | nil,
            shape_id: String.t() | nil,
            ontology: [String.t()] | nil
          }
  end

  defmodule Section do
    @moduledoc "One resource's compiled surface, carrying the delegated semantic facts."

    defstruct [:semantic]

    @type t :: %__MODULE__{semantic: AshSurface.IR.Semantic.t()}
  end
end

defmodule AshSurface.Compiler.Semantic do
  @moduledoc """
  Semantic delegation to AshR2RML.

  AshR2RML owns mapping truth. This compiler only reflects what
  `AshR2RML.Resource.Info.mapping_result/1` returns; it never rediscovers,
  fabricates, or repairs semantics. Mapped resources carry exactly the
  compiled subject template, predicate IRIs, and class set; unmapped
  resources carry an all-nil section; partial mappings surface nils only
  where the compiled mapping is absent.

  `capability_iri` and `shape_id` stay nil on the Ash-first path: AshR2RML's
  compiled mapping carries no per-resource capability or shape artifact
  (capability concepts live only in its ggen consumer ontology, shape IRIs
  only in the ontology-first `AshR2RML.SemanticIR`). Delegation leaves them
  nil rather than inventing counterparts.
  """

  alias AshR2RML.Resource.Info
  alias AshSurface.IR.{Section, Semantic}

  @spec section(module()) :: Section.t()
  def section(resource) do
    case Info.mapping_result(resource) do
      {:ok, mapping} -> %Section{semantic: carry(mapping)}
      {:error, _refusal} -> %Section{semantic: %Semantic{}}
    end
  end

  defp carry(mapping) do
    %Semantic{
      subject_iri: subject_template(mapping.subject_map),
      predicates: predicate_iris(mapping),
      ontology: ontology_classes(mapping)
    }
  end

  # subject_iri is the compiled rr:template verbatim. Column, constant, and
  # blank-node subjects compile without a template; that absence surfaces as
  # nil, never as the column/constant value dressed up as a template.
  defp subject_template(%{strategy: :template, value: value}) when is_binary(value), do: value
  defp subject_template(_subject_map), do: nil

  # Predicate IRIs exactly as compiled across property and reference maps;
  # sorted because AshR2RML normalizes maps deterministically. A mapping that
  # admits no predicates keeps predicates nil so absence stays observable.
  defp predicate_iris(mapping) do
    mapping.predicate_object_maps
    |> Enum.map(& &1.predicate_iri)
    |> Kernel.++(Enum.map(mapping.reference_object_maps, & &1.predicate_iri))
    |> Enum.uniq()
    |> Enum.sort()
    |> case do
      [] -> nil
      sorted -> sorted
    end
  end

  # ontology is the compiled rr:class set verbatim (already sorted and unique
  # under AshR2RML normalization); nil only when the mapping carries none.
  defp ontology_classes(%{class_iris: []}), do: nil
  defp ontology_classes(%{class_iris: classes}), do: classes
end

defmodule AshSurface.SemanticDelegationTest.Owner do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshR2RML.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false)
  end

  r2rml do
    table_name("owners")
    class("https://example.org/vocab/Owner")

    subject do
      template("https://example.org/owner/{id}")
    end

    property(:name, "https://example.org/vocab/name")
  end
end

defmodule AshSurface.SemanticDelegationTest.Widget do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshR2RML.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false)
    attribute(:quantity, :integer)
  end

  relationships do
    belongs_to(:owner, AshSurface.SemanticDelegationTest.Owner)
  end

  r2rml do
    table_name("widgets")
    class("https://example.org/vocab/Widget")

    subject do
      template("https://example.org/widget/{id}")
    end

    property(:name, "https://example.org/vocab/name")
    property(:quantity, "https://example.org/vocab/quantity")
    reference(:owner, "https://example.org/vocab/owner")
  end
end

defmodule AshSurface.SemanticDelegationTest.ColumnSubjectGadget do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshR2RML.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:label, :string)
  end

  r2rml do
    table_name("gadgets")
    class("https://example.org/vocab/Gadget")

    subject do
      column(:id)
    end

    property(:label, "https://example.org/vocab/label")
  end
end

defmodule AshSurface.SemanticDelegationTest.SubjectOnlyDevice do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshR2RML.Resource]

  attributes do
    uuid_primary_key(:id)
  end

  r2rml do
    table_name("devices")
    class("https://example.org/vocab/Device")

    subject do
      template("https://example.org/device/{id}")
    end
  end
end

defmodule AshSurface.SemanticDelegationTest.UnmappedTool do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, allow_nil?: false)
  end
end

defmodule AshSurface.SemanticDelegationTest do
  @moduledoc """
  Delegation truth against the real AshR2RML extension.

  Expectations are diffed against AshR2RML's own compiled output
  (`AshR2RML.Resource.Info.mapping!/1`), not against restated literals alone:
  the section must carry exactly what the mapping compiled — no loss, no
  drift, no fabrication. Literal falsifiers pin the delegation rules
  independently of the plumbing.
  """

  use ExUnit.Case, async: true

  alias AshR2RML.Resource.Info
  alias AshSurface.Compiler.Semantic, as: SemanticCompiler
  alias AshSurface.IR.Semantic

  use ExUnit.Case, async: true

  alias AshR2RML.Resource.Info
  alias AshSurface.Compiler.Semantic, as: SemanticCompiler
  alias AshSurface.IR.Semantic

  describe "mapped resource" do
    test "section carries exactly the compiled subject template, predicates, and ontology" do
      compiled = Info.mapping!(AshSurface.SemanticDelegationTest.Widget)
      section = SemanticCompiler.section(AshSurface.SemanticDelegationTest.Widget)
      semantic = section.semantic

      # Diff against AshR2RML's own compiled output.
      assert semantic.subject_iri == compiled.subject_map.value
      assert compiled.subject_map.strategy == :template

      assert semantic.predicates ==
               compiled.predicate_object_maps
               |> Kernel.++(compiled.reference_object_maps)
               |> Enum.map(& &1.predicate_iri)
               |> Enum.uniq()
               |> Enum.sort()

      assert semantic.ontology == compiled.class_iris

      # Independent literal falsifiers for the same delegation.
      assert semantic.subject_iri == "https://example.org/widget/{id}"

      assert semantic.predicates == [
               "https://example.org/vocab/name",
               "https://example.org/vocab/owner",
               "https://example.org/vocab/quantity"
             ]

      assert semantic.ontology == ["https://example.org/vocab/Widget"]

      # No Ash-first counterpart exists for these; nil, never fabricated.
      assert semantic.capability_iri == nil
      assert semantic.shape_id == nil
    end

    test "multi-class mapping carries the whole compiled class set" do
      compiled = Info.mapping!(AshSurface.SemanticDelegationTest.Owner)
      semantic = SemanticCompiler.section(AshSurface.SemanticDelegationTest.Owner).semantic

      assert semantic.ontology == compiled.class_iris
      assert semantic.ontology == ["https://example.org/vocab/Owner"]
    end
  end

  describe "unmapped resource" do
    test "semantic section is all-nil" do
      refute Info.mapped?(AshSurface.SemanticDelegationTest.UnmappedTool)

      assert SemanticCompiler.section(AshSurface.SemanticDelegationTest.UnmappedTool).semantic ==
               %Semantic{
                 subject_iri: nil,
                 capability_iri: nil,
                 predicates: nil,
                 shape_id: nil,
                 ontology: nil
               }
    end
  end

  describe "partial mapping" do
    test "column subject: subject template nil, present facts carried verbatim" do
      compiled = Info.mapping!(AshSurface.SemanticDelegationTest.ColumnSubjectGadget)

      semantic =
        SemanticCompiler.section(AshSurface.SemanticDelegationTest.ColumnSubjectGadget).semantic

      # The nil is proven by AshR2RML's own compiled state, not assumed.
      assert compiled.subject_map.strategy == :column
      assert semantic.subject_iri == nil

      assert semantic.predicates ==
               compiled.predicate_object_maps |> Enum.map(& &1.predicate_iri) |> Enum.sort()

      assert semantic.ontology == compiled.class_iris
      assert semantic.capability_iri == nil
      assert semantic.shape_id == nil
    end

    test "no mapped predicates: predicates nil, present facts carried verbatim" do
      compiled = Info.mapping!(AshSurface.SemanticDelegationTest.SubjectOnlyDevice)

      semantic =
        SemanticCompiler.section(AshSurface.SemanticDelegationTest.SubjectOnlyDevice).semantic

      # The nil is proven by AshR2RML's own compiled state, not assumed.
      assert compiled.predicate_object_maps == []
      assert compiled.reference_object_maps == []

      assert semantic.subject_iri == "https://example.org/device/{id}"
      assert semantic.predicates == nil
      assert semantic.ontology == compiled.class_iris
      assert semantic.capability_iri == nil
      assert semantic.shape_id == nil
    end
  end
end
