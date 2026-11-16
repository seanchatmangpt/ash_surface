defmodule AshShadcn.History do
  @moduledoc """
  History lane core: AshPaperTrail version rows, AshStateMachine graph and AshArchival
  archived-record reads/restores, all derived from the resource's own DSL.
  """
  require Ash.Query
  alias Ash.Resource.Info
  alias AshShadcn.Data

  # -- paper trail -------------------------------------------------------------

  def paper_trail?(resource), do: AshPaperTrail.Resource in extensions(resource)
  def archival?(resource), do: AshArchival.Resource in extensions(resource)
  def state_machine?(resource), do: AshStateMachine in extensions(resource)

  defp extensions(resource), do: Spark.extensions(resource)

  @doc "Version rows (newest first) for one record: action, field diff, actor, timestamp."
  def versions(resource, id, ctx) do
    if paper_trail?(resource) do
      version = AshPaperTrail.Resource.Info.version_resource(resource)

      version
      |> Ash.Query.filter(version_source_id == ^id)
      |> Ash.Query.sort(version_inserted_at: :desc, id: :desc)
      |> Ash.read(authorize?: false, tenant: ctx[:tenant])
      |> case do
        {:ok, rows} -> {:ok, %{versions: Enum.map(rows, &version_row(resource, &1)), count: length(rows)}}
        {:error, e} -> {:error, e}
      end
    else
      {:error, :not_applicable}
    end
  end

  defp version_row(resource, row) do
    actor_keys = for b <- AshPaperTrail.Resource.Info.belongs_to_actor(resource), do: :"#{b.name}_id"
    changes = Data.serialize(row.changes || %{})

    %{
      id: row.id,
      action_type: Data.serialize(row.version_action_type),
      action: Data.serialize(Map.get(row, :version_action_name) || row.version_action_type),
      changes: changes,
      diff: diff(changes),
      actor_id: Enum.find_value(actor_keys, &Map.get(row, &1)),
      inserted_at: Data.serialize(row.version_inserted_at)
    }
  end

  # full_diff stores `%{field => %{"from" => a, "to" => b}}`; snapshot/changes_only store raw values.
  defp diff(changes) do
    for {field, v} <- Enum.sort(changes) do
      case v do
        %{"from" => from, "to" => to} -> %{field: field, from: from, to: to}
        %{"to" => to} -> %{field: field, from: nil, to: to}
        %{"unchanged" => value} -> %{field: field, from: value, to: value, unchanged: true}
        other -> %{field: field, from: nil, to: other}
      end
    end
  end

  # -- state machine -----------------------------------------------------------

  @doc "States, initial states and transitions straight from the DSL, plus mermaid text."
  def state_machine(resource) do
    if state_machine?(resource) do
      transitions =
        for t <- AshStateMachine.Info.state_machine_transitions(resource),
            from <- List.wrap(t.from),
            to <- List.wrap(t.to) do
          %{action: to_string(t.action), from: to_string(from), to: to_string(to)}
        end

      {:ok,
       %{
         state_attribute: to_string(AshStateMachine.Info.state_machine_state_attribute!(resource)),
         states: Enum.map(AshStateMachine.Info.state_machine_all_states(resource), &to_string/1),
         initial_states: Enum.map(AshStateMachine.Info.state_machine_initial_states!(resource), &to_string/1),
         transitions: transitions,
         mermaid: AshStateMachine.Charts.mermaid_state_diagram(resource)
       }}
    else
      {:error, :not_applicable}
    end
  end

  # -- archival ----------------------------------------------------------------

  def archived(resource, ctx) do
    with {:ok, action} <- archive_read(resource) do
      attr = AshArchival.Resource.Info.archive_attribute!(resource)

      resource
      |> Ash.Query.for_read(action, %{}, take(ctx))
      |> Ash.Query.filter(not is_nil(^Ash.Expr.ref(attr)))
      |> Ash.read(take(ctx))
      |> case do
        {:ok, rows} -> {:ok, %{records: Enum.map(rows, &archived_record(&1, attr)), count: length(rows)}}
        {:error, e} -> {:error, e}
      end
    end
  end

  def restore(resource, id, ctx) do
    with {:ok, read} <- archive_read(resource),
         {:ok, act} <- restore_action(resource),
         {:ok, rec} <- fetch(resource, read, id, ctx),
         {:ok, updated} <- rec |> Ash.Changeset.for_update(act, %{}, take(ctx)) |> Ash.update(take(ctx)) do
      {:ok, %{record: Data.record(updated)}}
    end
  end

  defp fetch(resource, read, id, ctx) do
    resource
    |> Ash.Query.for_read(read, %{}, take(ctx))
    |> Ash.Query.do_filter([{hd(Info.primary_key(resource)), id}])
    |> Ash.read_one(take(ctx))
    |> case do
      {:ok, nil} -> {:error, :not_found}
      other -> other
    end
  end

  defp archive_read(resource) do
    with true <- archival?(resource),
         [action | _] <- AshArchival.Resource.Info.archive_exclude_read_actions!(resource) do
      {:ok, action}
    else
      _ -> {:error, :not_applicable}
    end
  end

  defp restore_action(resource) do
    case Enum.find(Info.actions(resource), &(&1.type == :update and &1.name == :restore)) do
      nil -> {:error, :not_applicable}
      a -> {:ok, a.name}
    end
  end

  defp archived_record(rec, attr) do
    Data.record(rec) |> Map.put("archived_at", Data.serialize(Map.get(rec, attr)))
  end

  defp take(ctx), do: Keyword.take(ctx, [:actor, :tenant, :authorize?])
end
