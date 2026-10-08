# ANTI-VACUITY mutant: specimen A' ("alpha clash").
#
# Deliberately declares the SAME section name (:alpha) and the SAME singleton entity
# key (:entity) as specimen A -- the duplicate-singleton-key composition defect the
# law forbids. Compiling a draft that attaches BOTH CompositionSpecimens.Alpha and
# CompositionSpecimens.AlphaClash must fail cleanly with a Spark error naming the
# conflict; the composition court asserts exactly that failure. If Spark ever starts
# silently accepting duplicate singleton keys, this file plus the court's clash test
# turn red and expose the regression.
defmodule CompositionSpecimens.AlphaClash.Entity do
  @moduledoc "Duplicate target struct for the conflicting singleton `:entity` of section `:alpha`."
  defstruct [:name, :weight, :__identifier__, __spark_metadata__: nil]
end

defmodule CompositionSpecimens.AlphaClash.Persist do
  @moduledoc "Transformer for the clash mutant (mirrors A's Persist; never co-resident with A on a legal draft)."
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    CompositionSpecimens.Order.record(:alpha_clash_persist)

    alpha_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:alpha])

    compiled = %{
      alpha: alpha_entities,
      alpha_label: Spark.Dsl.Transformer.get_option(dsl_state, [:alpha], :label)
    }

    {:ok,
     Spark.Dsl.Transformer.persist(dsl_state, :composition_specimens_alpha_clash_compiled, compiled)}
  end
end

defmodule CompositionSpecimens.AlphaClash do
  @moduledoc "Mutant extension A': DUPLICATE section :alpha + singleton key :entity."

  @entity %Spark.Dsl.Entity{
    name: :entity,
    target: CompositionSpecimens.AlphaClash.Entity,
    args: [:name],
    identifier: :name,
    schema: [
      name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"],
      weight: [type: :integer, doc: "Specimen weight (clash mutant)"]
    ]
  }

  @alpha %Spark.Dsl.Section{
    name: :alpha,
    describe: "Specimen extension A' (clash mutant) section",
    schema: [
      label: [type: :string, doc: "Specimen A' label"]
    ],
    entities: [
      @entity
    ],
    singleton_entity_keys: [:entity]
  }

  use Spark.Dsl.Extension,
    sections: [@alpha],
    transformers: [CompositionSpecimens.AlphaClash.Persist],
    verifiers: []
end
