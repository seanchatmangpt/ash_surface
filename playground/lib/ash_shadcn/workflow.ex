defmodule AshShadcn.Workflow do
  @moduledoc """
  Reactor introspection + execution for the admin workflow canvas. Workflows are `Ash.Reactor`
  modules listed under `config :playground, :workflows`.
  """
  alias AshShadcn.Workflow.Recorder

  def modules, do: Application.get_env(:playground, :workflows, [])

  def name(mod), do: mod |> Module.split() |> List.last()

  def fetch(name) when is_binary(name) do
    case Enum.find(modules(), &(name(&1) == name or inspect(&1) == name)) do
      nil -> {:error, :not_found}
      mod -> {:ok, mod}
    end
  end

  def summary(mod) do
    meta = meta(mod)
    reactor = mod.reactor()

    %{
      name: name(mod),
      module: inspect(mod),
      title: meta[:title] || name(mod),
      description: meta[:description],
      inputs: meta[:inputs] || Enum.map(reactor.inputs, &%{name: to_string(&1.name), label: to_string(&1.name), type: "string", default: ""}),
      step_count: mod |> graph() |> Map.fetch!(:nodes) |> Enum.count(&(&1.type == "step"))
    }
  end

  defp meta(mod), do: if(function_exported?(mod, :meta, 0), do: mod.meta(), else: %{})

  @doc "Turns the Reactor's steps/arguments/dependencies into `%{nodes, edges}` JSON-ready maps."
  def graph(mod) do
    reactor = mod.reactor()
    {:ok, planned} = Reactor.Planner.plan(reactor)

    all_steps =
      planned.plan
      |> Multigraph.vertices()
      |> Enum.filter(&is_struct(&1, Reactor.Step))

    # Ash.Reactor expands native steps into helper steps named `{:__input__, parent, _}` etc.;
    # fold helpers into the user-declared step they belong to.
    declared = MapSet.new(for %{name: n} <- all_steps, is_atom(n), do: n)

    owner = fn
      n when is_atom(n) -> if MapSet.member?(declared, n), do: n
      {_, n, _} when is_atom(n) -> if MapSet.member?(declared, n), do: n
      {_, n} when is_atom(n) -> if MapSet.member?(declared, n), do: n
      _ -> nil
    end

    steps = Enum.filter(all_steps, &is_atom(&1.name))

    input_nodes =
      Enum.map(reactor.inputs, fn %{name: i} ->
        %{id: "input:#{i}", type: "input", label: to_string(i), kind: "input", description: "Workflow input"}
      end)

    step_nodes =
      steps
      |> Enum.sort_by(&to_string(&1.name))
      |> Enum.map(fn s ->
        %{
          id: to_string(s.name),
          type: "step",
          label: to_string(s.name),
          kind: impl_name(s.impl),
          description: s.description,
          undoable: undoable?(s),
          arguments: Enum.map(s.arguments, &argument_json/1),
          return: reactor.return == s.name
        }
      end)

    edges =
      all_steps
      |> Enum.flat_map(fn s ->
        target = owner.(s.name)

        for a <- s.arguments, target != nil, edge <- arg_edge(a, owner, target), do: edge
      end)
      |> Enum.uniq()
      |> Enum.map(fn {from, to, label} -> %{id: "#{from}->#{to}", source: from, target: to, label: label} end)
      |> Enum.uniq_by(& &1.id)

    %{nodes: input_nodes ++ step_nodes, edges: edges, return: to_string(reactor.return)}
  end

  defp arg_edge(%{name: arg, source: %Reactor.Template.Result{name: dep}}, owner, target) do
    case owner.(dep) do
      nil -> []
      ^target -> []
      from -> [{to_string(from), to_string(target), to_string(arg)}]
    end
  end

  defp arg_edge(%{name: arg, source: %Reactor.Template.Input{name: i}}, _owner, target),
    do: [{"input:#{i}", to_string(target), to_string(arg)}]

  defp arg_edge(_, _, _), do: []

  defp impl_name({mod, _opts}), do: inspect(mod) |> String.split(".") |> List.last()
  defp impl_name(mod) when is_atom(mod), do: inspect(mod) |> String.split(".") |> List.last()
  defp impl_name(_), do: "step"

  defp undoable?(%{impl: {mod, _}}), do: undoable_mod?(mod)
  defp undoable?(%{impl: mod}), do: undoable_mod?(mod)
  defp undoable_mod?(mod), do: is_atom(mod) and Code.ensure_loaded?(mod) and function_exported?(mod, :undo, 4)

  defp ref_str(r) when is_atom(r), do: to_string(r)
  defp ref_str(r), do: inspect(r)

  defp argument_json(%{name: n, source: %Reactor.Template.Result{name: r}}), do: %{name: n, from: "result", ref: ref_str(r)}
  defp argument_json(%{name: n, source: %Reactor.Template.Input{name: i}}), do: %{name: n, from: "input", ref: ref_str(i)}
  defp argument_json(%{name: n}), do: %{name: n, from: "value", ref: nil}

  @doc """
  Runs the workflow with `inputs` and ctx (`:actor`, `:tenant`, `:authorize?`), returning
  `%{status, events, steps, result, error}` where `steps` maps step -> final status.
  """
  def run(mod, inputs, ctx \\ []) do
    ref = make_ref()
    t0 = System.monotonic_time(:millisecond)

    context = %{
      actor: ctx[:actor],
      tenant: ctx[:tenant],
      authorize?: Keyword.get(ctx, :authorize?, true),
      workflow_recorder: {self(), ref}
    }

    outcome = Reactor.run(mod, inputs, context)
    events = drain(ref, t0, [])
    steps = Enum.reduce(events, %{}, fn e, acc -> Map.put(acc, e.step, e.status) end)
    errors = events |> Enum.filter(&Map.has_key?(&1, :error)) |> Map.new(&{&1.step, &1.error})

    case outcome do
      {:ok, result} ->
        %{status: "ok", events: events, steps: steps, errors: errors, result: result, error: nil}

      {:error, err} ->
        %{status: "error", events: events, steps: steps, errors: errors, result: nil, error: Recorder.format(err)}

      other ->
        %{status: "error", events: events, steps: steps, errors: errors, result: nil, error: inspect(other)}
    end
  end

  defp drain(ref, t0, acc) do
    receive do
      {:workflow_event, ^ref, e} -> drain(ref, t0, [%{e | at: e.at - t0} | acc])
    after
      0 -> acc |> Enum.reverse() |> Enum.sort_by(& &1.at)
    end
  end
end
