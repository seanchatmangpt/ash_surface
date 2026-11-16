defmodule Playground.Blog do
  @moduledoc "Demo Ash domain browsed by the shadcn admin."
  use Ash.Domain, otp_app: :playground, extensions: [AshAi, AshJsonApi.Domain]

  json_api do
  end

  # lane:ai — tools exposed to the chat agent (policies still apply via the request actor)
  tools do
    tool :list_posts, Playground.Blog.Post, :read, description: "List blog posts. Supports filter, sort, limit."
    tool :create_post, Playground.Blog.Post, :create, description: "Create a blog post (needs title; actor must be allowed)."
    tool :publish_post, Playground.Blog.Post, :publish, description: "Publish a post by id."
    tool :list_comments, Playground.Blog.Comment, :read, description: "List comments."
    tool :list_authors, Playground.Blog.Author, :read, description: "List authors."
  end

  resources do
    resource Playground.Blog.Author
    resource Playground.Blog.Post
    resource Playground.Blog.Comment
  end
end
