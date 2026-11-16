defmodule AshShadcn.HistoryTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Blog.Author
  alias Playground.Editorial.Article

  @res "Playground.Editorial.Article"

  setup do
    actor =
      Ash.create!(Author, %{name: "Hist", email: "h#{System.unique_integer([:positive])}@x.io", role: :admin},
        authorize?: false
      )

    %{actor: actor}
  end

  defp get_api(path, params \\ %{}), do: build_conn() |> get("/admin/api" <> path, params)
  defp post_api(path, body), do: build_conn() |> post("/admin/api" <> path, body)

  defp new_article(actor, attrs \\ %{title: "T1", body: "B1"}) do
    Ash.create!(Article, attrs, actor: actor)
  end

  test "create/update/destroy produce versions with correct diffs and actor", %{actor: actor} do
    a = new_article(actor)
    a = Ash.update!(a, %{title: "T2"}, actor: actor)
    Ash.destroy!(a, actor: actor)

    %{"versions" => versions, "count" => 3} =
      get_api("/resources/#{@res}/records/#{a.id}/versions") |> json_response(200)

    assert Enum.map(versions, & &1["action_type"]) |> Enum.sort() == ["create", "destroy", "update"]
    assert Enum.all?(versions, &(&1["actor_id"] == actor.id))
    assert Enum.all?(versions, &is_binary(&1["inserted_at"]))

    update = Enum.find(versions, &(&1["action_type"] == "update"))
    assert update["action"] == "update"
    title = Enum.find(update["diff"], &(&1["field"] == "title"))
    assert %{"from" => "T1", "to" => "T2"} = title
    refute Enum.any?(update["diff"], &(&1["field"] == "body" and not &1["unchanged"]))

    create = Enum.find(versions, &(&1["action_type"] == "create"))
    assert %{"to" => "T1"} = Enum.find(create["diff"], &(&1["field"] == "title"))
  end

  test "archived record is hidden from normal read, listed in archived, and restorable", %{actor: actor} do
    a = new_article(actor, %{title: "Gone", body: "x"})
    Ash.destroy!(a, actor: actor)

    refute Enum.any?(Ash.read!(Article), &(&1.id == a.id))

    %{"records" => recs} =
      get_api("/resources/#{@res}/records") |> json_response(200)

    refute Enum.any?(recs, &(&1["id"] == a.id))

    %{"records" => archived} = get_api("/resources/#{@res}/archived") |> json_response(200)
    assert row = Enum.find(archived, &(&1["id"] == a.id))
    assert row["title"] == "Gone"
    assert is_binary(row["archived_at"])

    assert %{"record" => %{"id" => id}} =
             post_api("/resources/#{@res}/archived/#{a.id}/restore", %{actor_id: actor.id}) |> json_response(200)

    assert id == a.id
    assert Enum.any?(Ash.read!(Article), &(&1.id == a.id))
    %{"records" => after_restore} = get_api("/resources/#{@res}/archived") |> json_response(200)
    refute Enum.any?(after_restore, &(&1["id"] == a.id))
  end

  test "state machine: valid transitions advance, invalid is rejected", %{actor: actor} do
    a = new_article(actor)
    assert a.state == :draft
    assert {:error, %Ash.Error.Invalid{}} = Ash.update(a, %{}, action: :publish, actor: actor)

    a = Ash.update!(a, %{}, action: :submit, actor: actor)
    assert a.state == :review
    a = Ash.update!(a, %{}, action: :publish, actor: actor)
    assert a.state == :published

    # via the existing admin submit endpoint (AshPhoenix.Form)
    resp =
      post_api("/resources/#{@res}/submit", %{"action" => "retire", "id" => a.id, "params" => %{}})
      |> json_response(200)

    assert resp["errors"] == []
    assert resp["record"]["state"] == "retired"

    bad =
      post_api("/resources/#{@res}/submit", %{"action" => "submit", "id" => a.id, "params" => %{}})
      |> json_response(200)

    assert bad["errors"] != []
    assert Ash.get!(Article, a.id).state == :retired
  end

  test "state machine graph JSON matches the resource DSL" do
    body = get_api("/resources/#{@res}/state_machine") |> json_response(200)

    dsl =
      for t <- AshStateMachine.Info.state_machine_transitions(Article),
          from <- List.wrap(t.from),
          to <- List.wrap(t.to),
          do: {to_string(t.action), to_string(from), to_string(to)}

    json = for %{"action" => a, "from" => f, "to" => t} <- body["transitions"], do: {a, f, t}
    assert Enum.sort(json) == Enum.sort(dsl)
    assert Enum.sort(body["states"]) == ~w(draft published retired review)
    assert body["initial_states"] == ["draft"]
    assert body["state_attribute"] == "state"
    assert body["mermaid"] =~ "stateDiagram-v2"
    assert body["mermaid"] =~ "draft --> review: submit"
  end

  test "non-applicable resources answer 404 not_applicable" do
    for p <- ["/resources/Playground.Blog.Post/state_machine", "/resources/Playground.Blog.Post/archived"] do
      assert %{"error" => "not_applicable"} = get_api(p) |> json_response(404)
    end

    id = Ecto.UUID.generate()

    assert %{"error" => "not_applicable"} =
             get_api("/resources/Playground.Blog.Post/records/#{id}/versions") |> json_response(404)
  end
end
