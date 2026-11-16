defmodule AshShadcn.WorkflowTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias AshShadcn.Workflow
  alias Playground.Blog.{Author, Comment, Post}
  alias Playground.Workflows.{ModeratePostWorkflow, PublishPostWorkflow}

  setup do
    n = System.unique_integer([:positive])
    admin = Ash.create!(Author, %{name: "A", email: "wa#{n}@x.io", role: :admin}, authorize?: false)
    reader = Ash.create!(Author, %{name: "R", email: "wr#{n}@x.io", role: :reader}, authorize?: false)
    post = Ash.create!(Post, %{title: "Workflow post #{n}", body: "A long enough body here."}, authorize?: false)
    %{admin: admin, reader: reader, post: post}
  end

  defp comments(post), do: Ash.read!(Comment, authorize?: false) |> Enum.filter(&(&1.post_id == post.id))
  defp reload(post), do: Ash.get!(Post, post.id, authorize?: false)

  test "graph edges mirror step dependencies" do
    %{nodes: nodes, edges: edges} = Workflow.graph(PublishPostWorkflow)
    ids = MapSet.new(nodes, & &1.id)
    assert MapSet.subset?(MapSet.new(~w(load_post validate publish add_comment audit input:post_id)), ids)
    pairs = MapSet.new(edges, &{&1.source, &1.target})
    for e <- [{"input:post_id", "load_post"}, {"load_post", "validate"}, {"validate", "publish"}, {"publish", "add_comment"}, {"add_comment", "audit"}, {"publish", "audit"}] do
      assert e in pairs, "missing edge #{inspect(e)}"
    end
    refute {"validate", "audit"} in pairs
    assert Enum.find(nodes, &(&1.id == "publish")).undoable
    refute Enum.find(nodes, &(&1.id == "validate")).undoable

    %{edges: m} = Workflow.graph(ModeratePostWorkflow)
    mp = MapSet.new(m, &{&1.source, &1.target})
    assert {"load_post", "check_length"} in mp and {"load_post", "check_title"} in mp
    assert {"check_length", "decide"} in mp and {"check_title", "decide"} in mp
    assert {"decide", "apply_decision"} in mp
  end

  test "successful run records ok statuses and persists data", %{admin: admin, post: post} do
    r = Workflow.run(PublishPostWorkflow, %{post_id: post.id, comment: "hi", fail_at: ""}, actor: admin)
    assert r.status == "ok"
    assert Map.take(r.steps, [:load_post, :validate, :publish, :add_comment, :audit]) |> Map.values() |> Enum.uniq() == ["ok"]
    assert reload(post).status == :published
    assert [%{body: "hi"}] = comments(post)
  end

  test "failing step compensates: publish and comment are undone in the data layer", %{admin: admin, post: post} do
    r = Workflow.run(PublishPostWorkflow, %{post_id: post.id, comment: "gone", fail_at: "audit"}, actor: admin)
    assert r.status == "error"
    assert r.steps.audit == "error"
    assert r.steps.publish == "undone" and r.steps.add_comment == "undone"
    assert r.error =~ "audit rejected"
    assert reload(post).status == :draft
    assert reload(post).published_at == nil
    assert comments(post) == []
  end

  test "policy-denied actor fails the workflow at publish", %{reader: reader, post: post} do
    r = Workflow.run(PublishPostWorkflow, %{post_id: post.id, comment: "x", fail_at: ""}, actor: reader)
    assert r.status == "error"
    assert r.steps.publish == "error"
    assert r.steps.validate == "ok"
    refute Map.has_key?(r.steps, :add_comment)
    assert reload(post).status == :draft
  end

  test "branching workflow runs checks in parallel and records a note", %{admin: admin, post: post} do
    r = Workflow.run(ModeratePostWorkflow, %{post_id: post.id}, actor: admin)
    assert r.status == "ok"
    assert r.steps.check_length == "ok" and r.steps.check_title == "ok" and r.steps.decide == "ok"
    assert reload(post).status == :published
    assert Enum.any?(comments(post), &(&1.body == "Moderation decision recorded"))
  end

  describe "endpoints" do
    test "list and graph" do
      %{"workflows" => ws} = build_conn() |> get("/admin/api/workflows") |> json_response(200)
      assert Enum.any?(ws, &(&1["name"] == "PublishPostWorkflow" and &1["step_count"] == 5))
      %{"graph" => %{"nodes" => n, "edges" => e}} = build_conn() |> get("/admin/api/workflows/PublishPostWorkflow/graph") |> json_response(200)
      assert length(n) == 8 and Enum.any?(e, &(&1["source"] == "publish" and &1["target"] == "audit"))
      assert build_conn() |> get("/admin/api/workflows/Nope/graph") |> json_response(404)
    end

    test "run with actor, then policy-denied run", %{admin: admin, reader: reader, post: post} do
      body = fn actor -> %{"actor_id" => actor.id, "inputs" => %{"post_id" => post.id, "comment" => "c", "fail_at" => ""}} end
      ok = build_conn() |> post("/admin/api/workflows/PublishPostWorkflow/run", body.(reader)) |> json_response(422)
      assert ok["status"] == "error" and ok["steps"]["publish"] == "error"
      res = build_conn() |> post("/admin/api/workflows/PublishPostWorkflow/run", body.(admin)) |> json_response(200)
      assert res["status"] == "ok" and res["steps"]["audit"] == "ok"
      assert Enum.any?(res["events"], &(&1["step"] == "publish" and &1["status"] == "running"))
      assert reload(post).status == :published
    end
  end
end
