defmodule AshSurface.Compiler.RouteSchema.Introspector do
  @moduledoc """
  Phoenix router introspection for route descriptors (port of AshTypescript
  `RouterIntrospector`, returning typed errors instead of raising).

  Phoenix is not a hard dependency: every entry point guards with
  `Code.ensure_loaded?(Phoenix.Router)` and answers `{:error, :phoenix_unavailable}`.

  `introspect/2` takes `[{source, controller, routes}]` where each route has a
  `name` and `method` (struct, atom-keyed or string-keyed map) and returns one
  info map per mount: `%{source, controller, route, path, method, path_params,
  scope_prefix}` (`path_params` are strings; `path` is nil when unmounted;
  `scope_prefix` derived from the Phoenix helper name when mounted more than
  once). Multiple mounts whose helper names collide yield
  `{:error, {:ambiguous_mount, controller, route_name, [{verb, path}]}}`.
  """

  @spec introspect(module(), [{term(), module(), [map()]}]) ::
          {:ok, [map()]} | {:error, term()}
  def introspect(router, routes_config) do
    if available?(router) do
      router_routes = router.__routes__()

      routes_config
      |> Enum.flat_map(fn {source, controller, routes} ->
        Enum.map(routes, &{source, controller, &1})
      end)
      |> Enum.reduce_while({:ok, []}, fn {source, controller, route}, {:ok, acc} ->
        name = field(route, :name)

        matches =
          Enum.filter(
            router_routes,
            &(&1.plug == controller and to_string(&1.plug_opts) == to_string(name))
          )

        case infos(source, controller, route, matches) do
          {:ok, list} -> {:cont, {:ok, [list | acc]}}
          {:error, _} = e -> {:halt, e}
        end
      end)
      |> case do
        {:ok, acc} -> {:ok, acc |> Enum.reverse() |> List.flatten()}
        e -> e
      end
    else
      {:error, :phoenix_unavailable}
    end
  end

  @doc """
  Flat router listing: `[%{path, verb, path_params}]` sorted by `{path, verb}`.
  """
  @spec introspect_router(module()) :: {:ok, [map()]} | {:error, term()}
  def introspect_router(router) do
    if available?(router) do
      routes =
        router.__routes__()
        |> Enum.map(fn r ->
          %{
            path: r.path,
            verb: r.verb |> to_string() |> String.downcase(),
            path_params: path_params(r.path)
          }
        end)
        |> Enum.sort_by(&{&1.path, &1.verb})

      {:ok, routes}
    else
      {:error, :phoenix_unavailable}
    end
  end

  @doc "`:name` parameters of a path, as strings."
  @spec path_params(String.t()) :: [String.t()]
  def path_params(path),
    do: Regex.scan(~r{(?:\A|/)[:*](\w+)}, path) |> Enum.map(fn [_, p] -> p end)

  defp available?(router) do
    Code.ensure_loaded?(Phoenix.Router) and Code.ensure_loaded?(router) and
      function_exported?(router, :__routes__, 0)
  end

  defp infos(source, controller, route, []),
    do: {:ok, [info(source, controller, route, nil, nil)]}

  defp infos(source, controller, route, [single]),
    do: {:ok, [info(source, controller, route, single, nil)]}

  defp infos(source, controller, route, matches) do
    helpers = Enum.map(matches, & &1.helper)

    if length(Enum.uniq(helpers)) < length(matches) do
      mounts =
        Enum.map(matches, &{&1.verb |> to_string() |> String.downcase(), &1.path}) |> Enum.sort()

      {:error, {:ambiguous_mount, controller, field(route, :name), mounts}}
    else
      suffix = common_suffix(helpers)

      {:ok,
       matches
       |> Enum.map(&info(source, controller, route, &1, scope_prefix(&1.helper, suffix)))
       |> Enum.sort_by(&{&1.path, &1.method})}
    end
  end

  defp info(source, controller, route, nil, prefix) do
    %{
      source: source,
      controller: controller,
      route: route,
      path: nil,
      method: method(field(route, :method)),
      path_params: [],
      scope_prefix: prefix
    }
  end

  defp info(source, controller, route, rr, prefix) do
    %{
      source: source,
      controller: controller,
      route: route,
      path: rr.path,
      method: method(rr.verb),
      path_params: path_params(rr.path),
      scope_prefix: prefix
    }
  end

  # Segment-wise: helpers are `_`-joined segments; only whole shared trailing
  # segments are removed (`alpha_auth_path`/`zeta_auth_path` -> `alpha`/`zeta`).
  defp scope_prefix(helper, suffix_segments) do
    segs = String.split(helper, "_")
    segs |> Enum.take(length(segs) - length(suffix_segments)) |> Enum.join("_")
  end

  defp common_suffix(strings) do
    strings
    |> Enum.map(&(&1 |> String.split("_") |> Enum.reverse()))
    |> Enum.reduce(fn segs, acc ->
      acc |> Enum.zip(segs) |> Enum.take_while(fn {a, b} -> a == b end) |> Enum.map(&elem(&1, 0))
    end)
    |> Enum.reverse()
  end

  defp method(nil), do: nil
  defp method(v), do: v |> to_string() |> String.downcase()

  defp field(%{} = m, key), do: Map.get(m, key, Map.get(m, Atom.to_string(key)))
end
