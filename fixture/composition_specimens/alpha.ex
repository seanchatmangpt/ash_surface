# Composition specimen extension A ("alpha").
#
# Same Spark.Dsl.Extension shape as packs/ash-extension-pack/templates/extension.ex.tmpl
# renders: section + entity + singleton key, Persist transformer, Info module, declared
# via `use Spark.Dsl.Extension` with sections/transformers/verifiers. Independent of
# specimen B by construction -- no shared module, no shared persisted key, no shared
# section name.
defmodule CompositionSpecimens.Alpha.Entity do
  @moduledoc "Target struct for the singleton `:entity` of section `:alpha`."
  defstruct [:name, :weight, :__identifier__, __spark_metadata__: nil]
end

defmodule CompositionSpecimens.Alpha.Persist do
  @moduledoc """
  Transformer for specimen A: normalizes the raw `:alpha` section into a compiled map
  persisted as `:composition_specimens_alpha_compiled`.
  """
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    CompositionSpecimens.Order.record(:alpha_persist)

    alpha_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:alpha])

    compiled = %{
      alpha: alpha_entities,
      alpha_label: Spark.Dsl.Transformer.get_option(dsl_state, [:alpha], :label)
    }

    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :composition_specimens_alpha_compiled, compiled)}
  end
end

defmodule CompositionSpecimens.Alpha.Info do
  @moduledoc """
  Public introspection API for specimen A -- the Info-getter surface the composition
  court reads. Namespaced strictly under :alpha; nothing of B's leaks here.
  """
  def alpha(resource), do: Spark.Dsl.Extension.get_entities(resource, [:alpha])

  def compiled(resource) do
    case Spark.Dsl.Extension.get_persisted(resource, :composition_specimens_alpha_compiled) do
      nil -> {:error, :not_compiled}
      compiled -> {:ok, compiled}
    end
  end

  def compiled?(resource), do: match?({:ok, _}, compiled(resource))
end

defmodule CompositionSpecimens.Alpha do
  @moduledoc "Specimen extension A: sections [:alpha], singleton `:entity`, Info getters."

  @entity %Spark.Dsl.Entity{
    name: :entity,
    target: CompositionSpecimens.Alpha.Entity,
    args: [:name],
    identifier: :name,
    schema: [
      name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"],
      weight: [type: :integer, doc: "Specimen weight"]
    ]
  }

  @alpha %Spark.Dsl.Section{
    name: :alpha,
    describe: "Specimen extension A section",
    schema: [
      label: [type: :string, doc: "Specimen A label"]
    ],
    entities: [
      @entity
    ],
    singleton_entity_keys: [:entity]
  }

  use Spark.Dsl.Extension,
    sections: [@alpha],
    transformers: [CompositionSpecimens.Alpha.Persist],
    verifiers: []
end
