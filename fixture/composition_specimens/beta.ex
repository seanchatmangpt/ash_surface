# Composition specimen extension B ("beta").
#
# Shape-identical to specimen A (templates/extension.ex.tmpl shape) but fully
# independent: distinct section name (:beta), distinct entity struct, distinct
# persisted key (:composition_specimens_beta_compiled), distinct Info namespace.
# Independence is the premise the composition court falsifies against.
defmodule CompositionSpecimens.Beta.Entity do
  @moduledoc "Target struct for the singleton `:entity` of section `:beta`."
  defstruct [:name, :count, :__identifier__, __spark_metadata__: nil]
end

defmodule CompositionSpecimens.Beta.Persist do
  @moduledoc """
  Transformer for specimen B: normalizes the raw `:beta` section into a compiled map
  persisted as `:composition_specimens_beta_compiled`.
  """
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    CompositionSpecimens.Order.record(:beta_persist)

    beta_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:beta])

    compiled = %{
      beta: beta_entities,
      beta_label: Spark.Dsl.Transformer.get_option(dsl_state, [:beta], :label)
    }

    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :composition_specimens_beta_compiled, compiled)}
  end
end

defmodule CompositionSpecimens.Beta.Info do
  @moduledoc """
  Public introspection API for specimen B. Namespaced strictly under :beta; nothing
  of A's leaks here.
  """
  def beta(resource), do: Spark.Dsl.Extension.get_entities(resource, [:beta])

  def compiled(resource) do
    case Spark.Dsl.Extension.get_persisted(resource, :composition_specimens_beta_compiled) do
      nil -> {:error, :not_compiled}
      compiled -> {:ok, compiled}
    end
  end

  def compiled?(resource), do: match?({:ok, _}, compiled(resource))
end

defmodule CompositionSpecimens.Beta do
  @moduledoc "Specimen extension B: sections [:beta], singleton `:entity`, Info getters."

  @entity %Spark.Dsl.Entity{
    name: :entity,
    target: CompositionSpecimens.Beta.Entity,
    args: [:name],
    identifier: :name,
    schema: [
      name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"],
      count: [type: :integer, doc: "Specimen count"]
    ]
  }

  @beta %Spark.Dsl.Section{
    name: :beta,
    describe: "Specimen extension B section",
    schema: [
      label: [type: :string, doc: "Specimen B label"]
    ],
    entities: [
      @entity
    ],
    singleton_entity_keys: [:entity]
  }

  use Spark.Dsl.Extension,
    sections: [@beta],
    transformers: [CompositionSpecimens.Beta.Persist],
    verifiers: []
end
