defmodule Playground.Workflows.PublishPostWorkflow do
  @moduledoc """
  Publish a post: load -> validate -> publish -> comment -> audit. The audit step can be
  forced to fail (`fail_at: "audit"`), which compensates (undoes) the comment and the publish.
  """
  use Ash.Reactor

  ash do
    default_domain Playground.Blog
  end

  middlewares do
    middleware AshShadcn.Workflow.Recorder
  end

  input :post_id
  input :comment
  input :fail_at

  step :load_post, Playground.Workflows.Steps.LoadPost do
    argument :post_id, input(:post_id)
  end

  step :validate, Playground.Workflows.Steps.ValidatePost do
    argument :post, result(:load_post)
  end

  step :publish, Playground.Workflows.Steps.PublishPost do
    argument :post, result(:validate)
  end

  step :add_comment, Playground.Workflows.Steps.AddComment do
    argument :post, result(:publish)
    argument :comment, input(:comment)
  end

  step :audit, Playground.Workflows.Steps.Audit do
    argument :post, result(:publish)
    argument :comment, result(:add_comment)
    argument :fail_at, input(:fail_at)
  end

  return :audit

  def meta do
    %{
      title: "Publish post",
      description: "Load, validate, publish, comment and audit a post; failures compensate.",
      inputs: [
        %{name: "post_id", label: "Post ID", type: "string", default: ""},
        %{name: "comment", label: "Comment", type: "string", default: "Published!"},
        %{name: "fail_at", label: "Fail at step (audit)", type: "string", default: ""}
      ]
    }
  end
end
