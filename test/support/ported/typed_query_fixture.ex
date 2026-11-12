defmodule AshSurface.Ported.TqComment do
  @moduledoc "Private typed-query fixture: comment child resource."
  use Ash.Resource,
    domain: AshSurface.Ported.TqDomain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:content, :string, public?: true)
    attribute(:todo_id, :uuid, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.TqTodo do
  @moduledoc """
  Private typed-query fixture (counterpart of the reference `list_todos_user_page` typed query on
  its Todo resource). Declared apart from `AshSurface.Ported.Todo` so shared fixtures and the
  manifest counts of other lanes are untouched.
  """
  use Ash.Resource,
    domain: AshSurface.Ported.TqDomain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    typed_query :list_todos_user_page, :read do
      description("Pre-configured query for the user dashboard page")
      fields_const_name("listTodosUserPage")
      result_type_name("ListTodosUserPageResult")
      fields([:id, :title, :description, :priority, :comment_count, comments: [:id, :content]])
    end
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:completed, :boolean, default: false, public?: true)

    attribute :priority, :atom do
      constraints(one_of: [:low, :medium, :high, :urgent])
      default(:medium)
      public?(true)
    end
  end

  relationships do
    has_many :comments, AshSurface.Ported.TqComment do
      destination_attribute(:todo_id)
      public?(true)
    end
  end

  aggregates do
    count(:comment_count, :comments, public?: true)
  end

  actions do
    read :read do
      primary?(true)
      argument(:priority_filter, :atom, allow_nil?: true)
      pagination(offset?: true, default_limit: 10, countable: true, required?: false)
    end
  end
end

defmodule AshSurface.Ported.TqDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.TqTodo)
    resource(AshSurface.Ported.TqComment)
  end
end

defmodule AshSurface.Ported.TypedQueryRpc do
  @moduledoc """
  Installs the typed-query fixture manifest and RPC entry table into the pipeline and runs typed
  queries over caller-built results. `TqTodo` declares the typed queries; `list_tq_todos` is the
  RPC entry of its read action.
  """
  alias AshSurface.Ported.{TqComment, TqTodo}
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support, TypedQuery}
  alias AshSurface.RuntimeParity.RequestedFields.Compat

  @otp_app :ash_surface_ported_tq

  def entries, do: [Pipeline.entry(:list_tq_todos, TqTodo, :read)]

  def install do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.TqDomain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Support.install(Compat.prepare(manifest), entries())
  end

  def run(name, params, result, opts \\ []) do
    install()
    TypedQuery.run(name, params, result, opts)
  end

  def parse(name, params, opts \\ []) do
    install()
    TypedQuery.parse(name, params, opts)
  end

  def todo(attrs \\ []),
    do:
      struct(
        TqTodo,
        Keyword.merge(
          [
            id: "aaaaaaaa-0000-0000-0000-000000000001",
            title: "Test Todo 1",
            description: "First test todo",
            priority: :high,
            completed: false,
            comment_count: 0,
            comments: []
          ],
          attrs
        )
      )

  def comment(attrs \\ []),
    do:
      struct(
        TqComment,
        Keyword.merge([id: "bbbbbbbb-0000-0000-0000-000000000001", content: "hi"], attrs)
      )
end
