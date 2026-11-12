defmodule AshSurface.Ported.RpcValidate do
  @moduledoc """
  Non-actuating counterpart of the reference `Rpc.validate_action/3` (lane GU-T11 test support).

  Stage 1 is `Rpc.Pipeline.parse_request/2` in validation mode. Form validation then builds
  the real Ash query / changeset / action input from the parsed request (no data layer is
  touched; nothing is created, read, updated or destroyed) and formats the collected errors
  through `AshSurface.Errors.to_errors/2`:

    * read actions: `Ash.Query.for_read/3` errors (typed `invalid_argument`)
    * create / update / destroy: changeset errors, normalised to `InvalidAttribute` entries
      with interpolated messages exactly as the reference does from its form errors; an
      update/destroy target is the caller-supplied `:record` (a real Ash struct) since
      resolving it from `identity` needs a data layer
    * generic actions: `Ash.ActionInput.for_action/3` errors
  """

  alias AshSurface.Ported.Rpc
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  def validate(params, opts \\ []) do
    Rpc.install()
    {record, parse_opts} = Keyword.pop(opts, :record)

    case Pipeline.parse_request(params, Keyword.put(parse_opts, :validation_mode?, true)) do
      {:ok, request} ->
        request
        |> form_errors(record)
        |> case do
          [] -> Pipeline.format_output(%{success: true}, request)
          errors -> %{"success" => false, "errors" => render(errors, request)}
        end

      {:error, reason} ->
        Pipeline.error_response(reason)
    end
  end

  defp form_errors(%{action: %{type: :read}} = r, _record),
    do: Ash.Query.for_read(r.resource, r.action.name, r.input).errors

  defp form_errors(%{action: %{type: :create}} = r, _record),
    do: r.resource |> Ash.Changeset.for_create(r.action.name, r.input) |> changeset_errors()

  defp form_errors(%{action: %{type: :update}} = r, record),
    do: record |> Ash.Changeset.for_update(r.action.name, r.input) |> changeset_errors()

  defp form_errors(%{action: %{type: :destroy}} = r, record),
    do: record |> Ash.Changeset.for_destroy(r.action.name, r.input) |> changeset_errors()

  defp form_errors(%{action: %{type: :action}} = r, _record),
    do: Ash.ActionInput.for_action(r.resource, r.action.name, r.input).errors

  defp changeset_errors(changeset) do
    Enum.map(changeset.errors, fn
      %{field: field} = error when not is_nil(field) ->
        %Ash.Error.Changes.InvalidAttribute{field: field, message: message(error), path: [field]}

      other ->
        other
    end)
  end

  defp message(%Ash.Error.Changes.Required{}), do: "is required"

  defp message(%{message: message, vars: vars}) when is_binary(message) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp message(%{message: message}) when is_binary(message), do: message
  defp message(error), do: Exception.message(error)

  defp render(errors, request) do
    AshSurface.Errors.to_errors(errors,
      resource: request.resource,
      action: request.action.name,
      context: request.context
    )
  end
end
