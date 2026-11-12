defmodule AshSurface.Errors do
  @moduledoc """
  Error pipeline: raw term -> Ash error class -> unwrapped list -> client error maps
  -> handler chain (resource -> domain -> identity) -> JSON-safe serialization ->
  `AshSurface.ErrorFormatter` key/placeholder formatting.

  Options for `to_errors/2`: `:domain`, `:resource`, `:action`, `:actor`, `:context`,
  `:formatter` (default `Config.output_field_formatter/0`, camel_case), `:show_policy_breakdowns`
  (default `Config.show_policy_breakdowns/0`; Policy errors are redacted to "forbidden" unless
  true), `:show_raised_errors` (default `Config.show_raised_errors/0`; when true non-Ash raised
  exceptions expose their message). Explicit opts always win over `AshSurface.Config`.
  Handler chain: resource -> domain -> `Config.error_handler/0` -> identity.
  `Config.error_output_formatter/0` (module with `format_error/1`, or `{m, f, extra}` called as
  `m.f(error, extra...)`) post-processes each formatted error; override with
  `:error_output_formatter`, `:resource_handler`,
  `:domain_handler` (module or `{m, f, args}`; fall back to a `handle_surface_error/2`
  function exported by the resource/domain module).

  Errors with no known shape are logged server-side under a fresh UUID and the client
  only receives that id. A handler that raises fails closed to the same generic error.
  """

  require Logger

  alias AshSurface.{Config, ErrorFormatter, ErrorHandler}
  alias AshSurface.IR.ErrorShape

  @spec to_errors(term(), keyword()) :: [map()]
  def to_errors(errors, opts \\ []) do
    opts = with_config_defaults(opts)
    kernel_formatter = Keyword.fetch!(opts, :formatter)
    formatter = error_formatter(kernel_formatter)
    out_formatter = Keyword.get(opts, :error_output_formatter)

    context =
      opts
      |> Keyword.take([:domain, :resource, :action, :actor])
      |> Map.new()
      |> Map.merge(Keyword.get(opts, :context, %{}))

    errors
    |> Ash.Error.to_error_class()
    |> unwrap_errors()
    |> Enum.map(&process(&1, opts, context))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&render(&1, formatter, out_formatter, field_names(opts), namer(opts, kernel_formatter)))
  end

  # The error-key formatter is derived from the one `FieldName` kernel (scope, then config):
  # kernel aliases normalise to the built-ins, a custom `{m, f}` kernel formatter becomes a
  # 1-arity function so structural keys and `vars` follow it as well.
  defp error_formatter(f) when f in [:camel, :camel_case], do: :camel_case
  defp error_formatter(f) when f in [:pascal, :pascal_case], do: :pascal_case
  defp error_formatter(f) when f in [:snake, :snake_case], do: :snake_case
  defp error_formatter({_, _} = f), do: custom_error_formatter(f)
  defp error_formatter({_, _, _} = f), do: custom_error_formatter(f)
  defp error_formatter(f), do: validate_formatter!(f)

  defp custom_error_formatter(f) do
    case AshSurface.FieldName.validate_formatter(f) do
      :ok -> &AshSurface.FieldName.compute(&1, f)
      {:error, _} -> validate_formatter!(f)
    end
  end

  @doc false
  def validate_formatter!(f) when f in [:camel_case, :pascal_case, :snake_case], do: f
  def validate_formatter!(f) when is_function(f, 1), do: f

  def validate_formatter!(other),
    do: raise(ArgumentError, "unknown_formatter: #{inspect(other)} (typed refusal)")

  # `:field_names` opt wins; else the resource's `field_names` surface DSL option.
  defp field_names(opts) do
    case Keyword.fetch(opts, :field_names) do
      {:ok, mapping} -> mapping
      :error -> resource_field_names(Keyword.get(opts, :resource))
    end
  end

  # Resource-bound naming (no explicit `:field_names` opt): the SAME `FieldName` kernel that
  # names schema keys, so error `fields`/`path`/`vars.field` equal the schema key spelling.
  defp namer(opts, formatter) do
    resource = Keyword.get(opts, :resource)

    if not Keyword.has_key?(opts, :field_names) and is_atom(resource) and not is_nil(resource) and
         Code.ensure_loaded?(resource) and function_exported?(resource, :spark_is, 0) and
         Ash.Resource.Info.resource?(resource) do
      action = action_name(Keyword.get(opts, :action))

      fn name ->
        fmt = [formatter: formatter]

        cond do
          is_function(formatter, 1) -> ErrorFormatter.format_name(name, formatter)
          action -> AshSurface.FieldName.wire_argument(resource, action, name, fmt)
          true -> AshSurface.FieldName.wire(resource, name, fmt)
        end
      end
    end
  end

  defp action_name(a) when is_atom(a) and not is_nil(a), do: a
  defp action_name(%{name: n}) when is_atom(n), do: n
  defp action_name(_), do: nil

  defp resource_field_names(resource) when is_atom(resource) and not is_nil(resource) do
    if Code.ensure_loaded?(resource) and function_exported?(resource, :spark_dsl_config, 0) do
      AshSurface.Resource.Info.field_names(resource)
    end
  rescue
    _ -> nil
  end

  defp resource_field_names(_), do: nil

  defp map_field_names(error, mapping, formatter),
    do: ErrorFormatter.apply_field_names(error, mapping, formatter)

  # Whole render path is fail-closed: a raising output formatter yields the generic error.
  defp render(error, formatter, out_formatter, field_names, namer) do
    error
    |> finalize()
    |> serialize()
    |> then(fn e ->
      if namer,
        do: ErrorFormatter.apply_namer(e, namer),
        else: map_field_names(e, field_names, formatter)
    end)
    |> ErrorFormatter.format(formatter)
    |> output_format(out_formatter)
  rescue
    e -> fail_closed("output formatter: " <> inspect(e), error, formatter)
  catch
    kind, reason -> fail_closed("#{kind}: #{inspect(reason)}", error, formatter)
  end

  defp fail_closed(reason, original, formatter) do
    uuid = Ash.UUID.generate()

    Logger.error(
      "Error formatting failed. Error ID: #{uuid} Failure: #{reason} Original: #{inspect(original)}"
    )

    uuid |> generic([]) |> serialize() |> ErrorFormatter.format(formatter)
  end

  defp with_config_defaults(opts) do
    opts
    |> Keyword.put_new_lazy(:formatter, &AshSurface.FieldName.output_formatter/0)
    |> Keyword.put_new_lazy(:show_raised_errors, &Config.show_raised_errors/0)
    |> Keyword.put_new_lazy(:show_policy_breakdowns, &Config.show_policy_breakdowns/0)
    |> Keyword.put_new_lazy(:default_handler, &Config.error_handler/0)
    |> Keyword.put_new_lazy(:error_output_formatter, &Config.error_output_formatter/0)
  end

  defp output_format(error, nil), do: error

  defp output_format(error, {mod, fun, extra}) when is_list(extra) and length(extra) <= 3 do
    f = Function.capture(mod, fun, 1 + length(extra))

    case extra do
      [] -> f.(error)
      [a] -> f.(error, a)
      [a, b] -> f.(error, a, b)
      [a, b, c] -> f.(error, a, b, c)
    end
  end

  defp output_format(error, mod) when is_atom(mod), do: mod.format_error(error)

  # Every emitted type is routed through the closed enum; details always present.
  defp finalize(error) when is_map(error) do
    error
    |> Map.update(:type, ErrorShape.catch_all(), &ErrorShape.normalize_type/1)
    |> Map.put_new(:details, %{})
  end

  defp finalize(other), do: other

  @doc "Generic client error for an unrecognised term; logged under a fresh UUID."
  @spec unhandled_error(term()) :: map()
  def unhandled_error(error) do
    uuid = Ash.UUID.generate()

    Logger.warning(
      "Unhandled error in surface pipeline. Error ID: #{uuid} Error: #{inspect(error)}"
    )

    generic(uuid, path_of(error))
  end

  @doc """
  Ash error struct -> wire `{type, short_message}`. Total over structs: anything not in
  the table is `unknown_error` (the closed set in `IR.ErrorShape`).
  """
  @spec classify(term()) :: {String.t(), String.t()}
  def classify(%module{}), do: type_for(module)
  def classify(_), do: {"unknown_error", "Unknown error"}

  @spec unwrap_errors(term()) :: [term()]
  def unwrap_errors(%{errors: errors}) when is_list(errors),
    do: Enum.flat_map(errors, &unwrap_errors/1)

  def unwrap_errors(%{errors: error}), do: unwrap_errors([error])
  def unwrap_errors(list) when is_list(list), do: Enum.flat_map(list, &unwrap_errors/1)

  # Reactor step failure: delegate to the wrapped inner error (ref rpc/error.ex RunStepError).
  def unwrap_errors(%{__struct__: Reactor.Error.Invalid.RunStepError, error: inner}),
    do: unwrap_errors(inner)

  def unwrap_errors(error), do: [error]

  defp process(error, opts, context) do
    base =
      transform(
        error,
        Keyword.get(opts, :show_raised_errors, false),
        Keyword.get(opts, :show_policy_breakdowns, false)
      )

    resource = Keyword.get(opts, :resource)
    domain = Keyword.get(opts, :domain)

    handlers = [
      Keyword.get(opts, :resource_handler) || exported(resource),
      Keyword.get(opts, :domain_handler) || exported(domain),
      Keyword.get(opts, :default_handler)
    ]

    try do
      case ErrorHandler.chain(base, context, handlers) do
        nil ->
          Logger.warning("Error dropped by handler chain: #{inspect(base)}")
          nil

        result ->
          result
      end
    rescue
      e -> handler_failure(inspect(e), base)
    catch
      kind, reason -> handler_failure("#{kind}: #{inspect(reason)}", base)
    end
  end

  defp exported(mod) when is_atom(mod) and not is_nil(mod) do
    Code.ensure_loaded(mod)
    if function_exported?(mod, :handle_surface_error, 2), do: {mod, :handle_surface_error, []}
  end

  defp exported(_), do: nil

  defp transform(error, show_raised?, show_policy?) do
    cond do
      match?(%Ash.Error.Unknown.UnknownError{}, error) and show_raised? ->
        exposed(error)

      is_struct(error) and Map.has_key?(table(), error.__struct__) and
          not match?(%Ash.Error.Unknown.UnknownError{}, error) ->
        known(error, show_policy?)

      is_exception(error) and show_raised? ->
        exposed(error)

      true ->
        unhandled_error(error)
    end
  end

  defp exposed(error) do
    %{
      message: Exception.message(error),
      short_message: "Unknown error",
      type: "unknown_error",
      vars: %{},
      fields: field_list(error),
      path: path_of(error)
    }
  end

  # {type, short_message}: private table (no protocol), ref rpc/error.ex.
  @table %{
    Ash.Error.Changes.InvalidChanges => {"invalid_changes", "Invalid changes"},
    Ash.Error.Query.InvalidQuery => {"invalid_query", "Invalid query"},
    Ash.Error.Query.NotFound => {"not_found", "Not found"},
    Ash.Error.Changes.Required => {"required", "Required field"},
    Ash.Error.Query.Required => {"required", "Required field"},
    Ash.Error.Forbidden.Policy => {"forbidden", "Forbidden"},
    Ash.Error.Forbidden.ForbiddenField => {"forbidden_field", "Forbidden field"},
    Ash.Error.Changes.InvalidAttribute => {"invalid_attribute", "Invalid attribute"},
    Ash.Error.Changes.InvalidArgument => {"invalid_argument", "Invalid argument"},
    Ash.Error.Query.InvalidArgument => {"invalid_argument", "Invalid argument"},
    Ash.Error.Action.InvalidArgument => {"invalid_argument", "Invalid argument"},
    Ash.Error.Page.InvalidKeyset => {"invalid_keyset", "Invalid keyset"},
    Ash.Error.Query.InvalidPage => {"invalid_page", "Invalid pagination"},
    Ash.Error.Invalid.TenantRequired => {"tenant_required", "Tenant required"},
    Ash.Error.Invalid.InvalidPrimaryKey => {"invalid_primary_key", "Invalid primary key"},
    Ash.Error.Query.ReadActionRequiresActor => {"forbidden", "Authentication required"},
    Ash.Error.Unknown.UnknownError => {"unknown_error", "Unknown error"},
    AshAuthentication.Errors.AuthenticationFailed =>
      {"authentication_failed", "Authentication failed"},
    AshAuthentication.Errors.InvalidToken => {"invalid_token", "Invalid token"}
  }

  defp table, do: @table

  # Reference rpc/error.ex: these types emit `Map.get(error, :message) || Exception.message/1`
  # (the bare template, interpolated client-side from `vars`), not the long Ash form.
  @bare_message_types [
    Ash.Error.Changes.InvalidChanges,
    Ash.Error.Query.InvalidQuery,
    Ash.Error.Changes.InvalidAttribute,
    Ash.Error.Changes.InvalidArgument,
    Ash.Error.Query.InvalidArgument,
    Ash.Error.Action.InvalidArgument
  ]

  defp error_vars(error) do
    case Map.get(error, :vars) do
      vars when is_list(vars) or is_map(vars) ->
        vars |> Map.new() |> Map.new(fn {k, v} -> {k, scrub(v)} end)

      _ ->
        %{}
    end
  end

  defp scrub(v) when is_atom(v) and not is_nil(v) and not is_boolean(v) do
    case Atom.to_string(v) do
      "Elixir." <> _ -> v |> Module.split() |> List.last()
      s -> s
    end
  end

  defp scrub(v), do: v

  defp type_for(module) do
    case Map.fetch(@table, module) do
      {:ok, {type, short}} -> {ErrorShape.normalize_type(type), short}
      :error -> {ErrorShape.catch_all(), module |> Module.split() |> List.last()}
    end
  end

  defp known(error, show_policy?) do
    {type, short} = type_for(error.__struct__)

    vars =
      error
      |> Map.from_struct()
      |> Map.take([:field, :value, :resource, :action, :relationship, :key, :count])
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new(fn {k, v} -> {k, scrub(v)} end)

    {message, vars} =
      case error do
        %Ash.Error.Forbidden.Policy{} when show_policy? ->
          {Ash.Error.Forbidden.Policy.report(error, help_text?: false), vars}

        %Ash.Error.Forbidden.Policy{} ->
          {"forbidden", %{}}

        %mod{message: bare} when is_binary(bare) and mod in @bare_message_types ->
          {bare, Map.merge(error_vars(error), vars)}

        _ ->
          {Exception.message(error), vars}
      end

    %{
      message: message,
      short_message: short,
      type: type,
      vars: vars,
      fields: field_list(error),
      path: path_of(error)
    }
  end

  defp field_list(error) do
    cond do
      is_atom(Map.get(error, :field)) and not is_nil(Map.get(error, :field)) -> [error.field]
      is_list(Map.get(error, :fields)) -> error.fields
      true -> []
    end
  end

  defp path_of(error) when is_map(error),
    do: if(is_list(Map.get(error, :path)), do: error.path, else: [])

  defp path_of(_), do: []

  defp handler_failure(reason, original) do
    uuid = Ash.UUID.generate()

    Logger.error(
      "Error handler failed. Error ID: #{uuid} Failure: #{reason} Original: #{inspect(original)}"
    )

    generic(uuid, [])
  end

  defp generic(uuid, path) do
    %{
      message: "Something went wrong. Unique error id: #{uuid}",
      short_message: "Unknown error",
      type: "unknown_error",
      vars: %{},
      fields: [],
      path: path,
      details: %{error_id: uuid}
    }
  end

  defp key(k) when is_binary(k), do: k
  defp key(k) when is_atom(k), do: Atom.to_string(k)
  defp key(k) when is_number(k), do: to_string(k)
  defp key(k), do: inspect(k)

  defp serialize(v) when is_nil(v) or is_binary(v) or is_number(v) or is_boolean(v), do: v
  defp serialize(v) when is_atom(v), do: Atom.to_string(v)
  defp serialize(v) when is_tuple(v), do: v |> Tuple.to_list() |> Enum.map(&serialize/1)
  defp serialize(%DateTime{} = v), do: DateTime.to_iso8601(v)
  defp serialize(%Date{} = v), do: Date.to_iso8601(v)
  defp serialize(%Time{} = v), do: Time.to_iso8601(v)
  defp serialize(%NaiveDateTime{} = v), do: NaiveDateTime.to_iso8601(v)
  defp serialize(%Decimal{} = v), do: Decimal.to_string(v, :normal)
  defp serialize(%Ash.CiString{} = v), do: Ash.CiString.value(v)
  defp serialize(%module{}), do: "##{inspect(module)}<>"

  defp serialize(v) when is_list(v) do
    cond do
      v == [] -> []
      Keyword.keyword?(v) -> Map.new(v, fn {k, x} -> {key(k), serialize(x)} end)
      true -> Enum.map(v, &serialize/1)
    end
  end

  defp serialize(v) when is_map(v), do: Map.new(v, fn {k, x} -> {key(k), serialize(x)} end)
  defp serialize(v) when is_pid(v), do: "#PID<>"
  defp serialize(v) when is_reference(v), do: "#Reference<>"
  defp serialize(v) when is_function(v), do: "#Function<>"
  defp serialize(v), do: v
end
