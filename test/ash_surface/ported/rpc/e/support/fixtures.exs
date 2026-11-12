defmodule AshSurface.Ported.E.Fixtures.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.E.Fixtures.NestedArray)
    resource(AshSurface.Ported.E.Fixtures.OrderHolder)
    resource(AshSurface.Ported.E.Fixtures.OrderMixedHolder)
  end
end

defmodule AshSurface.Ported.E.Fixtures.NestedArray do
  @moduledoc """
  Surface-extended copy of `AshSurface.Ported.NestedArrayConstraints` (the shared fixture has no
  `AshSurface.Resource` extension and so cannot be projected); same generic action.
  """
  use Ash.Resource,
    domain: AshSurface.Ported.E.Fixtures.Domain,
    validate_domain_inclusion?: false,
    extensions: [AshSurface.Resource]

  surface do
    type_name("NestedArray")
    projection(:validate)
  end

  actions do
    action :validate, :boolean do
      argument :bounded_matrix, {:array, {:array, :integer}} do
        allow_nil?(false)
        constraints(min_length: 1, max_length: 2, items: [min_length: 2, max_length: 3])
      end

      run(fn _input, _context -> {:ok, true} end)
    end
  end
end

defmodule AshSurface.Ported.E.Fixtures.OrderHolder do
  @moduledoc "Projects the ZodOrder diamond (NodeA -> NodeB/NodeC -> NodeD -> NodeE) as attributes."
  use Ash.Resource,
    domain: AshSurface.Ported.E.Fixtures.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    extensions: [AshSurface.Resource]

  surface do
    type_name("OrderHolder")
    projection(:create)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:root, AshSurface.Ported.ZodOrder.NodeA, public?: true)
    attribute(:leaf, AshSurface.Ported.ZodOrder.NodeE, public?: true)
  end

  actions do
    create :create do
      accept([:root, :leaf])
    end
  end
end

defmodule AshSurface.Ported.E.Fixtures.OrderMixedHolder do
  @moduledoc "Independent + chained embedded resources (reference: mixed dependent/independent)."
  use Ash.Resource,
    domain: AshSurface.Ported.E.Fixtures.Domain,
    data_layer: Ash.DataLayer.Ets,
    validate_domain_inclusion?: false,
    extensions: [AshSurface.Resource]

  surface do
    type_name("OrderMixedHolder")
    projection(:create)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:nested_profile, AshSurface.Ported.InputParsing.NestedProfile, public?: true)
    attribute(:task_metadata, AshSurface.Ported.TaskMetadata, public?: true)
    attribute(:todo_metadata, AshSurface.Ported.TodoMetadata, public?: true)
    attribute(:link, AshSurface.Ported.TodoContent.LinkContent, public?: true)
  end

  actions do
    create :create do
      accept([:nested_profile, :task_metadata, :todo_metadata, :link])
    end
  end
end
