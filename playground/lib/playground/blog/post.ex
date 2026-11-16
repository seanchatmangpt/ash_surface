defmodule Playground.Blog.Post do
  use Ash.Resource,
    domain: Playground.Blog,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource]

  ets do
    private? false
  end

  json_api do
    type "post"
    includes [:author, :comments]

    routes do
      base "/posts"

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
      index :published, route: "/published"
      patch :publish, route: "/:id/publish"
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true, constraints: [min_length: 3]
    attribute :body, :string, public?: true
    attribute :status, :atom, constraints: [one_of: [:draft, :published, :archived]], default: :draft, public?: true
    attribute :points, :integer, default: 0, public?: true, constraints: [min: 0]
    attribute :tags, {:array, :string}, default: [], public?: true
    attribute :published_at, :utc_datetime, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, Playground.Blog.Author, public?: true, attribute_writable?: true
    has_many :comments, Playground.Blog.Comment, destination_attribute: :post_id, public?: true
  end

  calculations do
    calculate :title_length, :integer, expr(string_length(title)), public?: true
  end

  aggregates do
    count :comment_count, :comments, public?: true
  end

  actions do
    defaults [:read, :destroy]

    read :published do
      filter expr(status == :published)
    end

    create :create do
      primary? true
      accept [:title, :body, :status, :points, :tags, :author_id]
    end

    update :update do
      primary? true
      accept [:title, :body, :status, :points, :tags, :author_id]
    end

    update :publish do
      accept []
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    action :word_count, :integer do
      argument :text, :string, allow_nil?: false
      run fn input, _ctx -> {:ok, input.arguments.text |> String.split() |> length()} end
    end
  end

  pub_sub do
    module PlaygroundWeb.Endpoint
    prefix "post"
    publish_all :create, ["changed"]
    publish_all :update, ["changed"]
    publish_all :destroy, ["changed"]
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action(:word_count) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :editor)
    end
  end
end
