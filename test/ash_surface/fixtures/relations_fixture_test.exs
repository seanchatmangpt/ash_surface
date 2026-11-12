defmodule AshSurface.Fixtures.RelationsFixtureTest do
  use ExUnit.Case, async: true
  alias AshSurface.ZodFixtures.Relations, as: R

  test "Ash sees has_many, belongs_to and has_one" do
    assert %{type: :has_many, destination: R.Post} =
             Ash.Resource.Info.relationship(R.Author, :posts)

    assert %{type: :has_one, destination: R.Profile} =
             Ash.Resource.Info.relationship(R.Author, :profile)

    assert %{type: :belongs_to, destination: R.Author} =
             Ash.Resource.Info.relationship(R.Post, :author)

    assert %{type: :has_many, destination: R.Comment} =
             Ash.Resource.Info.relationship(R.Post, :comments)

    assert %{type: :belongs_to} = Ash.Resource.Info.relationship(R.Comment, :post)
  end

  test "ETS round trip across relationships" do
    author = Ash.create!(R.Author, %{name: "a"}, action: :create)
    post = Ash.create!(R.Post, %{title: "t", author_id: author.id}, action: :create)
    Ash.create!(R.Comment, %{body: "c", post_id: post.id}, action: :create)
    loaded = Ash.get!(R.Post, post.id, load: [:comments, :author])
    assert [%{body: "c"}] = loaded.comments
    assert loaded.author.name == "a"
  end
end
