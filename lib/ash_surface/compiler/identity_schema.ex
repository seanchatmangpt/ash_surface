# Lane L23 (v26.11.11): get-by/identities + multitenancy parity with
# ash_typescript. Their `get?`/`get_by` and `require_tenant_parameters`
# semantics, made executable as pure zod renderers: an identity lookup is a
# parseable admission (wrong identity fields fail), and a required tenant is
# a min(1) string that rejects the empty tenant.
defmodule AshSurface.Compiler.IdentitySchema do
  @moduledoc """
  Identity (get_by) and tenant schema renderers.

  Parity subject: ash_typescript's `get?`/`get_by` identity admission and
  `require_tenant_parameters`. Both are made executable here as pure zod
  fragments — no discovery, no Ash introspection (the no-second-discovery
  contract this compiler family holds).

  `render_get_schema/2` turns each admitted identity into a
  `z.object({ ... }).strict()` over its key fragments, so a get_by call is a
  parseable admission: fields outside the identity (or of the wrong shape)
  fail parse instead of silently selecting nothing.

  `render_tenant_schema/0` is require_tenant_parameters made executable:
  a tenant parameter that parses must be a non-empty string.
  """

  alias AshSurface.Compiler.{ObjectMode, QuerySchema, ZodType}
  alias AshSurface.Config

  # Identity filters are scalar-only (ash_typescript pipeline.ex:1212-1420):
  # a key whose kind is structured cannot be an equality lookup value.
  @non_scalar_kinds ~w(map array union embedded struct keyword tuple resource embedded_resource typed_struct typed_map)

  @tenant_fragment "z.string().min(1)"

  @doc """
  Renders a get-by schema per admitted identity.

  Identities follow the serialized manifest idioms (string-keyed):

      %{
        "name" => "email",
        "keys" => [%{"name" => "email", "type" => %{"kind" => "string"}}]
      }

  `primary_key` is the list of primary-key attribute names; an identity
  whose keys are exactly that set is admitted under the name
  `"primary_key"` regardless of its declared name (the get-by spelling of
  `get?` by primary key).

  Returns `{:ok, %{identity_name => schema_string}}`, or
  `{:error, :no_admitted_identities}` when the identity list is empty or
  no identity is structurally admissible.
  """
  @spec render_get_schema(term(), term()) ::
          {:ok, %{optional(String.t()) => String.t()}}
          | {:error,
             :no_admitted_identities | {:identity_name_collision, String.t(), [String.t()]}}
  def render_get_schema(identities, primary_key),
    do: render_get_schema(identities, primary_key, [])

  @doc """
  As `render_get_schema/2`; an explicit `:object_mode` opt (`:strip | :strict | :passthrough`,
  see `AshSurface.Compiler.ObjectMode`) replaces the default `.strict()` object suffix.
  """
  @spec render_get_schema(term(), term(), keyword()) ::
          {:ok, %{optional(String.t()) => String.t()}}
          | {:error,
             :no_admitted_identities
             | {:identity_name_collision, String.t(), [String.t()]}
             | {:identity_key_denied, String.t(), String.t()}}
  def render_get_schema(identities, primary_key, opts)
      when is_list(identities) and is_list(primary_key) do
    case denied_key(identities) do
      nil -> do_render_get_schema(identities, primary_key, opts)
      {identity, key} -> {:error, {:identity_key_denied, identity, key}}
    end
  end

  def render_get_schema(_identities, _primary_key, _opts), do: {:error, :no_admitted_identities}

  # ZodGuard denies `__proto__` as an object key; refuse up front, typed.
  defp denied_key(identities) do
    Enum.find_value(identities, fn
      %{"name" => name, "keys" => keys} when is_list(keys) ->
        Enum.find_value(keys, fn
          %{"name" => "__proto__"} -> {to_string(name), "__proto__"}
          _ -> nil
        end)

      _ ->
        nil
    end)
  end

  defp do_render_get_schema(identities, primary_key, opts) do
    pk = Enum.map(primary_key, &to_string/1)

    admitted =
      Enum.flat_map(identities, fn identity ->
        case admitted_identity(identity, pk, opts) do
          {:ok, name, declared, schema} -> [{name, declared, schema}]
          :skip -> []
        end
      end)

    collisions =
      admitted
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.filter(fn {_name, declared} -> length(declared) > 1 end)
      |> Enum.sort()

    cond do
      admitted == [] ->
        {:error, :no_admitted_identities}

      collisions != [] ->
        [{name, declared} | _] = collisions
        {:error, {:identity_name_collision, name, Enum.sort(declared)}}

      true ->
        {:ok, Map.new(admitted, fn {n, _d, z} -> {n, z} end)}
    end
  end

  @doc """
  Renders the tenant parameter schema (require_tenant_parameters made
  executable): a tenant that parses is a non-empty string.
  """
  @spec render_tenant_schema() :: {:ok, String.t()}
  def render_tenant_schema, do: {:ok, @tenant_fragment}

  @doc """
  Renders the tenant parameter from a multitenancy fact
  (`%{"strategy" => "attribute" | "context" | nil, "global?" => bool,
  "require_tenant_parameters" => bool}`; atom keys and atom strategies
  accepted). Mirrors ash_typescript `requires_tenant?` (strategy in
  attribute/context and not global) and `requires_tenant_parameter?`
  (additionally `require_tenant_parameters`, default per Config, false).

    * `{:ok, "z.string().min(1)"}` - tenant required
    * `{:ok, "z.string().min(1).optional()"}` - tenant-bearing resource whose
      parameter is not required by config
    * `{:ok, nil}` - no tenant parameter (no multitenancy / global)
  """
  @spec render_tenant_schema(term()) :: {:ok, String.t() | nil}
  def render_tenant_schema(mt), do: render_tenant_schema(mt, Config.require_tenant_parameters())

  @doc """
  As `render_tenant_schema/1` with an explicit `require_tenant_parameters` default; a value
  in the multitenancy fact wins. The `/1` default is `Config.require_tenant_parameters/0`
  (false, ash_typescript rpc.ex:301): a tenant-bearing resource's parameter is optional
  unless required by config or fact.
  """
  @spec render_tenant_schema(term(), boolean()) :: {:ok, String.t() | nil}
  def render_tenant_schema(%{} = mt, default_require?) do
    strategy = fact(mt, "strategy") |> to_string_or_nil()
    global? = fact(mt, "global?") == true

    require_param? =
      case fact(mt, "require_tenant_parameters") do
        nil -> default_require? == true
        v -> v == true
      end

    cond do
      strategy not in ["attribute", "context"] or global? -> {:ok, nil}
      require_param? -> {:ok, @tenant_fragment}
      true -> {:ok, @tenant_fragment <> ".optional()"}
    end
  end

  def render_tenant_schema(_, _), do: {:ok, nil}

  defp fact(m, key) do
    case Map.fetch(m, key) do
      {:ok, v} -> v
      :error -> Map.get(m, String.to_existing_atom(key))
    end
  rescue
    ArgumentError -> nil
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(v), do: to_string(v)

  defp admitted_identity(identity, primary_key, opts) do
    with %{"name" => name} when is_binary(name) <- identity,
         %{"keys" => keys} when is_list(keys) <- identity,
         true <- keys != [],
         key_names = Enum.map(keys, & &1["name"]),
         true <- Enum.all?(key_names, &is_binary/1),
         true <- Enum.all?(keys, &typed_key?/1),
         true <- Enum.all?(keys, &scalar_key?/1),
         rendered when is_binary(rendered) <- render_identity_object(keys, opts) do
      {:ok, identity_name(name, key_names, primary_key), name, rendered}
    else
      _ -> :skip
    end
  end

  defp with_mode(zod, opts) do
    case Keyword.fetch(opts, :object_mode) do
      {:ok, m} -> String.replace_suffix(zod, ".strict()", ObjectMode.suffix(m))
      :error -> zod
    end
  end

  defp object_suffix(opts) do
    case Keyword.fetch(opts, :object_mode) do
      {:ok, m} -> ObjectMode.suffix(m)
      :error -> ".strict()"
    end
  end

  defp identity_name(name, key_names, primary_key) do
    if Enum.sort(key_names) == Enum.sort(primary_key) do
      "primary_key"
    else
      name
    end
  end

  # Non-identifier key names are rendered as JSON-quoted property names
  # (injection-safe) instead of being dropped; QuerySchema stays the owner
  # of the all-identifier path.
  defp render_identity_object(keys, opts) do
    pairs = Enum.map(keys, &{&1["name"], key_fragment(&1)})

    if Enum.all?(pairs, fn {n, _} -> Regex.match?(~r/^[A-Za-z_$][A-Za-z0-9_$]*$/, n) end) do
      case QuerySchema.render_get_input_schema(pairs) do
        {:ok, zod} -> with_mode(zod, opts)
        {:error, _} -> nil
      end
    else
      fields =
        pairs
        |> Enum.sort()
        |> Enum.map_join(", ", fn {n, z} -> "#{Jason.encode!(n)}: #{z}" end)

      "z.object({" <> fields <> "})" <> object_suffix(opts)
    end
  end

  # Identity keys are lookup values: always present. allow_nil? maps to
  # `.nullable()` only (never `.optional()`), via the shared ZodType fragment.
  defp key_fragment(%{"type" => %{"kind" => kind}} = key) when is_binary(kind) do
    ZodType.fragment(
      %{
        "type" => key["type"],
        "allow_nil?" => key["allow_nil?"] == true,
        "constraints" => key["constraints"]
      },
      []
    )
  end

  defp key_fragment(_key), do: "z.unknown()"

  defp scalar_key?(%{"type" => %{"kind" => kind}}) when is_binary(kind),
    do: kind not in @non_scalar_kinds

  defp scalar_key?(_), do: false

  defp typed_key?(%{"type" => %{"kind" => kind}}) when is_binary(kind), do: true
  defp typed_key?(_), do: false
end
