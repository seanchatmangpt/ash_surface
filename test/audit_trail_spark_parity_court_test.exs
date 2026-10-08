




defmodule AuditTrail.ResourceParityCourtTest do
  @moduledoc false
  use ExUnit.Case, async: true

  # Fact rows baked in at generation time from the pack ontology
  # (aex:SemanticFact / aex:SurfaceFact). The compiled extension under test is the
  # one this same graph generated -- real collaborators, no doubles.
  @orphan_check [
  ]

  @declared [
    {:"entity", "audit", "AuditTrail.Dsl.Event", "event"},
    {:"entity", "audit", "AuditTrail.Dsl.Projection", "projection"},
    {:"field", "", "AuditTrail.Dsl.Event", "description"},
    {:"field", "", "AuditTrail.Dsl.Event", "name"},
    {:"field", "", "AuditTrail.Dsl.Projection", "attribute"},
    {:"section", "", "", "audit"},
  ]

  test "every implemented fact has a sparkDeclared visibility (closure, audit_trail)" do
    assert @orphan_check == [], """
    spark parity VIOLATION: implemented facts with no sparkDeclared SurfaceFact:

    #{Enum.map_join(@orphan_check, "\n", &"  - #{&1}")}

    (implemented - sparkDeclared must be the empty set; see
    gates/110_spark_completeness.rq and ontology.ttl's closure vocabulary.)
    """
  end

  test "compiled Spark surface carries every declared fact (audit_trail)" do
    fixture = compile_fixture()
    extension = AuditTrail.Resource
    assert extension in Spark.extensions(fixture)

    declared = MapSet.new(@declared)

    compiled =
      extension.sections()
      |> Enum.flat_map(fn section ->
        section_name = Atom.to_string(section.name)
        rows = [{:section, "", "", section_name}]

        entity_rows =
          Enum.flat_map(section.entities || [], fn entity ->
            struct_name = if entity.target, do: inspect(entity.target), else: ""
            field_rows = Enum.map(entity.schema || [], fn {f, _} -> {:field, "", struct_name, Atom.to_string(f)} end)
            arg_rows = Enum.map(entity.args || [], fn a -> {:arg, "", struct_name, Atom.to_string(a)} end)

            oneof_rows =
              Enum.flat_map(entity.schema || [], fn {f, opts} ->
                case opts[:type] do
                  {:one_of, values} -> Enum.map(values, fn v -> {:oneof, "", struct_name, Atom.to_string(v)} end)
                  _ -> []
                end
              end)

            entity_row = [{:entity, section_name, struct_name, Atom.to_string(entity.name)}]
            entity_row ++ field_rows ++ arg_rows ++ oneof_rows
          end)

        sectionfield_rows =
          Enum.map(section.schema || [], fn {f, _} -> {:sectionfield, section_name, "", Atom.to_string(f)} end)

        rows ++ entity_rows ++ sectionfield_rows
      end)
      |> MapSet.new()

    missing = MapSet.difference(declared, compiled)
    assert MapSet.size(missing) == 0, """
    spark parity VIOLATION: declared facts absent from the COMPILED extension surface:

    #{Enum.map_join(missing, "\n", &"  - #{inspect(&1)}")}

    (the compiled extension under test is the one this graph generated --
    introspected via the real Spark.Dsl.Extension sections/0 callback.)
    """
  end

  defp compile_fixture do
    source = """
    defmodule AuditTrail.Resource.ParityFixture do
      use Ash.Resource,
        domain: nil,
        extensions: [AuditTrail.Resource]
    attributes do
        uuid_primary_key :id
      end
    end
    """

    modules = Code.compile_string(source)
    fixture = AuditTrail.Resource.ParityFixture
    assert Enum.any?(modules, &match?({^fixture, _}, &1))
    fixture
  end
end
