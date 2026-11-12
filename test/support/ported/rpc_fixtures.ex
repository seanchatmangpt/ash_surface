defmodule AshSurface.Ported.RpcFixtures do
  @moduledoc """
  Hand-built real Ash structs (no data layer, no mocks) used as already-materialized action
  results fed to `AshSurface.Ported.Rpc.run/3`. `struct/2` over the fixture resources keeps
  unloaded fields as `%Ash.NotLoaded{}`, exactly as an action result carries them.
  """
  alias AshSurface.Ported.{Todo, TodoComment, User}

  @user_id "11111111-1111-1111-1111-111111111111"
  @todo_id "22222222-2222-2222-2222-222222222222"
  @comment_id "33333333-3333-3333-3333-333333333333"

  def user_id, do: @user_id
  def todo_id, do: @todo_id
  def comment_id, do: @comment_id

  def user(attrs \\ []),
    do:
      struct(
        User,
        Keyword.merge(
          [id: @user_id, name: "John Doe", email: "john@example.com", active: true],
          attrs
        )
      )

  def todo(attrs \\ []),
    do:
      struct(
        Todo,
        Keyword.merge(
          [
            id: @todo_id,
            title: "Test Todo",
            completed: false,
            description: "A description",
            priority: :medium,
            user_id: @user_id,
            tags: []
          ],
          attrs
        )
      )

  def comment(attrs \\ []),
    do:
      struct(
        TodoComment,
        Keyword.merge(
          [
            id: @comment_id,
            content: "First comment",
            author_name: "John Doe",
            todo_id: @todo_id,
            user_id: @user_id,
            rating: 5,
            is_helpful: true
          ],
          attrs
        )
      )
end
