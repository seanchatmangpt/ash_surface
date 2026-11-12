defmodule AshSurface.Compiler.RecordSchema do
  @moduledoc """
  Per-resource record Zod schema (port of ash_typescript `generate_unified_resource_schema`,
  Zod 4 only, no `.ts` emitted): the shape of one record of `resource` as a client receives it.

  Fields, under the resource's `field_names` wire names (verbatim; unmapped fields keep the
  Ash name):

    * public attributes: required key, `.nullable()` when `allow_nil?`
    * public argument-less calculations and public aggregates: optional keys (loaded on demand),
      typed from the Ash return/aggregate type
    * public relationships: optional keys holding a record reference
      (`z.record(z.string(), z.unknown())`, an array for to-many); the selection schema owns the
      nested shape, so a reference never inlines (no cycles, no size blowup)

  Embedded resources reachable from a field are rendered through
  `EmbeddedSchema.render_program/2` (named declarations for cyclic or shared ones, mapped
  names applied), so the result is `ZodGuard.admit/2`-admissible.

  `render/2` returns `{:ok, %{declarations: [{id, expr}], expression: expr}}` or a typed
  `{:error, reason}` (`:not_a_resource`, or an `EmbeddedSchema` refusal).
  """

  alias AshSurface.Compiler.{EmbeddedSchema, TypeFacts}

  @spec render(module(), keyword()) ::
          {:ok, %{declarations: [{String.t(), String.t()}], expression: String.t()}}
          | {:error, term()}
  def render(resource, opts \\ []) when is_atom(resource) do
    if Ash.Resource.Info.resource?(resource) do
      with :ok <- check_collisions(resource) do
        fields = fields(resource)
        definition = %{"type" => %{"kind" => "typed_map", "fields" => fields}}

        EmbeddedSchema.render_program(
          definition,
          Keyword.put(opts, :resources, TypeFacts.embedded_resources([definition]))
        )
      end
    else
      {:error, {:not_a_resource, resource}}
    end
  end

  @doc "JS source `const <Name><suffix> = ...;` including the named declarations."
  @spec source(module(), %{declarations: list(), expression: String.t()}, keyword()) ::
          String.t()
  def source(resource, %{expression: expression} = program, opts \\ []) do
    suffix = Keyword.get(opts, :schema_suffix) || AshSurface.Config.zod_schema_suffix()

    EmbeddedSchema.declarations_source(program) <>
      "const #{identifier(resource)}#{suffix} = #{expression};\n"
  end

  @doc "The record schema's identifier stem: the resource `type_name`, else its last module segment."
  @spec identifier(module()) :: String.t()
  def identifier(resource) do
    type_name = if surface?(resource), do: AshSurface.Resource.Info.type_name(resource)
    type_name || resource |> Module.split() |> List.last()
  end

  # Names are pre-formatted by `wire_name/2`, so the embedded renderer only sees equal keys:
  # collide on the RAW Ash names here (distinct names, one emitted key -> typed refusal).
  defp check_collisions(resource) do
    names =
      Enum.map(Ash.Resource.Info.public_attributes(resource), & &1.name) ++
        (for calc <- Ash.Resource.Info.public_calculations(resource),
             Map.get(calc, :field?) != false,
             calc.arguments == [],
             do: calc.name) ++
        Enum.map(Ash.Resource.Info.public_aggregates(resource), & &1.name) ++
        Enum.map(Ash.Resource.Info.public_relationships(resource), & &1.name)

    names
    |> Enum.map(&{&1, wire_name(resource, &1)})
    |> AshSurface.Compiler.EmittedKeys.check({:record, resource})
  end

  defp fields(resource) do
    attributes(resource) ++
      calculations(resource) ++ aggregates(resource) ++ relationships(resource)
  end

  defp attributes(resource) do
    for attr <- Ash.Resource.Info.public_attributes(resource) do
      field(resource, attr.name, attr.type, attr.constraints, attr.allow_nil? != false, false)
    end
  end

  defp calculations(resource) do
    for calc <- Ash.Resource.Info.public_calculations(resource),
        Map.get(calc, :field?) != false,
        calc.arguments == [] do
      field(resource, calc.name, calc.type, calc.constraints, calc.allow_nil? != false, true)
    end
  end

  defp aggregates(resource) do
    for agg <- Ash.Resource.Info.public_aggregates(resource) do
      case Ash.Query.Aggregate.aggregate_type(resource, agg) do
        {:ok, type, constraints} ->
          field(resource, agg.name, type, constraints, agg.kind != :count, true)

        _ ->
          field(resource, agg.name, Ash.Type.Term, [], true, true)
      end
    end
  end

  # A relationship is a record reference: a typed map without fields, which the embedded
  # renderer emits as the open record (`z.record(z.string(), z.unknown())`).
  defp relationships(resource) do
    for rel <- Ash.Resource.Info.public_relationships(resource) do
      many? = rel.cardinality == :many
      record = %{"kind" => "typed_map", "fields" => []}

      type =
        if many?,
          do: %{"kind" => "array", "items" => %{"type" => record}},
          else: record

      mark_wire(
        %{
          "name" => wire_name(resource, rel.name),
          "type" => type,
          "allow_nil?" => not many?,
          "omittable" => true
        },
        resource,
        rel.name
      )
    end
  end

  defp field(resource, name, type, constraints, allow_nil?, omittable?) do
    type
    |> TypeFacts.analyze(constraints || [])
    |> Map.fetch!(:definition)
    |> Map.merge(%{"name" => wire_name(resource, name), "allow_nil?" => allow_nil?})
    |> mark_wire(resource, name)
    |> then(&if(omittable?, do: Map.put(&1, "omittable", true), else: &1))
  end

  # Mapped names are final (`"wire" => true`); the rest take the configured output formatter.
  defp wire_name(resource, name), do: mapped(resource, name) || AshSurface.FieldName.emitted(name)

  defp mapped(resource, name) do
    if surface?(resource),
      do: resource |> AshSurface.Resource.Info.field_names() |> lookup(name)
  end

  # Every name `wire_name/2` returns is final (mapped verbatim, or formatted exactly once
  # there): the embedded renderer must not re-apply the formatter (pascal is not idempotent).
  defp mark_wire(definition, _resource, _name), do: Map.put(definition, "wire", true)

  defp lookup(names, name) when is_list(names) or is_map(names),
    do: names |> Map.new() |> Map.get(name) |> then(&if(&1, do: to_string(&1)))

  defp lookup(_names, _name), do: nil

  defp surface?(resource), do: AshSurface.Resource in Spark.extensions(resource)
end
