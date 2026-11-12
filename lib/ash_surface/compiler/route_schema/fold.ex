defmodule AshSurface.Compiler.RouteSchema.Fold do
  @moduledoc """
  Counterpart of ash_typescript `TypedController.Transformers.FoldArgumentConstraints`
  for string-keyed route descriptors.

  `fold_arguments/2` validates each argument's type kind and constraints and folds the
  type's constraint defaults into the argument (Ash string kinds default
  `allow_empty?: false`, so the fold makes it explicit and the rendered Zod fragment is
  identical to one built from an RPC action input). `check_returns/2` restricts a route's
  `returns` to plain data (no resources or unions at any depth), since the handler, not
  the caller, decides what it sends.

  Refusals (typed, never a silent `z.unknown()`):
  `{:invalid_argument_type, route, argument, kind}`,
  `{:invalid_argument_constraints, route, argument, key, reason}`,
  `{:unsupported_return, route, kind}`.
  """

  alias AshSurface.Compiler.ZodType

  @string_default_kinds ~w(string ci_string)

  # Descriptor kind -> Ash type whose `Ash.Type.constraints/1` defines the lawful key set.
  # Kinds absent here (ltree, enum, ...) have no Ash constraint schema to derive from and
  # fall back to key-shape validation against every key the fold knows.
  @ash_types %{
    "string" => Ash.Type.String,
    "ci_string" => Ash.Type.CiString,
    "integer" => Ash.Type.Integer,
    "boolean" => Ash.Type.Boolean,
    "uuid" => Ash.Type.UUID,
    "uuid_v7" => Ash.Type.UUIDv7,
    "float" => Ash.Type.Float,
    "decimal" => Ash.Type.Decimal,
    "date" => Ash.Type.Date,
    "time" => Ash.Type.Time,
    "time_usec" => Ash.Type.TimeUsec,
    "utc_datetime" => Ash.Type.UtcDatetime,
    "utc_datetime_usec" => Ash.Type.UtcDatetimeUsec,
    "datetime" => Ash.Type.DateTime,
    "naive_datetime" => Ash.Type.NaiveDatetime,
    "duration" => Ash.Type.Duration,
    "duration_name" => Ash.Type.DurationName,
    "binary" => Ash.Type.Binary,
    "atom" => Ash.Type.Atom,
    "map" => Ash.Type.Map,
    "struct" => Ash.Type.Struct,
    "keyword" => Ash.Type.Keyword,
    "tuple" => Ash.Type.Tuple,
    "term" => Ash.Type.Term,
    "module" => Ash.Type.Module,
    "function" => Ash.Type.Function,
    "file" => Ash.Type.File,
    "url_encoded_binary" => Ash.Type.UrlEncodedBinary,
    "vector" => Ash.Type.Vector,
    "array" => {:array, Ash.Type.String}
  }

  # Keys the fold / Zod renderer itself reads or injects, per kind (not in Ash's schema).
  @injected_keys %{
    "string" => ~w(match_flags),
    "ci_string" => ~w(match_flags),
    "array" => ~w(min_items max_items unique_items?)
  }

  @bound_keys ~w(min max greater_than less_than)
  @non_neg_int_keys ~w(min_length max_length min_items max_items scale)
  @boolean_keys ~w(allow_empty? trim? escape? unsafe_to_atom? preserve_nil_values? nil_items?
                   remove_nil_items? unique_items? strict? sort?)
  @known_keys @bound_keys ++
                @non_neg_int_keys ++
                @boolean_keys ++
                ~w(match match_flags one_of items fields instance_of precision storage_type
                   casing length_count cast_dates_as timezone signs units dimensions
                   empty_values mfa arity behaviour protocol)
  @forbidden_return_kinds ~w(resource embedded_resource union)

  @spec fold_arguments(term(), [map()]) :: {:ok, [map()]} | {:error, term()}
  def fold_arguments(route, args) do
    args
    |> Enum.reduce_while({:ok, []}, fn arg, {:ok, acc} ->
      case fold_argument(route, arg) do
        {:ok, folded} -> {:cont, {:ok, [folded | acc]}}
        {:error, _} = e -> {:halt, e}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      e -> e
    end
  end

  @spec check_returns(term(), map()) :: :ok | {:error, term()}
  def check_returns(route, %{} = descriptor) do
    case first_forbidden(descriptor["returns"]) do
      nil -> :ok
      kind -> {:error, {:unsupported_return, route["name"], kind}}
    end
  end

  defp first_forbidden(%{} = def_map) do
    type = def_map["type"]
    type = if is_map(type), do: type, else: %{}

    own = type["kind"] || def_map["kind"]

    cond do
      own in @forbidden_return_kinds ->
        own

      true ->
        [type["items"], type["item_type"], def_map["items"], def_map["item_type"]]
        |> Enum.map(&nested/1)
        |> Enum.find(& &1)
    end
  end

  defp first_forbidden(kind) when is_binary(kind),
    do: if(kind in @forbidden_return_kinds, do: kind)

  defp first_forbidden(_), do: nil

  defp nested(%{"kind" => _} = t), do: first_forbidden(%{"type" => t})
  defp nested(%{} = d), do: first_forbidden(d)
  defp nested(_), do: nil

  defp fold_argument(route, arg) do
    name = arg["name"]
    kind = kind(arg)

    with :ok <- check_kind(route, name, arg),
         {:ok, constraints} <- constraints(route, name, kind, arg["constraints"]),
         {:ok, arg} <- fold_items(route, name, arg) do
      {:ok, put_constraints(arg, kind, constraints)}
    end
  end

  # Array item constraints: validated against the item kind and folded like a scalar argument.
  defp fold_items(
         route,
         name,
         %{"type" => %{"kind" => "array", "items" => %{} = item} = type} = arg
       ) do
    ikind = if is_binary(item["kind"]), do: item["kind"]

    case item["constraints"] do
      nil ->
        {:ok, arg}

      c ->
        with {:ok, folded} <- constraints(route, name, ikind, c) do
          # definition form so the Zod renderer reads the item's own constraints
          item = %{
            "type" => %{"kind" => ikind},
            "constraints" => fold_defaults(ikind, folded)
          }

          {:ok, Map.put(arg, "type", Map.put(type, "items", item))}
        end
    end
  end

  defp fold_items(_route, _name, arg), do: {:ok, arg}

  defp kind(%{"type" => %{"kind" => kind}}) when is_binary(kind), do: kind
  defp kind(_), do: nil

  defp check_kind(route, name, arg) do
    case ZodType.unmappable_kinds([arg]) do
      [] -> :ok
      [bad | _] -> {:error, {:invalid_argument_type, route, name, bad}}
    end
  end

  defp constraints(_route, _name, _kind, nil), do: {:ok, %{}}

  defp constraints(route, name, kind, %{} = c) do
    allowed = allowed_keys(kind)

    Enum.reduce_while(c, :ok, fn {key, value}, :ok ->
      key = to_string(key)

      case check_constraint(kind, allowed, key, value) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, {:invalid_argument_constraints, route, name, key, reason}}}
      end
    end)
    |> case do
      :ok -> {:ok, c}
      e -> e
    end
  end

  defp constraints(route, name, _kind, other),
    do: {:error, {:invalid_argument_constraints, route, name, "constraints", {:not_a_map, other}}}

  # Per-kind lawful key set, derived from `Ash.Type.constraints/1` of the resolved type plus
  # the keys the fold injects. `nil` means no Ash type to derive from (key-shape check only).
  defp allowed_keys(kind) do
    case Map.fetch(@ash_types, kind) do
      {:ok, type} ->
        ash = type |> Ash.Type.constraints() |> Keyword.keys() |> Enum.map(&Atom.to_string/1)
        ash ++ Map.get(@injected_keys, kind, [])

      :error ->
        nil
    end
  end

  defp check_constraint(kind, allowed, key, value) do
    cond do
      key not in @known_keys -> {:error, :unknown_constraint}
      is_list(allowed) and key not in allowed -> {:error, :not_applicable}
      key in @bound_keys -> check_bound(kind, value)
      true -> check_value(key, value)
    end
  end

  defp check_bound("decimal", v),
    do: if(numeric?(v), do: :ok, else: {:error, :not_a_number})

  defp check_bound(_kind, v),
    do: if(is_number(v), do: :ok, else: {:error, :not_a_number})

  defp check_value(key, value) when key in @non_neg_int_keys,
    do: if(is_integer(value) and value >= 0, do: :ok, else: {:error, :not_a_non_negative_integer})

  defp check_value(key, value) when key in @boolean_keys,
    do: if(is_boolean(value), do: :ok, else: {:error, :not_a_boolean})

  defp check_value("match", v), do: binary_value(v)
  defp check_value("match_flags", v), do: binary_value(v)
  defp check_value("instance_of", v), do: binary_value(v)
  defp check_value("timezone", v), do: binary_value(v)
  defp check_value("length_count", v), do: one_of_value(v, ~w(graphemes codepoints bytes))
  defp check_value("casing", v), do: one_of_value(v, ["upper", "lower", nil])

  defp check_value("cast_dates_as", v),
    do: if(is_binary(v) or is_atom(v), do: :ok, else: {:error, :not_a_string})

  defp check_value("precision", v) do
    if (is_integer(v) and v >= 0) or (is_binary(v) and v != "") or (is_atom(v) and not is_nil(v)),
      do: :ok,
      else: {:error, :invalid_precision}
  end

  defp check_value("dimensions", v),
    do: if(is_integer(v) and v > 0, do: :ok, else: {:error, :not_a_positive_integer})

  defp check_value("arity", v),
    do: if(is_integer(v) and v >= 0, do: :ok, else: {:error, :not_a_non_negative_integer})

  defp check_value("one_of", v),
    do: if(is_list(v) and v != [], do: :ok, else: {:error, :not_a_non_empty_list})

  defp check_value(key, v) when key in ~w(signs units empty_values),
    do: if(is_list(v) or is_binary(v) or is_atom(v), do: :ok, else: {:error, :not_a_list})

  defp check_value("items", v), do: if(is_map(v), do: :ok, else: {:error, :not_a_map})

  defp check_value("fields", v),
    do: if(is_map(v) or is_list(v), do: :ok, else: {:error, :not_a_map})

  defp check_value(_key, _value), do: :ok

  defp numeric?(v) when is_number(v), do: true
  defp numeric?(v) when is_binary(v), do: match?({%Decimal{}, ""}, Decimal.parse(v))
  defp numeric?(_), do: false

  defp binary_value(v), do: if(is_binary(v), do: :ok, else: {:error, :not_a_string})

  defp one_of_value(v, allowed) do
    s = if is_atom(v) and not is_nil(v) and not is_boolean(v), do: Atom.to_string(v), else: v
    if s in allowed, do: :ok, else: {:error, {:not_one_of, allowed}}
  end

  # Ash string kinds default `allow_empty?: false`; fold it in explicitly.
  defp put_constraints(arg, kind, constraints) do
    folded = fold_defaults(kind, constraints)

    if folded == %{} and not Map.has_key?(arg, "constraints"),
      do: arg,
      else: Map.put(arg, "constraints", folded)
  end

  defp fold_defaults(kind, constraints) when kind in @string_default_kinds do
    constraints
    |> Map.put_new("allow_empty?", false)
    |> Map.put_new("trim?", true)
  end

  defp fold_defaults(_kind, constraints), do: constraints
end
