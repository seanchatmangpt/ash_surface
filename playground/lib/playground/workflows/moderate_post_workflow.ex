defmodule Playground.Workflows.ModeratePostWorkflow do
  @moduledoc """
  Branching/parallel example: two independent checks run in parallel after loading the post,
  join in `decide`, which drives `apply_decision`. A native Ash.Reactor `create` records a
  moderation note at the end.
  """
  use Ash.Reactor

  ash do
    default_domain Playground.Blog
  end

  middlewares do
    middleware AshShadcn.Workflow.Recorder
  end

  input :post_id

  step :load_post, Playground.Workflows.Steps.LoadPost do
    argument :post_id, input(:post_id)
  end

  step :check_length, Playground.Workflows.Steps.CheckLength do
    argument :post, result(:load_post)
  end

  step :check_title, Playground.Workflows.Steps.CheckTitle do
    argument :post, result(:load_post)
  end

  step :decide, Playground.Workflows.Steps.Decide do
    argument :length, result(:check_length)
    argument :title, result(:check_title)
  end

  step :apply_decision, Playground.Workflows.Steps.ApplyDecision do
    argument :post, result(:load_post)
    argument :decision, result(:decide)
  end

  create :record_note, Playground.Blog.Comment, :create do
    inputs %{
      body: value("Moderation decision recorded"),
      post_id: input(:post_id)
    }

    wait_for :apply_decision
  end

  return :record_note

  def meta do
    %{
      title: "Moderate post",
      description: "Parallel length/title checks, decide, apply the decision and record a note.",
      inputs: [%{name: "post_id", label: "Post ID", type: "string", default: ""}]
    }
  end
end
