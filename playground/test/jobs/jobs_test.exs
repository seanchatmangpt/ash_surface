defmodule AshShadcnJobsTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: Playground.Repo
  import Phoenix.ConnTest
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Jobs.Digest
  @res "Playground.Jobs.Digest"

  setup_all do
    case Process.whereis(Playground.Jobs.Supervisor) do
      nil -> start_supervised!(Playground.Jobs.Supervisor)
      _ -> :ok
    end

    :ok
  end

  setup do
    Ash.bulk_destroy!(Ash.read!(Digest), :destroy, %{}, authorize?: false, return_errors?: true)
    Playground.Repo.delete_all(Oban.Job)
    :ok
  end

  defp get_api(path, params \\ %{}), do: build_conn() |> get("/admin/api" <> path, params) |> json_response(200)
  defp post_api(path), do: build_conn() |> post("/admin/api" <> path)

  test "triggers endpoint lists the trigger and scheduled action" do
    %{"triggers" => ts} = get_api("/jobs/triggers")
    t = Enum.find(ts, &(&1["name"] == "archive_stale"))
    assert %{"kind" => "trigger", "resource" => @res, "action" => "archive", "queue" => "default",
             "scheduler_cron" => "*/5 * * * *", "state" => "active"} = t
    s = Enum.find(ts, &(&1["name"] == "heartbeat"))
    assert %{"kind" => "scheduled_action", "action" => "heartbeat", "scheduler_cron" => "0 * * * *"} = s
  end

  test "run trigger for a record enqueues a job; draining archives the record" do
    stale = Ash.create!(Digest, %{title: "old", age_days: 40}, authorize?: false)
    fresh = Ash.create!(Digest, %{title: "new", age_days: 1}, authorize?: false)

    %{"job" => %{"id" => id, "state" => "available", "queue" => "default"}} =
      post_api("/jobs/triggers/#{@res}/archive_stale/run?id=#{stale.id}") |> json_response(200)

    assert is_integer(id)
    assert %{"jobs" => [%{"id" => ^id}], "counts" => %{"available" => 1}} = get_api("/jobs", %{state: "available"})

    assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :default)
    assert Ash.get!(Digest, stale.id, authorize?: false).status == :archived
    assert Ash.get!(Digest, fresh.id, authorize?: false).status == :draft

    assert %{"jobs" => [%{"state" => "completed"}], "total" => 1, "counts" => %{"completed" => 1}} =
             get_api("/jobs", %{state: "completed"})
  end

  test "run without id schedules the scheduler, which fans out to matching records only" do
    stale = Ash.create!(Digest, %{title: "old2", age_days: 99}, authorize?: false)
    fresh = Ash.create!(Digest, %{title: "new2", age_days: 0}, authorize?: false)

    assert %{"job" => %{"worker" => w}} = post_api("/jobs/triggers/#{@res}/archive_stale/run") |> json_response(200)
    assert w =~ "Scheduler.ArchiveStale"

    assert %{failure: 0} = Oban.drain_queue(queue: :default, with_recursion: true)
    assert Ash.get!(Digest, stale.id, authorize?: false).status == :archived
    assert Ash.get!(Digest, fresh.id, authorize?: false).status == :draft
  end

  test "scheduled action run creates a heartbeat record" do
    post_api("/jobs/triggers/#{@res}/heartbeat/run") |> json_response(200)
    assert %{failure: 0, success: 1} = Oban.drain_queue(queue: :default)
    assert Enum.any?(Ash.read!(Digest, authorize?: false), &(&1.title == "heartbeat"))
  end

  test "cancel and retry change job state; filters and pagination apply" do
    for i <- 1..3 do
      r = Ash.create!(Digest, %{title: "d#{i}", age_days: 50}, authorize?: false)
      post_api("/jobs/triggers/#{@res}/archive_stale/run?id=#{r.id}") |> json_response(200)
    end

    %{"jobs" => [%{"id" => id}], "total" => 3, "page" => 2} = get_api("/jobs", %{per_page: 1, page: 2})
    assert %{"job" => %{"state" => "cancelled"}} = post_api("/jobs/#{id}/cancel") |> json_response(200)
    assert %{"total" => 1} = get_api("/jobs", %{state: "cancelled"})
    assert %{"job" => %{"state" => "available"}} = post_api("/jobs/#{id}/retry") |> json_response(200)
    assert %{"total" => 0} = get_api("/jobs", %{queue: "nope"})
    assert post_api("/jobs/999999/cancel").status == 404
  end

  test "unknown trigger/resource is 404" do
    assert post_api("/jobs/triggers/#{@res}/nope/run").status == 404
    assert post_api("/jobs/triggers/Nope/archive_stale/run").status == 404
  end
end
