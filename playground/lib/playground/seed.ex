defmodule Playground.Seed do
  @moduledoc "Demo records so the admin has something to browse. Idempotent per boot (ETS)."
  alias Playground.Blog.{Author, Comment, Post}

  def run do
    opts = [authorize?: false]
    admin = Ash.create!(Author, %{name: "Ada Admin", email: "ada@example.com", role: :admin, bio: "Runs the place."}, opts)
    editor = Ash.create!(Author, %{name: "Ed Editor", email: "ed@example.com", role: :editor}, opts)
    _reader = Ash.create!(Author, %{name: "Rae Reader", email: "rae@example.com", role: :reader}, opts)

    for {title, status, author, pts} <- [
          {"Hello Ash", :published, admin, 120},
          {"Policies in practice", :draft, editor, 40},
          {"Zod meets Ash", :published, editor, 310},
          {"Notes on Reactor", :archived, admin, 5}
        ] do
      post =
        Ash.create!(Post, %{title: title, status: status, author_id: author.id, points: pts, tags: ["ash", "demo"], body: "Body of #{title}."}, opts)

      Ash.create!(Comment, %{body: "Nice post!", post_id: post.id}, opts)
    end

    :ok
  end
end
