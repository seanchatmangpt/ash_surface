defmodule AshSurface.Compiler.ChannelDiscovery do
  @moduledoc """
  Builds the string-keyed discovery map read by `Compiler.Section.Channel`
  from `Ash.Notifier.PubSub` publications (ash_typescript `typed_channel`
  parity, descriptor-only).

  `discover/2` input: a list of channel specs

      %{name: "Org", topic: "org:*",
        resources: [ResourceModule | {ResourceModule, ["event", ...]}]}

  A bare module takes every publication. Output:
  `{:ok, %{"channels" => [...], "warnings" => [...]}}` where each event is
  `%{"event", "payload" => definition | nil, "returns_kind" => kind | nil}`;
  payload types are resolved by `Ash.Info.Manifest.Generator.TypeResolver` and
  rendered into the `ZodType` definition shape (`type.kind`, `constraints`,
  `type.fields` / `type.items` / `type.values`).

  `verify/1` is pure over a discovery map and returns `{:ok, warnings}` or
  `{:error, {:duplicate_event, channel, event}}` /
  `{:error, {:non_object_payload, channel, event, kind}}`; `discover/2` also
  returns `{:error, {:event_not_found, resource, event}}`.
  Warnings: `{:non_public_publication, resource, event}`,
  `{:missing_returns, channel, event}`.
  """

  alias Ash.Info.Manifest.Generator.TypeResolver
  alias Ash.Info.Manifest.Type

  @object_kinds ~w(map struct keyword tuple resource embedded_resource union)
  @unknown_kinds ~w(term any unknown)
  @max_depth 8
  @constraint_drop ~w(fields items types instance_of match)a

  @spec discover([map() | keyword()], keyword()) :: {:ok, map()} | {:error, term()}
  def discover(channels, _opts \\ []) when is_list(channels) do
    channels
    |> Enum.reduce_while({:ok, [], []}, fn spec, {:ok, acc, warns} ->
      case discover_channel(spec) do
        {:ok, channel, w} -> {:cont, {:ok, [channel | acc], warns ++ w}}
        {:error, _} = e -> {:halt, e}
      end
    end)
    |> case do
      {:ok, acc, warns} ->
        discovery = %{"channels" => Enum.reverse(acc), "warnings" => warns}

        with {:ok, verify_warns} <- verify(discovery) do
          {:ok, %{discovery | "warnings" => Enum.uniq(warns ++ verify_warns)}}
        end

      e ->
        e
    end
  end

  @doc "Pure checks over a discovery map. See moduledoc."
  @spec verify(map()) :: {:ok, [term()]} | {:error, term()}
  def verify(%{"channels" => channels}) do
    with :ok <- unique_events(channels),
         :ok <- object_payloads(channels) do
      {:ok,
       for(
         c <- channels,
         e <- c["events"],
         is_nil(e["payload"]),
         do: {:missing_returns, c["name"], e["event"]}
       )}
    end
  end

  def verify(other), do: {:error, {:invalid_discovery, other}}

  # Event names are unique across all resources of one channel (ash_typescript
  # VerifyTypedChannel.verify_unique_event_names parity); other channels may reuse them.
  defp unique_events(channels) do
    Enum.find_value(channels, :ok, fn c ->
      c["events"]
      |> Enum.frequencies_by(& &1["event"])
      |> Enum.sort()
      |> Enum.find_value(fn {ev, n} ->
        if n > 1, do: {:error, {:duplicate_event, c["name"], ev}}
      end)
    end)
  end

  defp object_payloads(channels) do
    Enum.find_value(channels, :ok, fn c ->
      Enum.find_value(c["events"], fn e ->
        kind = e["returns_kind"]

        if is_nil(kind) or kind in @object_kinds or kind in @unknown_kinds,
          do: nil,
          else: {:error, {:non_object_payload, c["name"], e["event"], kind}}
      end)
    end)
  end

  defp discover_channel(spec) do
    catch_depth(fn -> do_discover_channel(spec) end)
  end

  defp catch_depth(fun) do
    try do
      fun.()
    catch
      {:depth_exceeded, mod, max} -> {:error, {:max_depth_exceeded, mod, max}}
    end
  end

  defp do_discover_channel(spec) do
    spec = Map.new(spec)
    name = spec[:name]

    spec
    |> Map.get(:resources, [])
    |> Enum.reduce_while({:ok, [], []}, fn entry, {:ok, evs, warns} ->
      {mod, wanted} = normalize(entry)

      case events_for(mod, wanted) do
        {:ok, list, w} -> {:cont, {:ok, evs ++ list, warns ++ w}}
        {:error, _} = e -> {:halt, e}
      end
    end)
    |> case do
      {:ok, evs, warns} ->
        {:ok, %{"name" => name, "topic" => spec[:topic], "events" => evs}, warns}

      e ->
        e
    end
  end

  defp normalize({mod, events}), do: {mod, Enum.map(events, &to_string/1)}
  defp normalize(mod) when is_atom(mod), do: {mod, :all}

  defp events_for(mod, wanted) do
    pubs = Ash.Notifier.PubSub.Info.publications(mod)

    selected =
      case wanted do
        :all ->
          {:ok, pubs}

        names ->
          Enum.reduce_while(names, {:ok, []}, fn n, {:ok, acc} ->
            case Enum.find(pubs, &(to_string(&1.event) == n)) do
              nil -> {:halt, {:error, {:event_not_found, mod, n}}}
              pub -> {:cont, {:ok, acc ++ [pub]}}
            end
          end)
      end

    with {:ok, selected} <- selected do
      events =
        for pub <- selected, not is_nil(pub.event) do
          event(pub)
        end

      warns =
        for pub <- selected,
            not is_nil(pub.event),
            not pub.public?,
            do: {:non_public_publication, mod, to_string(pub.event)}

      {:ok, events, warns}
    end
  end

  defp event(pub) do
    case pub.returns do
      nil ->
        %{"event" => to_string(pub.event), "payload" => nil, "returns_kind" => nil}

      returns ->
        type = TypeResolver.resolve(returns, pub.constraints || [])
        defn = definition(type, 0)

        %{
          "event" => to_string(pub.event),
          "payload" => defn,
          "returns_kind" => resolved_kind(type)
        }
    end
  end

  defp resolved_kind(%Type{kind: :type_ref, module: m}),
    do: resolved_kind(TypeResolver.resolve_definition(m))

  defp resolved_kind(%Type{kind: kind}), do: to_string(kind)

  @doc "Renders a resolved `Ash.Info.Manifest.Type` into the ZodType definition shape."
  @spec definition(Type.t(), non_neg_integer()) :: map()
  def definition(%Type{kind: :type_ref, module: m}, depth) when depth >= @max_depth,
    do: throw({:depth_exceeded, m, @max_depth})

  def definition(%Type{kind: :type_ref, module: m, constraints: c}, depth) do
    d = definition(TypeResolver.resolve_definition(m), depth + 1)

    if c in [nil, []],
      do: d,
      else: Map.update(d, "constraints", constraints(c), &Map.merge(&1, constraints(c)))
  end

  def definition(%Type{} = t, depth) do
    type =
      %{"kind" => kind_name(t)}
      |> put_if("fields", fields(t.fields, depth))
      |> put_if("items", t.item_type && type_of(t.item_type, depth))
      |> put_if("values", t.values && Enum.map(t.values, &to_string/1))

    %{"type" => type, "constraints" => constraints(t.constraints)}
  end

  defp type_of(%Type{} = t, depth), do: definition(t, depth + 1)["type"]

  defp fields(nil, _), do: nil
  defp fields([], _), do: nil

  defp fields(list, depth) do
    Enum.map(list, fn f ->
      %{
        "name" => to_string(f.name),
        "type" => type_of(f.type, depth),
        "allow_nil?" => f.allow_nil? != false
      }
    end)
  end

  defp kind_name(%Type{kind: kind}), do: to_string(kind)

  defp put_if(map, _k, nil), do: map
  defp put_if(map, _k, []), do: map
  defp put_if(map, k, v), do: Map.put(map, k, v)

  defp constraints(c) when is_list(c) do
    c
    |> carry_match()
    |> Enum.reject(fn {k, _} -> k in @constraint_drop end)
    |> Enum.flat_map(fn {k, v} -> if json_safe?(v), do: [{key_name(k), jsonify(v)}], else: [] end)
    |> Map.new()
  end

  defp constraints(_), do: %{}

  @js_flag %{caseless: "i", multiline: "m", dotall: "s"}
  defp js_flags(opts), do: opts |> List.wrap() |> Enum.map_join(&Map.get(@js_flag, &1, ""))

  defp key_name(:match__source), do: "match"
  defp key_name(k), do: to_string(k)

  # `match` (a Regex) is carried as its source plus flags so ZodType renders .regex().
  defp carry_match(c) do
    case Keyword.get(c, :match) do
      %Regex{} = re ->
        c ++ [{:match__source, Regex.source(re)}, {:match_flags, js_flags(Regex.opts(re))}]

      _ ->
        c
    end
  end

  defp json_safe?(v) when is_number(v) or is_boolean(v) or is_binary(v) or is_atom(v), do: true

  defp json_safe?(v) when is_list(v),
    do: Enum.all?(v, &(is_number(&1) or is_binary(&1) or (is_atom(&1) and not is_nil(&1))))

  defp json_safe?(_), do: false

  defp jsonify(v) when is_list(v), do: Enum.map(v, &jsonify/1)
  defp jsonify(v) when is_atom(v) and not is_boolean(v) and not is_nil(v), do: Atom.to_string(v)
  defp jsonify(v), do: v
end
