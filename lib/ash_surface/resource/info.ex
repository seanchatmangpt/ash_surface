defmodule AshSurface.Resource.Projections do
  @moduledoc """
  Typed introspection of projection options (zod port lane 12).

  Reads the `:surface` projection entities through `AshSurface.Resource.Info`
  and applies option defaults. Name, namespace, description, deprecated and see
  are presentation facts: this module exposes them but they never belong in IR
  truth sections.
  """

  alias AshSurface.Resource.Info

  @defaults %{
    get?: false,
    not_found_error?: true,
    enable_filter?: true,
    enable_sort?: true,
    get_by: [],
    identities: [],
    see: []
  }

  @presentation_keys [:name, :namespace, :description, :deprecated, :see]

  @doc "All projection entities of `resource`."
  @spec all(module()) :: [struct()]
  def all(resource),
    do: Enum.reject(Info.surface(resource), &match?(%AshSurface.Dsl.TypedQuery{}, &1))

  @doc "All typed_query entities of `resource`."
  @spec typed_queries(module()) :: [struct()]
  def typed_queries(resource),
    do: Enum.filter(Info.surface(resource), &match?(%AshSurface.Dsl.TypedQuery{}, &1))

  @doc "The typed query named `name`, or nil."
  @spec typed_query(module(), atom()) :: struct() | nil
  def typed_query(resource, name), do: Enum.find(typed_queries(resource), &(&1.name == name))

  @doc "The projection for `action`, or nil."
  @spec for_action(module(), atom()) :: struct() | nil
  def for_action(resource, action), do: Enum.find(all(resource), &(&1.action == action))

  @doc "Effective option value with defaults applied."
  @spec option(struct(), atom()) :: term()
  def option(projection, key), do: Map.get(projection, key) |> default(key)

  @doc "Presentation-only facts of a projection (excluded from IR truth sections)."
  @spec presentation(struct()) :: map()
  def presentation(projection) do
    Map.new(@presentation_keys, fn key -> {key, option(projection, key)} end)
  end

  defp default(nil, key), do: Map.get(@defaults, key)
  defp default(value, _key), do: value
end
