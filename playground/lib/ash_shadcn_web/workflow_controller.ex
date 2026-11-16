defmodule AshShadcnWeb.WorkflowController do
  @moduledoc "JSON API for Ash.Reactor workflow introspection and execution."
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias AshShadcn.Workflow

  def index(conn, _), do: json(conn, %{workflows: Enum.map(Workflow.modules(), &Workflow.summary/1)})

  def graph(conn, %{"name" => name}) do
    with_workflow(conn, name, fn mod -> json(conn, %{workflow: Workflow.summary(mod), graph: Workflow.graph(mod)}) end)
  end

  def run(conn, %{"name" => name} = params) do
    with_workflow(conn, name, fn mod ->
      inputs =
        (params["inputs"] || %{})
        |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
        |> Map.new()

      ctx = [
        actor: AshShadcn.load_actor(params["actor_id"]),
        tenant: blank_to_nil(params["tenant"]),
        authorize?: params["authorize"] not in ["false", false]
      ]

      result = Workflow.run(mod, inputs, ctx)
      conn |> put_status(if(result.status == "ok", do: 200, else: 422)) |> json(sanitize(result))
    end)
  end

  defp with_workflow(conn, name, fun) do
    case Workflow.fetch(name) do
      {:ok, mod} -> fun.(mod)
      _ -> conn |> put_status(404) |> json(%{error: "not_found", message: "unknown workflow #{name}"})
    end
  end

  defp sanitize(%{result: nil} = r), do: r
  defp sanitize(%{result: res} = r), do: %{r | result: to_json(res)}

  defp to_json(%{__struct__: _} = s) do
    if is_struct(s, DateTime) or is_struct(s, NaiveDateTime), do: s, else: s |> Map.from_struct() |> Map.drop([:__meta__, :__metadata__, :aggregates, :calculations]) |> to_json()
  end

  defp to_json(m) when is_map(m), do: Map.new(m, fn {k, v} -> {k, to_json(v)} end)
  defp to_json(l) when is_list(l), do: Enum.map(l, &to_json/1)
  defp to_json(%Ash.NotLoaded{}), do: nil
  defp to_json(v) when is_atom(v) or is_binary(v) or is_number(v), do: v
  defp to_json(v), do: inspect(v)

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v
end
