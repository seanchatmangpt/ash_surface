defmodule Playground.Blog.Comment do
  use Ash.Resource,
    domain: Playground.Blog,
    data_layer: Ash.DataLayer.Ets,
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshJsonApi.Resource]

  ets do
    private? false
  end

  json_api do
    type "comment"

    routes do
      base "/comments"

      index :read
      get :read
      post :create
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :flagged, :boolean, default: false, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :post, Playground.Blog.Post, public?: true, attribute_writable?: true, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy, create: [:body, :flagged, :post_id], update: [:body, :flagged]]
  end

  pub_sub do
    module PlaygroundWeb.Endpoint
    prefix "comment"
    publish_all :create, ["changed"]
    publish_all :update, ["changed"]
    publish_all :destroy, ["changed"]
  end
end
