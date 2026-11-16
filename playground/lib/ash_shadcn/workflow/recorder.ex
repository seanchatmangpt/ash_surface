defmodule AshShadcn.Workflow.Recorder do
  @moduledoc """
  Reactor middleware recording per-step lifecycle events. Events are sent to the pid in the
  reactor context key `:workflow_recorder` as `{:workflow_event, ref, event}`.
  """
  use Reactor.Middleware

  @impl true
  def event(event, step, ctx) do
    with {pid, ref} when is_pid(pid) <- ctx[:workflow_recorder],
         {:ok, status, extra} <- classify(event) do
      send(pid, {:workflow_event, ref, Map.merge(%{step: step_name(step), status: status, at: System.monotonic_time(:millisecond)}, extra)})
    end

    :ok
  end

  defp classify(:run_start), do: :skip
  defp classify({:run_start, _}), do: {:ok, "running", %{}}
  defp classify({:run_complete, _}), do: {:ok, "ok", %{}}
  defp classify({:run_error, err}), do: {:ok, "error", %{error: format(err)}}
  defp classify({:run_halt, _}), do: {:ok, "ok", %{}}
  defp classify(:undo_start), do: {:ok, "undoing", %{}}
  defp classify(:undo_complete), do: {:ok, "undone", %{}}
  defp classify({:undo_error, err}), do: {:ok, "error", %{error: "undo failed: " <> format(err)}}
  defp classify(_), do: :skip

  defp step_name(%{name: {:__reactor_stable_name__, name}}), do: name
  defp step_name(%{name: name}), do: name

  @doc false
  def format(errs) when is_list(errs), do: errs |> Enum.map(&format/1) |> Enum.join("; ")
  def format(%{__exception__: true} = e), do: Exception.message(e)
  def format(other), do: inspect(other)
end
