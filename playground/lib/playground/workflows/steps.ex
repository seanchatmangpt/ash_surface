defmodule Playground.Workflows.Steps do
  @moduledoc "Hand-written Reactor steps (with undo) over the demo Blog domain."

  alias Playground.Blog.{Comment, Post}

  defmodule LoadPost do
    @moduledoc false
    use Reactor.Step
    @impl true
    def run(%{post_id: id}, ctx, _), do: Ash.get(Post, id, actor: ctx[:actor], tenant: ctx[:tenant], authorize?: ctx[:authorize?] != false)
  end

  defmodule ValidatePost do
    @moduledoc false
    use Reactor.Step
    @impl true
    def run(%{post: post}, _ctx, _) do
      cond do
        post.status == :published -> {:error, "post is already published"}
        String.length(post.title || "") < 3 -> {:error, "title too short"}
        true -> {:ok, post}
      end
    end
  end

  defmodule PublishPost do
    @moduledoc "Publishes via :publish; undo restores status/published_at."
    use Reactor.Step
    @impl true
    def run(%{post: post}, ctx, _) do
      Ash.update(post, %{}, action: :publish, actor: ctx[:actor], tenant: ctx[:tenant], authorize?: ctx[:authorize?] != false)
    end

    @impl true
    def undo(published, %{post: original}, _ctx, _) do
      published
      |> Ash.Changeset.for_update(:update, %{}, authorize?: false)
      |> Ash.Changeset.force_change_attribute(:status, original.status)
      |> Ash.Changeset.force_change_attribute(:published_at, original.published_at)
      |> Ash.update(authorize?: false)
      |> case do
        {:ok, _} -> :ok
        {:error, e} -> {:error, e}
      end
    end
  end

  defmodule AddComment do
    @moduledoc "Creates a comment on the published post; undo destroys it."
    use Reactor.Step
    @impl true
    def run(%{post: post, comment: body}, ctx, _) do
      Ash.create(Comment, %{body: body, post_id: post.id}, actor: ctx[:actor], tenant: ctx[:tenant], authorize?: ctx[:authorize?] != false)
    end

    @impl true
    def undo(comment, _args, _ctx, _) do
      case Ash.destroy(comment, authorize?: false) do
        :ok -> :ok
        {:ok, _} -> :ok
        {:error, e} -> {:error, e}
      end
    end
  end

  defmodule Audit do
    @moduledoc "Final step; fails when the `fail_at` input is \"audit\" (drives compensation)."
    use Reactor.Step
    @impl true
    def run(%{fail_at: "audit"}, _ctx, _), do: {:error, "audit rejected the publication"}
    def run(%{post: post, comment: comment}, _ctx, _), do: {:ok, %{post_id: post.id, comment_id: comment.id, audited: true}}
  end

  defmodule CheckLength do
    @moduledoc false
    use Reactor.Step
    @impl true
    def run(%{post: post}, _ctx, _), do: {:ok, %{ok: String.length(post.body || "") >= 10, length: String.length(post.body || "")}}
  end

  defmodule CheckTitle do
    @moduledoc false
    use Reactor.Step
    @impl true
    def run(%{post: post}, _ctx, _), do: {:ok, %{ok: not String.contains?(String.downcase(post.title || ""), "spam")}}
  end

  defmodule Decide do
    @moduledoc false
    use Reactor.Step
    @impl true
    def run(%{length: l, title: t}, _ctx, _), do: {:ok, if(l.ok and t.ok, do: :published, else: :archived)}
  end

  defmodule ApplyDecision do
    @moduledoc "Applies the decision with :update (policy-checked); undo restores the old status."
    use Reactor.Step
    @impl true
    def run(%{post: post, decision: status}, ctx, _) do
      Ash.update(post, %{status: status}, action: :update, actor: ctx[:actor], tenant: ctx[:tenant], authorize?: ctx[:authorize?] != false)
    end

    @impl true
    def undo(updated, %{post: original}, _ctx, _) do
      with {:ok, _} <- Ash.update(updated, %{status: original.status}, action: :update, authorize?: false), do: :ok
    end
  end

end
