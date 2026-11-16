defmodule AshShadcn.Ide.Runner do
  @moduledoc "Runs one Ash action via AshShadcn.Data and renders a terminal transcript."
  alias AshShadcn.Data
  alias Ash.Resource.Info

  def run(resource, params, ctx) do
    started = System.monotonic_time(:microsecond)
    {status, lines, result} = execute(resource, params, ctx)
    ms = div(System.monotonic_time(:microsecond) - started, 1000)

    %{
      command: command(resource, params),
      status: status,
      duration_ms: ms,
      lines: lines,
      result: result
    }
  end

  def command(resource, params) do
    name = resource |> Module.split() |> List.last()
    args = params["params"] || %{}
    id = if params["id"], do: [{"id", params["id"]}], else: []
    kv = Enum.map_join(id ++ Enum.sort(Map.to_list(args)), ", ", fn {k, v} -> "#{k}: #{Jason.encode!(v)}" end)
    "#{name}.#{params["action"] || "?"}(#{kv})"
  end

  defp execute(resource, params, ctx) do
    act = Info.actions(resource) |> Enum.find(&(to_string(&1.name) == params["action"]))

    case act && act.type do
      nil -> {"error", ["** (ArgumentError) unknown action #{inspect(params["action"])}"], nil}
      :read -> read(resource, params, ctx)
      :action -> finish(Data.run_generic(resource, params, ctx), :generic)
      _ -> finish(Data.submit(resource, params, ctx), :form)
    end
  rescue
    e -> {"error", ["** (#{inspect(e.__struct__)}) #{Exception.message(e)}"], nil}
  end

  defp read(resource, params, ctx) do
    finish(Data.read(resource, Map.merge(params["params"] || %{}, %{"action" => params["action"], "limit" => params["limit"] || "25"}), ctx), :read)
  end

  defp finish({:ok, %{errors: [_ | _] = errs}}, :form),
    do: {"error", Enum.map(errs, fn e -> "** #{if e.field != "", do: e.field <> ": ", else: ""}#{e.message}" end), nil}

  defp finish({:ok, %{record: rec}}, :form), do: {"ok", ["{:ok, #{summary(rec)}}"], rec}
  defp finish({:ok, %{records: recs} = body}, :read), do: {"ok", ["{:ok, #{length(recs)} of #{body.count} record(s)}"], recs}
  defp finish({:ok, %{result: r}}, :generic), do: {"ok", ["{:ok, #{inspect(r)}}"], r}
  defp finish({:error, e}, _), do: {"error", ["** #{Data.error_body(e).message |> String.split("\n") |> hd()}"], nil}

  defp summary(nil), do: "nil"
  defp summary(rec), do: rec |> Map.take(["id", "title", "name"]) |> inspect()
end
