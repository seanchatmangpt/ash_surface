defmodule AshSurface.DivergenceClose.FieldNamePrecedenceErrorSpellingTest do
  @moduledoc """
  Wave 3 lane RO courts (SK-fw defects 3 and 4), real Spark compile + real `Errors.to_errors/2`.

  (3) ONE precedence kernel (`FieldName.wire/3`): a `typescript_field_names/0` callback is
  authoritative (reference `compute_field_for_client`: unlisted fields fall to the formatter,
  never to the `field_names` option), so `wire/3` and `format_field_for_client/3` agree.
  (4) error `fields`, `path` and `vars.field` carry the resource-bound wire spelling = schema key.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Errors, FieldName}

  defp compile!(tag, body, surface) do
    name = "Elixir.AshSurface.RO.#{tag}#{System.unique_integer([:positive])}"

    Code.compile_string("""
    defmodule #{name} do
      use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
        extensions: [AshSurface.Resource]
      #{body}
      surface do
        #{surface}
      end
    end
    """)

    String.to_existing_atom(name)
  end

  defp invalid(field, path),
    do: %{
      Ash.Error.Changes.InvalidAttribute.exception(field: field, message: "bad", vars: [])
      | path: path
    }

  describe "defect 3: callback vs field_names DSL precedence" do
    setup do
      r =
        compile!(
          "Prec",
          """
          def typescript_field_names, do: [a_x?: "aX"]
          attributes do
            uuid_primary_key :id, public?: true
            attribute :a_x?, :boolean, public?: true
            attribute :done?, :boolean, public?: true
          end
          actions do
            defaults [:read]
          end
          """,
          ~s|field_names done?: "isDone"|
        )

      {:ok, r: r}
    end

    test "wire and format_field_for_client agree for every formatter", %{r: r} do
      for f <- [:camel_case, :pascal_case, :snake_case] do
        for field <- [:a_x?, :done?, :id] do
          assert FieldName.wire(r, field, formatter: f) ==
                   FieldName.format_field_for_client(field, r, f)
        end
      end

      assert FieldName.wire(r, :a_x?) == "aX"
      # callback present: the DSL entry for an unlisted field is NOT consulted
# RBS (disclosed): reference parity, a trailing `?` is kept (ash_typescript helpers.ex:25-30,73).
      assert FieldName.wire(r, :done?) == "done?"
      assert FieldName.format_field_for_client(:done?, r, :camel_case) == "done?"
    end

    test "without the callback the field_names option applies" do
      r =
        compile!(
          "NoCb",
          """
          attributes do
            uuid_primary_key :id, public?: true
            attribute :done?, :boolean, public?: true
          end
          actions do
            defaults [:read]
          end
          """,
          ~s|field_names done?: "isDone"|
        )

      assert FieldName.wire(r, :done?) == "isDone"
      assert FieldName.format_field_for_client(:done?, r, :camel_case) == "isDone"
    end
  end

  describe "defect 4: error spelling equals schema key (resource-bound)" do
    setup do
      r =
        compile!(
          "Err",
          """
          attributes do
            uuid_primary_key :id, public?: true
            attribute :__x, :string, public?: true
            attribute :is_active?, :boolean, public?: true
          end
          actions do
            read :read do
              argument :is_task_completed_now?, :boolean
            end
          end
          """,
          ~s|argument_names read: [is_task_completed_now?: "isCompleted"]|
        )

      {:ok, r: r}
    end

    test "path, fields and vars.field use the schema-key spelling", %{r: r} do
      [e] = Errors.to_errors(invalid(:__x, [:__x, :a_1]), resource: r)
      assert e["path"] == [FieldName.wire(r, :__x), FieldName.wire(r, :a_1)]
      assert hd(e["path"]) == "__x"
      assert e["fields"] == ["__x"]
      assert e["vars"]["field"] == "__x"

      [e] = Errors.to_errors(invalid(:is_active?, []), resource: r)
      assert e["fields"] == ["isActive?"]
      assert e["vars"]["field"] == "isActive?"
    end

    test "argument_names wins for the action's argument", %{r: r} do
      [e] =
        Errors.to_errors(invalid(:is_task_completed_now?, []), resource: r, action: :read)

      assert e["fields"] == ["isCompleted"]
      assert e["vars"]["field"] == "isCompleted"
    end

    test "snake and pascal formatters follow the same kernel", %{r: r} do
      [s] = Errors.to_errors(invalid(:is_active?, []), resource: r, formatter: :snake_case)
      assert s["fields"] == [FieldName.wire(r, :is_active?, formatter: :snake_case)]
      [p] = Errors.to_errors(invalid(:is_active?, []), resource: r, formatter: :pascal_case)
      assert p["Fields"] == ["IsActive?"]
    end
  end
end
