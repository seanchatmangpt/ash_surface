defmodule Playground.Blog.Author do
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
    type "author"

    routes do
      base "/authors"

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :role, :atom, constraints: [one_of: [:admin, :editor, :reader]], default: :reader, public?: true
    attribute :bio, :string, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_email, :email, pre_check_with: Playground.Blog
  end

  relationships do
    has_many :posts, Playground.Blog.Post, destination_attribute: :author_id, public?: true
  end

  calculations do
    calculate :display_name, :string, expr(name <> " <" <> email <> ">"), public?: true
  end

  aggregates do
    count :post_count, :posts, public?: true
  end

  actions do
    defaults [:read, :destroy, create: [:name, :email, :role, :bio], update: [:name, :email, :role, :bio]]
  end

  pub_sub do
    module PlaygroundWeb.Endpoint
    prefix "author"
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

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :editor)
    end
  end
end
