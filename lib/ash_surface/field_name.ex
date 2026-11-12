defmodule AshSurface.FieldName do
  @moduledoc """
  Client-facing field naming. Canonical IR names stay snake_case; conversion
  happens only at projection. Explicit override maps are used verbatim.
  Parsing client input never mints atoms (`String.to_existing_atom/1` only).
  """

  @type formatter ::
          :camel_case
          | :snake_case
          | :pascal_case
          | :camel
          | :snake
          | :pascal
          | {module, atom}
          | {module, atom, [term]}
  @sort_prefixes ["--", "++", "-", "+"]

  @doc "Format `field` for the client; an `overrides` entry wins verbatim."
  @spec format(atom | String.t(), formatter, %{optional(atom) => String.t()}) :: String.t()
  def format(field, formatter, overrides \\ %{}) do
    case field do
      f when is_atom(f) and is_map_key(overrides, f) -> Map.fetch!(overrides, f)
      f -> compute(f, formatter)
    end
  end

  @scope_key :ash_surface_output_field_formatter

  @doc """
  The output formatter in force for emitted keys: the process-scoped one set by
  `with_formatter/2` (also `AshSurface.Compiler.compile/2` option `:output_field_formatter`),
  else `AshSurface.Config.output_field_formatter/0` (default `:camel_case`).
  """
  @spec output_formatter() :: formatter
  def output_formatter, do: scoped_formatter() || AshSurface.Config.output_field_formatter()

  @doc """
  The `with_formatter/2` scope in force for the calling process, or `nil` when none.

  A spawned process (`Task.async`, `Task.Supervisor.async_nolink`, anything that sets `$callers`
  or `$ancestors`) resolves the scope of its nearest scoped caller, the way the Ecto sandbox
  resolves its owner. The scope is read from the live caller's process dictionary, so it ends
  with the `with_formatter/2` block (or the caller's death): nothing is copied into the child.
  """
  @spec scoped_formatter() :: formatter | nil
  def scoped_formatter do
    case Process.get(@scope_key, :unset) do
      :unset -> inherited_scope()
      formatter -> formatter
    end
  end

  @doc """
  Explicit scope handle: `capture_scope/0` in the scoped process, `with_scope/2` in any process
  (a plain `spawn`, a GenServer) that carries no `$callers` chain.
  """
  @spec capture_scope() :: formatter | nil
  def capture_scope, do: scoped_formatter()

  @spec with_scope(formatter | nil, (-> result)) :: result when result: term
  def with_scope(nil, fun) when is_function(fun, 0), do: fun.()
  def with_scope(formatter, fun), do: with_formatter(formatter, fun)

  defp inherited_scope do
    chain = Process.get(:"$callers", []) ++ Process.get(:"$ancestors", [])

    Enum.find_value(chain, fn
      pid when is_pid(pid) and node(pid) == node() ->
        with {:dictionary, dict} <- Process.info(pid, :dictionary),
             {_, formatter} <- List.keyfind(dict, @scope_key, 0) do
          formatter
        else
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  @doc "Input formatter in force: the `with_formatter/2` scope, else `Config.input_field_formatter/0`."
  @spec input_formatter() :: formatter
  def input_formatter, do: scoped_formatter() || AshSurface.Config.input_field_formatter()

  @doc """
  Runs `fun` with `formatter` as the output formatter of the calling process (nesting restores
  the outer value). Unlike the application env this is invisible to other processes, so it is
  safe under concurrent compiles.
  """
  @spec with_formatter(formatter, (-> result)) :: result when result: term
  def with_formatter(formatter, fun) when is_function(fun, 0) do
    prev = Process.get(@scope_key, :unset)
    Process.put(@scope_key, formatter)

    try do
      fun.()
    after
      case prev do
        :unset -> Process.delete(@scope_key)
        value -> Process.put(@scope_key, value)
      end
    end
  end

  @doc """
  Wire name an emitted schema key takes: `output_formatter/0` (default `:camel_case`, the
  reference default, shared with the RPC pipeline and error fields) applied to `field`. Mapped
  (`field_names`) names never pass through here: they are final.
  """
  @spec emitted(atom | String.t()) :: String.t()
  def emitted(field), do: compute(field, output_formatter())

  @doc "Compute a formatted name with no override."
  @spec compute(atom | String.t(), formatter) :: String.t()
  def compute(field, formatter) do
    case formatter do
      {_, _} -> call_custom(formatter, field)
      {_, _, _} -> call_custom(formatter, field)
      f when f in [:snake_case, :snake] -> clean(field)
      f when f in [:camel_case, :camel] -> field |> clean() |> camelize(false)
      f when f in [:pascal_case, :pascal] -> field |> clean() |> camelize(true)
      other -> raise ArgumentError, "Unsupported formatter: #{inspect(other)}"
    end
  end

  @doc """
  Shallow key formatting of a map (port of ash_typescript `FieldFormatter.format_fields/2`):
  every top-level key is formatted with `compute/2` (non-string keys are stringified first);
  values, including nested maps, are left untouched.
  """
  @spec format_fields(map, formatter) :: %{optional(String.t()) => term}
  def format_fields(map, formatter) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {key, value} -> {compute(key, formatter), value} end)

  @config_options ~w(fetch_options custom_fetch headers hook_ctx)a

  @doc """
  RPC function config option names (`fetch_options`, `custom_fetch`, `headers`, `hook_ctx`)
  spelled by `formatter` (default `AshSurface.Config.output_field_formatter/0`), so the
  option names a client reads and the names a signature declares share one spelling.
  """
  @spec config_options(formatter | nil) :: %{atom => String.t()}
  def config_options(formatter \\ nil) do
    formatter = formatter || AshSurface.Config.output_field_formatter()
    Map.new(@config_options, &{&1, compute(&1, formatter)})
  end

  # Reference parity (ash_typescript helpers.ex:25-30,73): a trailing `?` is kept (RBS: stripping it
  # made the built-in inverse land on a different atom, `isReady` -> `:is_ready`, not `:is_ready?`).
  defp clean(field), do: to_string(field)

  @doc """
  Validate a formatter. Custom `{Module, :fun}` needs `Module.fun/1`;
  `{Module, :fun, extra}` needs `Module.fun/(1 + length(extra))` (up to 3 extras).
  """
  @spec validate_formatter(term) :: :ok | {:error, term}
  def validate_formatter(f)
      when f in [:camel_case, :snake_case, :pascal_case, :camel, :snake, :pascal],
      do: :ok

  def validate_formatter({m, f}) when is_atom(m) and is_atom(f),
    do: check_exported(m, f, 1, {m, f})

  def validate_formatter({m, f, extra} = fmt) when is_atom(m) and is_atom(f) and is_list(extra) do
    if length(extra) <= 3,
      do: check_exported(m, f, 1 + length(extra), fmt),
      else: {:error, {:invalid_formatter, :too_many_extra_args, fmt}}
  end

  def validate_formatter(other), do: {:error, {:invalid_formatter, :unsupported, other}}

  defp check_exported(m, f, arity, fmt) do
    if Code.ensure_loaded?(m) and function_exported?(m, f, arity),
      do: :ok,
      else: {:error, {:invalid_formatter, {:undefined_function, m, f, arity}, fmt}}
  end

  # No `apply/3` (no_local_do_test): fixed-arity remote captures.
  defp call_custom(formatter, field) do
    case validate_formatter(formatter) do
      :ok -> :ok
      {:error, reason} -> raise ArgumentError, "Unsupported formatter: #{inspect(reason)}"
    end

    result =
      case formatter do
        {m, f} -> Function.capture(m, f, 1).(field)
        {m, f, []} -> Function.capture(m, f, 1).(field)
        {m, f, [a]} -> Function.capture(m, f, 2).(field, a)
        {m, f, [a, b]} -> Function.capture(m, f, 3).(field, a, b)
        {m, f, [a, b, c]} -> Function.capture(m, f, 4).(field, a, b, c)
      end

    if is_binary(result) and result != "" do
      result
    else
      raise ArgumentError,
            "invalid_custom_formatter_result: formatter #{inspect(formatter)} returned " <>
              "#{inspect(result)} for #{inspect(field)}; a custom formatter must return a " <>
              "non-empty binary"
    end
  end

  @doc """
  Parse a client field name to an internal atom. Returns `{:ok, atom}` or
  `:error` when the atom does not already exist. Never creates atoms.

  NOTE: `{:ok, atom}` means only "an atom with that name exists in the VM"
  (e.g. `"password_hash"` resolves if any loaded code mentions it). It is NOT
  an admission check; use `parse_input/3` with the admitted field set.
  Custom `{m, f}` formatters have no inverse here: `parse_input/2` returns
  `:error` for them; `parse_input/3` derives the inverse from the admitted set.
  """
  @spec parse_input(String.t() | atom, formatter) :: {:ok, atom} | :error
  def parse_input(field, _formatter) when is_atom(field), do: {:ok, field}
  def parse_input("", _formatter), do: :error
  def parse_input(field, {_, _}) when is_binary(field), do: :error
  def parse_input(field, {_, _, _}) when is_binary(field), do: :error

  # ash_typescript parity (field_formatting_comprehensive_test): an unsupported built-in
  # formatter raises instead of silently parsing as camel_case.
  def parse_input(field, formatter)
      when is_binary(field) and
             formatter not in [:camel_case, :snake_case, :pascal_case, :camel, :snake, :pascal],
      do: raise(ArgumentError, "Unsupported formatter: #{inspect(formatter)}")

  def parse_input(field, formatter) when is_binary(field) do
    {:ok, String.to_existing_atom(to_internal(field, formatter))}
  rescue
    ArgumentError -> :error
  end

  @doc """
  Admitted-set variant: resolves `field` only against `admitted` (a list of
  atoms), by inverting the formatter over that set (works for custom
  formatters too, and never touches the atom table). `overrides` win verbatim.
  Returns `{:ok, atom}` or `:error` (unknown, or ambiguous within the set).
  """
  @spec parse_input(String.t(), formatter, [atom], map) :: {:ok, atom} | :error
  def parse_input(field, formatter, admitted, overrides \\ %{})

  def parse_input(field, formatter, admitted, overrides)
      when is_binary(field) and field != "" and is_list(admitted) do
    case Enum.uniq(Enum.filter(admitted, &(format(&1, formatter, overrides) == field))) do
      [atom] -> {:ok, atom}
      _ -> :error
    end
  end

  def parse_input(_field, _formatter, _admitted, _overrides), do: :error

  @doc "Split a sort-string prefix (`-`, `+`, `--`, `++`) from the client field."
  @spec parse_sort(String.t()) :: {String.t(), String.t()} | :error
  def parse_sort(str) when is_binary(str) do
    result =
      case Enum.find(@sort_prefixes, &String.starts_with?(str, &1)) do
        nil -> {"", str}
        p -> {p, String.replace_prefix(str, p, "")}
      end

    case result do
      {p, ""} when p != "" -> :error
      ok -> ok
    end
  end

  @doc """
  Build `%{client_string => internal_atom}` for `fields`. Returns
  `{:error, {:collision, client, [atoms]}}` if two fields share a client name.
  """
  @spec client_to_internal([atom], formatter, map) ::
          {:ok, %{String.t() => atom}}
          | {:error, {:collision, String.t(), [atom]} | {:not_invertible, term, String.t()}}
  def client_to_internal(fields, formatter, overrides \\ %{}) do
    groups = Enum.group_by(fields, &format(&1, formatter, overrides))

    with nil <- Enum.find(Enum.sort(groups), fn {_, v} -> length(Enum.uniq(v)) > 1 end),
         nil <-
           Enum.find_value(fields, fn f ->
             case format_checked(f, formatter, overrides) do
               {:error, _} = e -> e
               _ -> nil
             end
           end) do
      {:ok, Map.new(groups, fn {c, [a | _]} -> {c, a} end)}
    else
      {:error, _} = e -> e
      {client, atoms} -> {:error, {:collision, client, Enum.uniq(atoms)}}
    end
  end

  @doc """
  Forward-path collision/invertibility check for built-in formatters: the
  client name must map back to the same internal name, otherwise two
  distinct fields could share one client spelling (`a__b` / `a_b`).
  Custom formatters need no inverse (admitted-set `parse_input/4`).
  """
  @spec format_checked(atom | String.t(), formatter, map) ::
          {:ok, String.t()} | {:error, {:not_invertible, term, String.t()}}
  def format_checked(field, formatter, overrides \\ %{}) do
    client = format(field, formatter, overrides)

    cond do
      is_atom(field) and is_map_key(overrides, field) -> {:ok, client}
      match?({_, _}, formatter) or match?({_, _, _}, formatter) -> {:ok, client}
      to_internal(client, formatter) == clean(field) -> {:ok, client}
      true -> {:error, {:not_invertible, field, client}}
    end
  end

  @doc """
  Client name of `field` on `resource` (port of ash_typescript
  `FieldFormatter.format_field_for_client/3`). Precedence: the module-level
  `typescript_field_names/0` callback (fields it does not list fall through to the
  formatter, never to the `field_names` option), then the resource's persisted
  `surface` mapping, then the plain formatter.
  """
  @spec format_field_for_client(atom, module, formatter) :: String.t()
  def format_field_for_client(field, resource, formatter) do
    Code.ensure_loaded(resource)

    if function_exported?(resource, :typescript_field_names, 0) or surface?(resource),
      do: wire(resource, field, formatter: formatter),
      else: compute(field, formatter)
  end

  @doc """
  Wire (client) name of resource field `name`. Precedence: module-level
  `typescript_field_names/0`, the resource `field_names` option (both verbatim), then the
  configured output formatter (`emitted/1`; `formatter:` overrides it). Every emitted object key (fields, filter and
  sort keys, calculations, relationships, identity keys) routes through this one function.
  """
  @spec wire(module | nil, atom | String.t(), keyword) :: String.t()
  def wire(resource, name, opts \\ []) do
    key = to_key(name)

    case {override(resource, key), Keyword.fetch(opts, :formatter)} do
      {{:ok, wire}, _} -> wire
      {:error, {:ok, formatter}} -> compute(name, formatter)
      {:error, :error} -> emitted(name)
    end
  end

  @doc """
  Wire name of argument `name` of `action`: the resource `argument_names` entry for the
  action (verbatim), then `field_names` / `typescript_field_names` (an accepted attribute),
  then the formatter.
  """
  @spec wire_argument(module | nil, atom, atom | String.t(), keyword) :: String.t()
  def wire_argument(resource, action, name, opts \\ []) do
    key = to_key(name)

    with true <- surface?(resource),
         args when is_list(args) or is_map(args) <-
           AshSurface.Resource.Info.argument_names(resource),
         per_action when is_list(per_action) or is_map(per_action) <-
           args |> Map.new() |> Map.get(action),
         {:ok, wire} <- Map.new(per_action) |> Map.fetch(key) do
      to_string(wire)
    else
      _ -> wire(resource, name, opts)
    end
  end

  @doc """
  Wire-name table for `fields` of `resource`: `{:ok, %{wire => internal_atom}}` (the inverse
  map that lets server-side names round-trip) or the typed refusal
  `{:error, {:field_name_collision, resource, wire, [internal]}}` when two fields share one
  client spelling. `wire_fun` defaults to `wire/3`.
  """
  @spec wire_inverse(module | nil, [atom], (atom -> String.t())) ::
          {:ok, %{String.t() => atom}}
          | {:error, {:field_name_collision, term, String.t(), [atom]}}
  def wire_inverse(resource, fields, wire_fun \\ nil) do
    wire_fun = wire_fun || (&wire(resource, &1))
    groups = fields |> Enum.uniq() |> Enum.group_by(wire_fun)

    case Enum.find(Enum.sort(groups), fn {_, atoms} -> length(atoms) > 1 end) do
      nil -> {:ok, Map.new(groups, fn {w, [a]} -> {w, a} end)}
      {w, atoms} -> {:error, {:field_name_collision, resource, w, Enum.sort(atoms)}}
    end
  end

  @doc """
  Inverse wire-name tables for one action, JSON-isomorphic (`%{"fields" => %{wire => internal},
  "arguments" => %{wire => internal}}`): `fields` covers the resource's public attributes,
  calculations, aggregates and relationships; `arguments` the action's inputs. A client
  spelling shared by two members of one table is the typed refusal
  `{:error, {:field_name_collision, resource, wire, [internal]}}`.
  """
  @spec action_inverse(module | nil, atom, [String.t() | atom]) ::
          {:ok, %{String.t() => %{String.t() => String.t()}}} | {:error, term}
  def action_inverse(resource, action_name, input_names) do
    fields =
      if surface_or_resource?(resource) do
        Enum.map(Ash.Resource.Info.public_attributes(resource), & &1.name) ++
          Enum.map(Ash.Resource.Info.public_calculations(resource), & &1.name) ++
          Enum.map(Ash.Resource.Info.public_aggregates(resource), & &1.name) ++
          Enum.map(Ash.Resource.Info.public_relationships(resource), & &1.name)
      else
        []
      end

    inputs = Enum.map(input_names, &to_key/1)

    with {:ok, f} <- wire_inverse(resource, fields),
         {:ok, a} <- wire_inverse(resource, inputs, &wire_argument(resource, action_name, &1)) do
      {:ok, %{"fields" => stringify_values(f), "arguments" => stringify_values(a)}}
    end
  end

  defp stringify_values(map), do: Map.new(map, fn {k, v} -> {k, to_string(v)} end)

  defp surface_or_resource?(resource),
    do:
      is_atom(resource) and not is_nil(resource) and Code.ensure_loaded?(resource) and
        function_exported?(resource, :spark_is, 0) and Ash.Resource.Info.resource?(resource)

  defp to_key(name) when is_atom(name), do: name

  defp to_key(name) when is_binary(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> name
  end

  defp surface?(resource),
    do:
      is_atom(resource) and not is_nil(resource) and Code.ensure_loaded?(resource) and
        function_exported?(resource, :spark_is, 0) and Ash.Resource.Info.resource?(resource) and
        AshSurface.Resource in Spark.extensions(resource)

  # ONE precedence kernel (matches ash_typescript FieldFormatter.compute_field_for_client):
  # a module exporting `typescript_field_names/0` is authoritative; a field it does not list
  # falls to the formatter, NEVER to the `field_names` DSL option. Only without the callback
  # does the resource `field_names` option apply. `format_field_for_client/3` delegates here.
  defp override(resource, key) when is_atom(resource) and not is_nil(resource) do
    Code.ensure_loaded(resource)

    cond do
      function_exported?(resource, :typescript_field_names, 0) ->
        callback_override(resource, key)

      surface?(resource) ->
        with names when is_list(names) or is_map(names) <-
               AshSurface.Resource.Info.field_names(resource),
             {:ok, wire} <- names |> Map.new() |> Map.fetch(key) do
          {:ok, to_string(wire)}
        else
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp override(_resource, _key), do: :error

  defp callback_override(resource, key) do
    if function_exported?(resource, :typescript_field_names, 0) do
      case resource.typescript_field_names() |> Map.new() |> Map.fetch(key) do
        {:ok, wire} -> {:ok, to_string(wire)}
        :error -> :error
      end
    else
      :error
    end
  end

  defp to_internal(s, f) when f in [:snake_case, :snake], do: s

  defp to_internal(s, _) do
    s
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.downcase()
  end

  # Reference rule: `Macro.camelize/1` then lowercase the first character (pascal: no lowering).
  # Sole deviation (KD-13): leading underscores are preserved, so `_x` stays distinct from `x`
  # and round-trips; interior non-injectivity is caught by format_checked/3 and EmittedKeys.
  defp camelize(s, pascal?) do
    rest = String.trim_leading(s, "_")
    lead = String.duplicate("_", String.length(s) - String.length(rest))
    camel = Macro.camelize(rest)

    case {pascal?, String.split_at(camel, 1)} do
      {true, _} -> lead <> camel
      {false, {h, t}} -> lead <> String.downcase(h) <> t
    end
  end
end
