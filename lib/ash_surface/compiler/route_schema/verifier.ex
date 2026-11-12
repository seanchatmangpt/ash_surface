defmodule AshSurface.Compiler.RouteSchema.Verifier do
  @moduledoc """
  Descriptor-level equivalent of the reference `VerifyTypedController` (non-actuating).

  Typed refusals: `{:duplicate_route_names, [name]}`, `{:invalid_argument_types, [{route, arg}]}`,
  `{:invalid_names, [{subject, name, suggestion | :not_identifier}]}`,
  `{:invalid_field_names, [{subject, path, suggestion | :not_identifier}]}`.
  Field names are checked at any depth inside `returns` and argument `"fields"` maps.
  """
  alias AshSurface.Naming

  @spec verify([map()]) :: :ok | {:error, term()}
  def verify(routes) when is_list(routes) do
    Enum.find_value(
      [&names/1, &arg_types/1, &route_names/1, &field_names/1],
      :ok,
      fn check ->
        case check.(routes) do
          :ok -> nil
          err -> err
        end
      end
    )
  end

  defp names(routes) do
    dups =
      routes
      |> Enum.group_by(&{&1["name"], &1["scope_prefix"]})
      |> Enum.filter(fn {_, v} -> length(v) > 1 end)
      |> Enum.map(fn {{n, _}, _} -> n end)

    if dups == [], do: :ok, else: {:error, {:duplicate_route_names, dups}}
  end

  defp arg_types(routes) do
    bad =
      for r <- routes,
          a <- Map.get(r, "arguments", []),
          not valid_type?(a["type"]),
          do: {r["name"], a["name"]}

    if bad == [], do: :ok, else: {:error, {:invalid_argument_types, bad}}
  end

  defp valid_type?(%{"kind" => k}) when is_binary(k) and k != "", do: true
  defp valid_type?(k) when is_binary(k) and k != "", do: true
  defp valid_type?(_), do: false

  defp route_names(routes) do
    bad =
      for r <- routes,
          {subject, n} <-
            [{"route #{r["name"]}", r["name"]}] ++
              for(
                a <- Map.get(r, "arguments", []),
                do: {"route #{r["name"]}, argument #{a["name"]}", a["name"]}
              ),
          p = problem(n),
          do: {subject, n, p}

    if bad == [], do: :ok, else: {:error, {:invalid_names, bad}}
  end

  defp field_names(routes) do
    bad =
      for r <- routes,
          {loc, def} <-
            [{"returns", r["returns"]}] ++
              for(a <- Map.get(r, "arguments", []), do: {"argument #{a["name"]}", a["type"]}),
          {path, p} <- walk(def, []),
          do: {"route #{r["name"]}, #{loc} field", Enum.join(path, "."), p}

    if bad == [], do: :ok, else: {:error, {:invalid_field_names, bad}}
  end

  defp problem(name) do
    n = to_string(name)

    cond do
      Naming.invalid_name?(n) -> Naming.make_name_better(n)
      not Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, n) -> :not_identifier
      true -> nil
    end
  end

  defp walk(%{} = m, path) do
    own =
      case m["fields"] do
        %{} = f ->
          Enum.flat_map(f, fn {k, v} ->
            here = for p <- [problem(k)], p, do: {path ++ [k], p}
            here ++ walk(v, path ++ [k])
          end)

        _ ->
          []
      end

    rest =
      Enum.flat_map(["type", "items"], fn key ->
        case m[key] do
          %{} = sub -> walk(sub, if(key == "items", do: path ++ ["[]"], else: path))
          _ -> []
        end
      end)

    own ++ rest
  end

  defp walk(_, _), do: []
end
