defmodule AshSurface.Resource.Validator do
  @moduledoc false

  # Admission law (ontology.ttl: surf:AshSurfaceSpec validate delegate, arity 1,
  # `:ok | {:error, [%{code: _, detail: _}]}`): surface projection metadata is
  # admitted only against the EXACT public action set of the compiled resource.
  #
  # Transport kinds mirror the projection facet one_of in ontology.ttl
  # (surf:TransportAuto/Http/Channel). `:auto` is a projection-side preference
  # meaning "preserve all admitted alternatives"; it is not a runtime transport
  # and therefore does not borrow AshSurface.Transport's runtime list.
  #
  # Offline classes mirror the runtime's offline semantics: `:online_only` (no
  # offline behavior), `:cache_last` (serve last observed state offline),
  # `:queue_reconcile` (queue DO commands offline, reconcile via receipts).
  @admitted_transports [:auto, :http, :phoenix_channel]
  @admitted_offline_classes [:online_only, :cache_last, :queue_reconcile]

  @spec validate(map()) :: :ok | {:error, [map()]}
  def validate(%{surface: projections} = compiled) when is_list(projections) do
    if Enum.all?(projections, &projection_shape?/1) do
      refusals =
        duplicate_refusals(projections) ++
          admission_refusals(compiled, projections) ++
          kind_refusals(projections)

      if refusals == [], do: :ok, else: {:error, refusals}
    else
      {:error, invalid_compilation("every surface projection must declare an atom :action")}
    end
  end

  def validate(_compiled) do
    {:error,
     invalid_compilation(
       "compiled AshSurface extension state must contain a surface projection list"
     )}
  end

  defp projection_shape?(%{action: action}) when is_atom(action), do: true
  defp projection_shape?(_projection), do: false

  defp duplicate_refusals(projections) do
    projections
    |> Enum.map(& &1.action)
    |> Enum.frequencies()
    |> Enum.filter(fn {_action, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.map(fn action ->
      %{
        code: "duplicate_action_projection",
        detail: "surface projection for #{inspect(action)} is declared more than once"
      }
    end)
  end

  # Metadata naming anything outside the resource's exact public action set is
  # refused instead of silently becoming a second application model.
  defp admission_refusals(_compiled, []), do: []

  defp admission_refusals(compiled, projections) do
    case public_action_set(compiled) do
      nil ->
        invalid_compilation(
          "compiled AshSurface extension state must reference the Ash resource whose exact public action set admits every projection"
        )

      public_actions ->
        known = MapSet.new(public_actions)

        projections
        |> Enum.map(& &1.action)
        |> Enum.uniq()
        |> Enum.reject(&MapSet.member?(known, &1))
        |> Enum.sort()
        |> Enum.map(fn action ->
          %{
            code: "unknown_action_projection",
            detail:
              "surface projection names #{inspect(action)}, which is not in the exact public action set " <>
                inspect(Enum.sort(public_actions))
          }
        end)
    end
  end

  defp public_action_set(%{resource: resource}) do
    if Ash.Resource.Info.resource?(resource) do
      resource
      |> Ash.Resource.Info.public_actions()
      |> Enum.map(& &1.name)
    else
      nil
    end
  end

  defp public_action_set(_compiled), do: nil

  defp kind_refusals(projections) do
    Enum.flat_map(projections, fn projection ->
      kind_refusal(
        projection,
        :transport,
        @admitted_transports,
        "unknown_transport_projection",
        "transport"
      ) ++
        kind_refusal(
          projection,
          :offline,
          @admitted_offline_classes,
          "unknown_offline_class_projection",
          "offline class"
        )
    end)
  end

  defp kind_refusal(projection, field, admitted, code, label) do
    case Map.get(projection, field) do
      nil ->
        []

      kind ->
        if Enum.member?(admitted, kind) do
          []
        else
          [
            %{
              code: code,
              detail:
                "surface projection for #{inspect(projection.action)} declares #{label} #{inspect(kind)}; admitted kinds are " <>
                  inspect(admitted)
            }
          ]
        end
    end
  end

  defp invalid_compilation(detail) do
    [%{code: "invalid_surface_compilation", detail: detail}]
  end
end
