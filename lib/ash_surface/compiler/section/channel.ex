defmodule AshSurface.Compiler.Section.Channel do
  @moduledoc """
  Channel section: string-keyed discovery `"channels"` -> channel structs whose
  events carry Zod payload schemas (ash_typescript `typed_channel` parity,
  descriptor-only: no Spark channel DSL, no Phoenix interception).

  Input shape (the single discovery map, read once, never re-discovered):

      %{"channels" => [
        %{"name" => "Ticket", "topic" => "ticket:*",
          "events" => [%{"event" => "created", "payload" => %{"type" => %{"kind" => "map"}}}]}
      ]}

  Payload definitions are the `ZodType.fragment/1` definition shape. A missing
  (nil) payload renders `z.unknown()`; any other non-map payload is refused
  `{:error, {:non_map_payload, channel, event, payload}}`. Payload names are
  `identifier(event) <> "Payload"` (valid JS identifier). Two events of one channel
  with the same name and different schemas are refused
  `{:error, {:payload_name_conflict, name, schemas}}`; across channels such a clash is
  namespaced with the channel name. Event names repeat only across channels.
  """

  alias AshSurface.Compiler.{EmbeddedSchema, ZodType}

  # Resolved kinds Phoenix can push as a JSON object, plus kinds whose shape is
  # unknown (never refused). Used when an event carries a pre-resolved
  # `"returns_kind"`.
  @object_kinds ~w(map struct keyword tuple resource embedded_resource union typed_map typed_struct)
  @unknown_kinds ~w(term any unknown)

  defmodule Event do
    @moduledoc "One channel event with its Zod payload schema."
    @type t :: %__MODULE__{event: String.t(), payload_name: String.t(), zod: String.t()}
    defstruct [:event, :payload_name, :zod]
  end

  defstruct [:name, :topic, events: []]

  @type t :: %__MODULE__{name: String.t(), topic: String.t() | nil, events: [Event.t()]}

  @spec build(map(), keyword() | map()) :: {:ok, [t()]} | {:error, term()}
  def build(discovery, _opts \\ [])

  def build(discovery, opts) do
    with {:ok, built, _warnings} <- build_with_warnings(discovery, opts), do: {:ok, built}
  end

  @spec build_with_warnings(map(), keyword() | map()) ::
          {:ok, [t()], [term()]} | {:error, term()}
  def build_with_warnings(discovery, opts \\ [])

  def build_with_warnings(%{"channels" => channels} = discovery, _opts) when is_list(channels) do
    with {:ok, built} <- build_channels(channels),
         {:ok, built} <- check_conflicts(built) do
      carried = Map.get(discovery, "warnings") || []
      {:ok, built, Enum.uniq(carried ++ missing_returns(channels))}
    end
  end

  def build_with_warnings(%{} = _discovery, _opts), do: {:ok, [], []}
  def build_with_warnings(other, _opts), do: {:error, {:invalid_discovery, other}}

  defp missing_returns(channels) do
    for %{"name" => name} = c <- Enum.sort_by(channels, &Map.get(&1, "name")),
        %{"event" => ev} = e <- Enum.sort_by(Map.get(c, "events") || [], &Map.get(&1, "event")),
        is_nil(Map.get(e, "payload")),
        do: {:missing_returns, name, ev}
  end

  defp build_channels(channels) do
    channels
    |> Enum.sort_by(&Map.get(&1, "name"))
    |> Enum.reduce_while({:ok, []}, fn channel, {:ok, acc} ->
      case build_channel(channel) do
        {:ok, built} -> {:cont, {:ok, [built | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      err -> err
    end
  end

  defp build_channel(%{"name" => name} = channel) when is_binary(name) do
    events = Map.get(channel, "events") || []

    with :ok <- check_unique_events(name, events), do: build_events(name, channel, events)
  end

  defp build_channel(other), do: {:error, {:invalid_channel_entry, other}}

  defp check_unique_events(name, events) do
    events
    |> Enum.map(&Map.get(&1, "event"))
    |> Enum.frequencies()
    |> Enum.filter(fn {ev, n} -> is_binary(ev) and n > 1 end)
    |> Enum.sort()
    |> case do
      [] -> :ok
      [{ev, _} | _] -> {:error, {:duplicate_event, name, ev}}
    end
  end

  defp build_events(name, channel, events) do
    events
    |> Enum.sort_by(&Map.get(&1, "event"))
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case build_event(name, entry) do
        {:ok, ev} -> {:cont, {:ok, [ev | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} ->
        {:ok,
         %__MODULE__{name: name, topic: Map.get(channel, "topic"), events: Enum.reverse(acc)}}

      err ->
        err
    end
  end

  defp build_event(channel, %{"event" => event} = entry) when is_binary(event) do
    with :ok <- check_kind(channel, event, Map.get(entry, "returns_kind")) do
      case Map.get(entry, "payload") do
        nil ->
          {:ok, event_struct(event, "z.unknown()")}

        payload when is_map(payload) ->
          with {:ok, zod} <- render(payload), do: {:ok, event_struct(event, zod)}

        payload ->
          {:error, {:non_map_payload, channel, event, payload}}
      end
    end
  end

  defp build_event(_channel, other), do: {:error, {:invalid_event_entry, other}}

  defp check_kind(_channel, _event, nil), do: :ok

  defp check_kind(channel, event, kind) do
    k = to_string(kind)

    if k in @object_kinds or k in @unknown_kinds,
      do: :ok,
      else: {:error, {:non_object_payload, channel, event, k}}
  end

  defp render(payload) do
    if EmbeddedSchema.container?(payload) do
      EmbeddedSchema.render(payload)
    else
      {:ok, ZodType.fragment(payload)}
    end
  end

  defp event_struct(event, zod) do
    %Event{event: event, payload_name: identifier(event) <> "Payload", zod: zod}
  end

  @doc false
  # Deterministic valid-JS-identifier camel-casing: any non [A-Za-z0-9] run is a word
  # boundary; a leading digit gains an underscore.
  def identifier(text) do
    base =
      text
      |> String.split(~r/[^A-Za-z0-9]+/, trim: true)
      |> Enum.map_join(&Macro.camelize/1)

    case base do
      "" -> "Event"
      <<c, _::binary>> when c in ?0..?9 -> "_" <> base
      _ -> base
    end
  end

  # Same name + different shape inside one channel is refused. Across channels the
  # colliding events are namespaced by channel name (deterministic), then re-checked.
  defp check_conflicts(channels) do
    with {:ok, scoped} <- per_channel(channels) do
      {:ok, namespace_cross_channel(scoped)}
    end
  end

  defp per_channel(channels) do
    Enum.find_value(channels, {:ok, channels}, fn c ->
      case conflicts(c.events) do
        [] -> nil
        [{name, zods} | _] -> {:error, {:payload_name_conflict, name, zods}}
      end
    end)
  end

  defp namespace_cross_channel(channels) do
    clashing =
      channels
      |> Enum.flat_map(fn c -> Enum.map(c.events, &{&1.payload_name, &1.zod}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_, zods} -> zods |> Enum.uniq() |> length() > 1 end)
      |> Map.new(fn {name, _} -> {name, true} end)

    Enum.map(channels, fn c ->
      events =
        Enum.map(c.events, fn e ->
          if Map.has_key?(clashing, e.payload_name),
            do: %{e | payload_name: identifier(c.name) <> e.payload_name},
            else: e
        end)

      %{c | events: events}
    end)
  end

  defp conflicts(events) do
    events
    |> Enum.group_by(& &1.payload_name, & &1.zod)
    |> Enum.map(fn {name, zods} -> {name, zods |> Enum.uniq() |> Enum.sort()} end)
    |> Enum.filter(fn {_, zods} -> length(zods) > 1 end)
    |> Enum.sort()
  end
end
