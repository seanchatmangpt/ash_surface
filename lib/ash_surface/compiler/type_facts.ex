defmodule AshSurface.Compiler.TypeFacts do
  @moduledoc """
  The ONE type-definition builder for the compiler (census D-03).

  Turns an Ash type (raw `{type, constraints}` or an
  `Ash.Info.Manifest.Type`) into the string-keyed definition map that
  `ZodType`, `EmbeddedSchema` and `UnionSchema` consume:

      %{
        "type" => %{
          "kind" => "string" | "array" | "enum" | "union" | "embedded_resource" | ...,
          "items" => definition,              # arrays (recursive)
          "values" => [String.t()],           # enum
          "members" => [%{"name", "type" => definition, "tag", "tag_value"}],
          "fields" => [%{"name", "type", "constraints", "allow_nil?", "omittable"}],
          "instance_of" => String.t(),        # struct / resource references
          "resource?" => boolean(),           # instance_of names a resource
          "resource" => String.t(),           # embedded resource / resource name
          "module" => String.t()
        },
        "constraints" => %{"min_length" => 1, "match" => "src", "match_flags" => "i", ...},
        "subtype_of" => "string",             # NewType only: the base kind
        "subtype_constraints" => %{...}
      }

  Named type modules (`Ash.Type.Enum`, `Ash.Type.NewType`) are expanded here
  through `Ash.Info.Manifest.Generator.TypeResolver`, so the manifest's
  `:type_ref` and the raw `{type, constraints}` path produce the same facts.
  Embedded resources are carried by name; `embedded_resources/1` resolves the
  field lists for the names reachable from a set of definitions (cycle-safe:
  each name is expanded once).

  Constraint vocabulary (shared with `AshTruth`): only `min max min_length
  max_length match one_of greater_than less_than allow_empty? items` are
  admitted. A regex (`%Regex{}` or Spark's `{Spark.Regex, :cache, ..}` tuple)
  is normalized to its source string, with `match_flags` carrying the `i m s`
  flags.
  """

  alias Ash.Info.Manifest.Generator.TypeResolver
  alias Ash.Info.Manifest.Type

  @admitted_constraint_keys [
    :min,
    :max,
    :min_length,
    :max_length,
    :match,
    :match_flags,
    :one_of,
    :greater_than,
    :less_than,
    :allow_empty?,
    :items
  ]

  @doc "The admitted constraint keys (atoms)."
  @spec admitted_constraint_keys() :: [atom()]
  def admitted_constraint_keys, do: @admitted_constraint_keys

  @type analysis :: %{
          definition: map(),
          kind: String.t(),
          declared_constraints: map(),
          subtype_of: String.t() | nil,
          subtype_constraints: map()
        }

  ## ---------------------------------------------------------------- entry

  @doc "Analyzes a raw Ash type + constraints."
  @spec analyze(term(), term()) :: analysis()
  def analyze(type, constraints \\ []) do
    type |> TypeResolver.resolve(constraints || []) |> analyze_type()
  end

  @doc "Analyzes a manifest type (`nil` is an unknown type)."
  @spec analyze_type(Type.t() | nil) :: analysis()
  def analyze_type(nil), do: analyze_type(%Type{kind: :unknown, constraints: []})

  def analyze_type(%Type{} = type) do
    definition = definition(type)
    {subtype_of, subtype_constraints} = subtype(type, definition)

    %{
      definition: definition,
      kind: definition["type"]["kind"],
      declared_constraints: constraints(type.constraints),
      subtype_of: subtype_of,
      subtype_constraints: subtype_constraints
    }
  end

  @doc "The kind string of a raw Ash type, or `\"unknown\"`."
  @spec kind(term(), term()) :: String.t()
  def kind(type, constraints \\ []), do: analyze(type, constraints).kind

  @doc """
  Display name of an Ash type for the `ash` truth section: Ash's short name
  when registered, else `inspect/1` (so `{:array, t}` stays the inspected tuple).
  """
  @spec type_name(term()) :: String.t()
  def type_name(type) do
    case List.keyfind(Ash.Type.short_names(), type, 1) do
      {name, ^type} -> Atom.to_string(name)
      nil -> inspect(type)
    end
  end

  ## --------------------------------------------------------- constraints

  @doc """
  Normalizes constraints to an atom-keyed map of admitted keys (IR style).
  Regexes become source strings plus `:match_flags`.
  """
  @spec constraints(term()) :: map()
  def constraints(nil), do: %{}

  def constraints(constraints) when is_list(constraints) do
    if Keyword.keyword?(constraints), do: constraints |> Map.new() |> constraints(), else: %{}
  end

  def constraints(constraints) when is_map(constraints) do
    constraints
    |> Enum.flat_map(fn {key, value} -> constraint(to_key(key), value) end)
    |> Map.new()
  end

  def constraints(_), do: %{}

  defp to_key(key) when is_atom(key), do: key

  defp to_key(key) when is_binary(key) do
    Enum.find(@admitted_constraint_keys, :unknown, &(Atom.to_string(&1) == key))
  end

  defp to_key(_), do: :unknown

  defp constraint(:match, value) do
    case regex_parts(value) do
      {source, flags} when flags in ["", nil] -> [match: source]
      {source, flags} -> [match: source, match_flags: flags]
      nil -> []
    end
  end

  defp constraint(:match_flags, value) when is_binary(value), do: [match_flags: value]
  defp constraint(:items, value), do: [items: constraints(value)]
  defp constraint(key, value) when key in @admitted_constraint_keys, do: [{key, json_safe(value)}]
  defp constraint(_key, _value), do: []

  defp json_safe(%Decimal{} = d), do: Decimal.to_string(d)
  defp json_safe(%Regex{} = r), do: r.source
  defp json_safe(value), do: value

  defp regex_parts({Spark.Regex, :cache, [source, opts]}) when is_binary(source),
    do: {source, flags(opts)}

  defp regex_parts(%Regex{source: source} = regex), do: {source, flags(Regex.opts(regex))}
  defp regex_parts(source) when is_binary(source), do: {source, ""}
  defp regex_parts(_), do: nil

  defp flags(opts) when is_binary(opts) do
    opts
    |> String.graphemes()
    |> Enum.filter(&(&1 in ~w(i m s)))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join()
  end

  defp flags(opts) when is_list(opts) do
    opts
    |> Enum.flat_map(fn
      :caseless -> ["i"]
      :multiline -> ["m"]
      :dotall -> ["s"]
      _ -> []
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join()
  end

  defp flags(_), do: ""

  @doc "String-keyed form of `constraints/1` (the zod definition vocabulary)."
  @spec stringify_constraints(map()) :: map()
  def stringify_constraints(constraints) when is_map(constraints) do
    Map.new(constraints, fn
      {:items, value} -> {"items", stringify_constraints(value)}
      {:one_of, values} when is_list(values) -> {"one_of", Enum.map(values, &string_value/1)}
      {key, value} -> {Atom.to_string(key), value}
    end)
  end

  defp string_value(value) when is_atom(value) and not is_boolean(value) and not is_nil(value),
    do: Atom.to_string(value)

  defp string_value(value), do: value

  ## ---------------------------------------------------------- definitions

  defp definition(%Type{} = type) do
    type = expand(type)
    kind = kind_string(type)
    cons = type.constraints |> constraints() |> Map.delete(:items) |> stringify_constraints()

    base = %{"type" => type_map(type, kind), "constraints" => cons}

    case subtype(type, base) do
      {nil, _} ->
        base

      {sub, sub_cons} ->
        base
        |> Map.put("subtype_of", sub)
        |> Map.put("subtype_constraints", stringify_constraints(sub_cons))
    end
  end

  # A named reference is expanded; a NewType keeps the memo of its base kind.
  defp expand(%Type{kind: :type_ref, module: module, constraints: cons} = ref) do
    cons = cons || []

    cond do
      Ash.Type.NewType.new_type?(module) ->
        {sub, merged} = TypeResolver.unwrap_new_type(module, cons)
        inner = sub |> TypeResolver.resolve(merged) |> expand()
        custom = Map.put(inner.custom || %{}, :newtype_of, true)

        custom =
          case newtype_field_names(module) do
            nil -> custom
            names -> Map.put(custom, :field_names, names)
          end

        %{inner | custom: custom}

      true ->
        resolved = TypeResolver.resolve_definition(module)
        resolved = if resolved.kind == :type_ref, do: %{ref | kind: :unknown}, else: resolved
        %{resolved | constraints: Keyword.merge(resolved.constraints || [], cons)}
    end
  end

  defp expand(%Type{} = type), do: type

  # Type-level wire-name map (`typescript_field_names/0` callback on a NewType):
  # `%{"field_atom_string" => "wireName"}`; nil when absent or malformed.
  defp newtype_field_names(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :typescript_field_names, 0) do
      case module.typescript_field_names() do
        names when is_list(names) or is_map(names) ->
          if Enum.all?(names, &match?({k, v} when is_atom(k) and is_binary(v), &1)),
            do: Map.new(names, fn {k, v} -> {Atom.to_string(k), v} end),
            else: nil

        _ ->
          nil
      end
    end
  end

  defp subtype(%Type{kind: _, custom: %{newtype_of: true}} = type, _),
    do: {kind_string(type), constraints(type.constraints)}

  defp subtype(%Type{kind: :type_ref} = type, _definition), do: subtype(expand(type), nil)
  defp subtype(%Type{}, _definition), do: {nil, %{}}

  defp kind_string(%Type{kind: kind}) when kind in [nil, :type_ref], do: "unknown"

  # Ash's resolver folds `Ash.Type.Vector` into `:term`; ZodType has a dedicated "vector"
  # kind (list of numbers on the wire). Likewise `AshPostgres.Ltree` (no ash_postgres dep:
  # matched by module name) carries the "ltree" kind.
  defp kind_string(%Type{module: Ash.Type.Vector}), do: "vector"
  defp kind_string(%Type{module: AshPostgres.Ltree}), do: "ltree"
  defp kind_string(%Type{kind: kind}), do: Atom.to_string(kind)

  defp type_map(%Type{kind: :array} = type, _kind) do
    items = if type.item_type, do: definition(type.item_type), else: nil
    put_new(%{"kind" => "array"}, "items", items)
  end

  defp type_map(%Type{kind: :enum} = type, kind) do
    values = (type.values || []) |> Enum.map(&string_value/1)
    %{"kind" => kind, "values" => values} |> put_module(type)
  end

  defp type_map(%Type{kind: :union} = type, kind) do
    members =
      Enum.map(type.members || [], fn member ->
        %{"name" => to_string(member.name), "type" => definition(member.type)}
        |> put_new("tag", member |> Map.get(:tag) |> tag_string())
        |> put_new("tag_value", member |> Map.get(:tag_value) |> tag_string())
      end)

    %{"kind" => kind, "members" => members}
  end

  defp type_map(%Type{kind: :embedded_resource} = type, kind) do
    module = type.resource_module || type.instance_of

    %{"kind" => kind, "resource" => inspect(module), "module" => inspect(module)}
    |> put_new("instance_of", type.instance_of && inspect(type.instance_of))
    |> Map.put("resource?", true)
  end

  defp type_map(%Type{kind: :resource} = type, kind) do
    module = type.resource_module || type.instance_of

    %{
      "kind" => kind,
      "resource" => inspect(module),
      "instance_of" => inspect(module),
      "resource?" => true
    }
  end

  defp type_map(%Type{kind: k} = type, kind) when k in [:struct, :map, :keyword] do
    %{"kind" => kind}
    |> put_new("fields", fields(type.fields))
    |> put_new("field_names", Map.get(type.custom || %{}, :field_names))
    |> put_new("instance_of", type.instance_of && inspect(type.instance_of))
    |> then(&if(k == :struct and type.instance_of, do: Map.put(&1, "resource?", false), else: &1))
  end

  defp type_map(%Type{kind: :tuple} = type, kind) do
    %{"kind" => kind} |> put_new("fields", fields(type.element_types))
  end

  defp type_map(%Type{} = type, kind), do: put_module(%{"kind" => kind}, type)

  defp put_module(map, %Type{module: module}) when is_atom(module) and not is_nil(module),
    do: Map.put(map, "module", inspect(module))

  defp put_module(map, _), do: map

  defp fields(nil), do: nil
  defp fields([]), do: nil

  defp fields(fields) do
    Enum.map(fields, fn field ->
      allow_nil? = Map.get(field, :allow_nil?, true) != false

      field.type
      |> definition()
      |> Map.merge(%{"name" => to_string(field.name), "allow_nil?" => allow_nil?})
      |> then(&if(allow_nil?, do: Map.put(&1, "omittable", true), else: &1))
    end)
  end

  defp tag_string(nil), do: nil
  defp tag_string(value) when is_boolean(value) or is_number(value) or is_binary(value), do: value
  defp tag_string(value) when is_atom(value), do: Atom.to_string(value)
  defp tag_string(value), do: to_string(value)

  defp put_new(map, _key, nil), do: map
  defp put_new(map, key, value), do: Map.put(map, key, value)

  ## ------------------------------------------------------ embedded closure

  @doc """
  Field lists for every embedded resource name reachable from `definitions`,
  as `%{"My.Embedded" => [field, ...]}` (the `EmbeddedSchema` `:resources`
  option). Each name is expanded once; nested embedded references stay by
  name, so self-referential embedded resources terminate (and surface as the
  builder's typed `cyclic_schema` refusal).
  """
  @spec embedded_resources([map()]) :: %{optional(String.t()) => [map()]}
  def embedded_resources(definitions) when is_list(definitions) do
    Enum.reduce(definitions, %{}, &collect(&1, &2))
  end

  defp collect(%{"type" => %{} = type}, acc) do
    acc =
      case type do
        %{"kind" => "embedded_resource", "module" => name} ->
          if Map.has_key?(acc, name), do: acc, else: expand_embedded(name, acc)

        # Struct argument `instance_of: Resource` (ash_typescript struct-argument rule):
        # per-field object over the resource's public attributes.
        %{"kind" => "resource", "instance_of" => name} when is_binary(name) ->
          if Map.has_key?(acc, name), do: acc, else: expand_embedded(name, acc, false)

        _ ->
          acc
      end

    acc = if type["items"], do: collect(type["items"], acc), else: acc
    acc = Enum.reduce(type["members"] || [], acc, &collect(Map.get(&1, "type"), &2))
    Enum.reduce(type["fields"] || [], acc, &collect(&1, &2))
  end

  defp collect(_, acc), do: acc

  # The embedded resource's `field_names` mapping (verbatim wire names), `%{atom => binary}`.
  defp resource_field_names(module) do
    with true <- AshSurface.Resource in Spark.extensions(module),
         names when is_list(names) or is_map(names) <-
           AshSurface.Resource.Info.field_names(module) do
      Map.new(names, fn {k, v} -> {k, to_string(v)} end)
    else
      _ -> %{}
    end
  end

  defp expand_embedded(name, acc, writable_only? \\ true) do
    module = String.to_existing_atom("Elixir." <> name)
    acc = Map.put(acc, name, [])

    renames = resource_field_names(module)

    fields =
      module
      |> Ash.Resource.Info.public_attributes()
      |> Enum.filter(&(not writable_only? or &1.writable? != false))
      |> Enum.sort_by(&to_string(&1.name))
      |> Enum.map(fn attr ->
        omittable? = attr.allow_nil? != false or not is_nil(attr.default)

        attr.type
        |> TypeResolver.resolve(attr.constraints || [])
        |> definition()
        |> Map.merge(%{
          "name" => Map.get(renames, attr.name, to_string(attr.name)),
          "allow_nil?" => attr.allow_nil? != false
        })
        |> then(&if(Map.has_key?(renames, attr.name), do: Map.put(&1, "wire", true), else: &1))
        |> then(&if(omittable?, do: Map.put(&1, "omittable", true), else: &1))
      end)

    acc = Map.put(acc, name, fields)
    Enum.reduce(fields, acc, &collect(&1, &2))
  end
end
