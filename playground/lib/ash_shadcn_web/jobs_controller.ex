defmodule AshShadcnWeb.JobsController do
  @moduledoc "AshOban triggers / scheduled actions and Oban.Job rows for the admin Jobs page."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn
  import Ecto.Query

  alias Playground.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  def triggers(conn, _), do: json(conn, %{triggers: Enum.flat_map(resources(), &describe/1)})

  def index(conn, params) do
    page = max(int(params["page"], 1), 1)
    per = params["per_page"] |> int(20) |> max(1) |> min(100)

    base =
      Oban.Job
      |> filter(:state, params["state"])
      |> filter(:queue, params["queue"])
      |> filter(:worker, params["worker"])

    total = Repo.aggregate(base, :count)

    rows =
      base
      |> order_by([j], desc: j.id)
      |> limit(^per)
      |> offset(^((page - 1) * per))
      |> Repo.all()
      |> Enum.map(&job/1)

    counts = Oban.Job |> group_by([j], j.state) |> select([j], {j.state, count(j.id)}) |> Repo.all() |> Map.new()

    json(conn, %{
      jobs: rows,
      page: page,
      per_page: per,
      total: total,
      counts: Map.new(@states, &{&1, Map.get(counts, &1, 0)})
    })
  end

  def run_trigger(conn, %{"resource" => r, "name" => n} = params) do
    with {:ok, resource} <- find_resource(r),
         {:ok, trig} <- find_trigger(resource, n),
         {:ok, job} <- enqueue(resource, trig, params["id"]) do
      json(conn, %{job: job(job)})
    else
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "not_found", message: "unknown resource, trigger or record"})
      {:error, e} -> conn |> put_status(422) |> json(%{error: "failed", message: inspect(e)})
    end
  end

  def cancel(conn, %{"id" => id}), do: mutate(conn, id, &Oban.cancel_job/1)

  def retry(conn, %{"id" => id}), do: mutate(conn, id, &Oban.retry_job/1)

  defp mutate(conn, id, fun) do
    case Repo.get(Oban.Job, int(id, 0)) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found", message: "no such job"})

      %{id: jid} ->
        case fun.(jid) do
          :ok -> json(conn, %{job: job(Repo.get!(Oban.Job, jid))})
          {:ok, _} -> json(conn, %{job: job(Repo.get!(Oban.Job, jid))})
          {:error, e} -> conn |> put_status(422) |> json(%{error: "failed", message: inspect(e)})
        end
    end
  end

  defp enqueue(resource, trig, nil), do: {:ok, AshOban.schedule(resource, trig)}
  defp enqueue(resource, %AshOban.Trigger{} = trig, id) when is_binary(id) do
    case Ash.get(resource, id, authorize?: false) do
      {:ok, %{} = rec} -> {:ok, AshOban.run_trigger(rec, trig)}
      _ -> {:error, :not_found}
    end
  end
  defp enqueue(resource, trig, _id), do: {:ok, AshOban.schedule(resource, trig)}

  defp resources do
    (AshShadcn.domains() ++ [Playground.Jobs])
    |> Enum.uniq()
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.filter(&(Code.ensure_loaded?(&1) and AshOban in Spark.extensions(&1)))
    |> Enum.uniq()
  end

  defp find_resource(name), do: Enum.find_value(resources(), {:error, :not_found}, &(inspect(&1) == name && {:ok, &1}))

  defp find_trigger(resource, name) do
    resource
    |> AshOban.Info.oban_triggers_and_scheduled_actions()
    |> Enum.find(&(Atom.to_string(&1.name) == name))
    |> case do
      nil -> {:error, :not_found}
      t -> {:ok, t}
    end
  end

  defp describe(resource) do
    for t <- AshOban.Info.oban_triggers_and_scheduled_actions(resource) do
      {kind, cron, worker, sched} =
        case t do
          %AshOban.Trigger{} -> {"trigger", t.scheduler_cron, t.worker, t.scheduler}
          %AshOban.Schedule{} -> {"scheduled_action", t.cron, t.worker, nil}
        end

      %{
        name: t.name,
        kind: kind,
        resource: inspect(resource),
        action: t.action,
        queue: t.queue,
        scheduler_cron: cron,
        state: t.state,
        worker: inspect(worker),
        scheduler: sched && inspect(sched),
        where: Map.get(t, :where) && inspect(t.where)
      }
    end
  end

  defp filter(q, _f, v) when v in [nil, ""], do: q
  defp filter(q, :state, v), do: where(q, [j], j.state == ^v)
  defp filter(q, :queue, v), do: where(q, [j], j.queue == ^v)
  defp filter(q, :worker, v), do: where(q, [j], j.worker == ^v)

  defp job(j) do
    %{
      id: j.id,
      state: j.state,
      queue: j.queue,
      worker: j.worker,
      attempt: j.attempt,
      max_attempts: j.max_attempts,
      args: j.args,
      errors: Enum.map(j.errors || [], &(&1["error"] || inspect(&1))),
      inserted_at: j.inserted_at,
      scheduled_at: j.scheduled_at,
      attempted_at: j.attempted_at,
      completed_at: j.completed_at
    }
  end

  defp int(nil, d), do: d
  defp int(v, _) when is_integer(v), do: v
  defp int(v, d) do
    case Integer.parse(to_string(v)) do
      {i, _} -> i
      _ -> d
    end
  end
end
