defmodule AshShadcnWeb.Realtime.Channel do
  @moduledoc """
  `admin:<ResourceModule>` channel. Join params: `%{"actor_id" => id}`. Join is refused unless the
  actor may read the resource. Feeds from `Ash.Notifier.PubSub` (topic `<prefix>:changed`, a plain
  Endpoint topic, so LiveViews may subscribe to the same topic) and pushes `"changed"` events.
  """
  use Phoenix.Channel

  @impl true
  def join("admin:" <> name, params, socket) do
    actor = AshShadcn.load_actor(params["actor_id"])

    with {:ok, res} <- resolve(name),
         {:ok, prefix} <- prefix(res),
         true <- Ash.can?({res, :read}, actor) || {:error, %{reason: "forbidden"}} do
      :ok = PlaygroundWeb.Endpoint.subscribe("#{prefix}:changed")
      {:ok, assign(socket, resource: res, actor: actor)}
    else
      {:error, %{} = e} -> {:error, e}
      _ -> {:error, %{reason: "forbidden"}}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: n}, socket) do
    push(socket, "changed", payload(socket.assigns.resource, event, n))
    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp resolve(name) do
    {:ok, AshShadcn.resource!(name)}
  rescue
    ArgumentError -> {:error, %{reason: "not_found"}}
  end

  defp prefix(res) do
    case Ash.Notifier.PubSub.Info.prefix(res) do
      nil -> {:error, %{reason: "no_realtime"}}
      p -> {:ok, p}
    end
  end

  defp payload(res, event, %Ash.Notifier.Notification{} = n) do
    data = n.data

    %{
      "resource" => inspect(res),
      "action" => to_string(n.action.name),
      "type" => to_string(n.action.type),
      "event" => to_string(event),
      "id" => data |> Map.get(:id) |> to_string(),
      "record" => record(res, data),
      "at" => DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp record(res, data) do
    for a <- Ash.Resource.Info.public_attributes(res), into: %{} do
      {to_string(a.name), json(Map.get(data, a.name))}
    end
  end

  defp json(v) when is_atom(v) and not is_nil(v) and not is_boolean(v), do: to_string(v)
  defp json(%DateTime{} = d), do: DateTime.to_iso8601(d)
  defp json(%Ash.CiString{} = s), do: to_string(s)
  defp json(v), do: v
end
