defmodule AshSurface.TypedQueryFieldsTest.Author do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:name, :string, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.TypedQueryFieldsTest.Post do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:title, :string, public?: true)
    attribute(:secret, :string, public?: false)
  end

  relationships do
    belongs_to(:author, AshSurface.TypedQueryFieldsTest.Author, public?: true, allow_nil?: true)
  end

  calculations do
    calculate(:shout, :string, expr(title <> "!"), public?: true)

    calculate :greeting, :string, expr(^arg(:who) <> title) do
      public?(true)
      argument(:who, :string, allow_nil?: false)
    end
  end

  actions do
    defaults([:read, create: [:title]])
  end

  surface do
    projection(:read)

    typed_query :post_list, :read do
      description("Posts")
      result_type_name("PostListResult")
      fields_const_name("postListFields")
      fields([:id, :title, :shout, author: [:id, :name]])
    end
  end
end

defmodule AshSurface.TypedQueryFieldsTest.Nested do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:label, :string, public?: true)
    attribute(:hidden, :string, public?: false)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.TypedQueryFieldsTest.Doc do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:title, :string, public?: true)
    attribute(:meta, AshSurface.TypedQueryFieldsTest.Nested, public?: true)
    attribute(:metas, {:array, AshSurface.TypedQueryFieldsTest.Nested}, public?: true)

    attribute(:body, :union,
      public?: true,
      constraints: [
        types: [
          note: [type: :string],
          rich: [type: AshSurface.TypedQueryFieldsTest.Nested]
        ]
      ]
    )

    attribute(:pt, :map,
      public?: true,
      constraints: [
        fields: [
          x: [type: :integer],
          inner: [type: :map, constraints: [fields: [deep: [type: :string]]]]
        ]
      ]
    )
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.TypedQueryFieldsTest.NsDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]

  surface do
    namespace("billing")
  end

  resources do
    resource(AshSurface.TypedQueryFieldsTest.DomRes)
  end
end

defmodule AshSurface.TypedQueryFieldsTest.DomRes do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.TypedQueryFieldsTest.NsDomain,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.TypedQueryFieldsTest do
  use ExUnit.Case, async: true

  alias AshSurface.Resource.{Projections, TypedQueryFields, Validator}
  alias AshSurface.TypedQueryFieldsTest.Post

  defp codes(fields),
    do: fields |> then(&TypedQueryFields.verify(Post, &1)) |> Enum.map(& &1.code)

  defp tq(name, action, fields) do
    struct!(AshSurface.Dsl.TypedQuery, name: name, action: action, fields: fields)
  end

  defp validate(queries), do: Validator.validate(%{surface: queries, resource: Post})

  defp refusal_codes(queries) do
    case validate(queries) do
      :ok -> []
      {:error, refusals} -> Enum.map(refusals, & &1.code)
    end
  end

  describe "DSL entity (real compiled resource)" do
    test "typed_query is introspectable and projections exclude it" do
      assert [%{name: :post_list, action: :read} = q] = Projections.typed_queries(Post)
      assert q.description == "Posts"
      assert q.result_type_name == "PostListResult"
      assert q.fields_const_name == "postListFields"
      assert Projections.typed_query(Post, :post_list) == q
      assert Projections.typed_query(Post, :nope) == nil
      assert Enum.map(Projections.all(Post), & &1.action) == [:read]
    end

    test "compiled state of the real resource validates" do
      assert :ok = Validator.validate(AshSurface.Resource.Info.compiled!(Post))
    end
  end

  describe "fields verification" do
    test "valid selections are admitted" do
      assert [] == codes([:id, :title, :shout, author: [:id, :name]])
      assert [] == codes([:id, greeting: %{args: %{who: "x"}, fields: []}])
    end

    test "unknown field" do
      assert ["typed_query_unknown_field"] == codes([:nope])
    end

    test "private field" do
      assert ["typed_query_private_field"] == codes([:secret])
    end

    test "duplicate field" do
      assert ["typed_query_duplicate_field"] == codes([:id, :id])
    end

    test "relationship without nested fields" do
      assert ["typed_query_requires_nested_fields"] == codes([:author])
    end

    test "unknown field inside nested relationship selection" do
      assert ["typed_query_unknown_field"] == codes(author: [:nope])
    end

    test "calculation needing args selected bare" do
      assert ["typed_query_calculation_requires_args"] == codes([:greeting])
    end

    test "calculation with args map missing the required arg" do
      assert ["typed_query_calculation_requires_args"] ==
               codes(greeting: %{args: %{}, fields: []})
    end

    test "nesting on a plain attribute" do
      assert ["typed_query_field_not_nestable"] == codes(title: [:x])
    end

    test "non-list fields and invalid entries" do
      assert ["typed_query_invalid_fields"] == codes(:id)
      assert ["typed_query_invalid_fields"] == codes(["id"])
    end
  end

  describe "validator refusals" do
    test "valid typed query is admitted" do
      assert [] == refusal_codes([tq(:ok_q, :read, [:id])])
    end

    test "unknown action" do
      assert ["typed_query_unknown_action"] == refusal_codes([tq(:q, :missing, [:id])])
    end

    test "non-read action" do
      assert ["typed_query_non_read_action"] == refusal_codes([tq(:q, :create, [:id])])
    end

    test "duplicate names" do
      assert ["typed_query_duplicate_name"] ==
               refusal_codes([tq(:q, :read, [:id]), tq(:q, :read, [:id])])
    end

    test "invalid names" do
      for name <- [:Bad, :"1x", :"has-dash", :ok?] do
        assert ["typed_query_invalid_name"] == refusal_codes([tq(name, :read, [:id])]),
               "expected #{inspect(name)} refused"
      end
    end

    test "invalid fields surface through the validator" do
      assert ["typed_query_unknown_field"] == refusal_codes([tq(:q, :read, [:nope])])
    end

    test "typed queries never count as projections" do
      assert [] == refusal_codes([tq(:read, :read, [:id])])
    end
  end

  describe "nested selection: embedded resources, unions, typed structs" do
    defp dcodes(fields),
      do:
        AshSurface.TypedQueryFieldsTest.Doc
        |> TypedQueryFields.verify(fields)
        |> Enum.map(& &1.code)
        |> Enum.sort()

    test "admitted selections" do
      assert [] == dcodes([:id, meta: [:id, :label], metas: [:label], pt: [:x, inner: [:deep]]])
      assert [] == dcodes(body: [:note, rich: [:label]])

      assert [] == dcodes(body: %{rich: [:id]})
    end

    test "embedded resource requires nested selection" do
      assert ["typed_query_requires_nested_fields"] == dcodes([:meta])
      assert ["typed_query_requires_nested_fields"] == dcodes([:metas])
    end

    test "unknown and private fields inside embedded selection" do
      assert ["typed_query_unknown_field"] == dcodes(meta: [:ghost])
      assert ["typed_query_private_field"] == dcodes(meta: [:hidden])
    end

    test "duplicate fields inside embedded selection" do
      assert ["typed_query_duplicate_field"] == dcodes(meta: [:id, :id])
    end

    test "typed struct: unknown/duplicate/needs-nested/not-nestable" do
      assert ["typed_query_unknown_field"] == dcodes(pt: [:nope])
      assert ["typed_query_duplicate_field"] == dcodes(pt: [:x, :x])
      assert ["typed_query_requires_nested_fields"] == dcodes(pt: [:inner])
      assert ["typed_query_field_not_nestable"] == dcodes(pt: [x: [:y]])
      assert ["typed_query_unknown_field"] == dcodes(pt: [inner: [:other]])
      assert ["typed_query_requires_nested_fields"] == dcodes([:pt])
    end

    test "union member selection" do
      assert ["typed_query_unknown_union_member"] == dcodes(body: [:ghost])
      assert ["typed_query_requires_nested_fields"] == dcodes(body: [:rich])
      assert ["typed_query_field_not_nestable"] == dcodes(body: [note: [:x]])
      assert ["typed_query_unknown_field"] == dcodes(body: [rich: [:ghost]])
      assert ["typed_query_private_field"] == dcodes(body: [rich: [:hidden]])
      assert ["typed_query_duplicate_field"] == dcodes(body: [:note, :note])
      assert ["typed_query_requires_nested_fields"] == dcodes([:body])
    end
  end

  describe "resource naming options through the real Spark verifier" do
    defp compile!(extra) do
      name = "Elixir.AshSurface.TypedQueryFieldsTest.R#{System.unique_integer([:positive])}"

      Code.compile_string("""
      defmodule #{name} do
        use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]
        attributes do
          uuid_primary_key :id, public?: true
          attribute :field_1, :string, public?: true
          attribute :field_2, :string, public?: true
          attribute :ok, :string, public?: true
        end
        actions do
          read :read do
            argument :arg_1, :string
          end
        end
        surface do
          #{extra}
        end
      end
      """)

      String.to_existing_atom(name)
    end

    test "valid options are introspectable" do
      mod =
        compile!("""
        type_name "Doc"
        namespace "docs"
        field_names field_1: "field1", field_2: "field2"
        argument_names read: [arg_1: "arg1"]
        """)

      alias AshSurface.Resource.Info
      assert "Doc" == Info.type_name(mod)
      assert "docs" == Info.namespace(mod)
      assert "docs" == Info.effective_namespace(mod)
      assert [field_1: "field1", field_2: "field2"] == Info.field_names(mod)
      assert [read: [arg_1: "arg1"]] == Info.argument_names(mod)

      assert {:ok, %{mapped: %{field_1: "field1"}}} =
               AshSurface.FieldName.Mapping.build(
                 fields: [:field_1, :field_2],
                 field_names: Map.new(Info.field_names(mod))
               )
    end

    defp refused_out(extra) do
      # Spark verifiers run after compile and surface DslError as a compiler warning.
      ExUnit.CaptureIO.capture_io(:stderr, fn -> compile!(extra) end)
    end

    test "field_names: unknown field, needless mapping, bad identifier, collision" do
      out = refused_out(~s|field_names ghost: "g"|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "invalid_field_names"

      out = refused_out(~s|field_names ok: "fine"|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "field_not_invalid"

      out = refused_out(~s|field_names field_1: "bad name"|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "replacement_invalid_identifier"

      out = refused_out(~s|field_names field_1: "same", field_2: "same"|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "collision"
    end

    test "argument_names: unknown action, unknown argument" do
      out = refused_out(~s|argument_names ghost: [arg_1: "a"]|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "invalid_argument_names"

      out = refused_out(~s|argument_names read: [nope_1: "a"]|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "field_not_found"
    end

    test "type_name / namespace identifiers" do
      out = refused_out(~s|type_name "not valid"|)
      assert out =~ "Spark.Error.DslError"
      assert out =~ "invalid_type_name"

      # namespace is a free-form grouping string (reference parity, KD-free): never refused
      refute refused_out(~s|namespace "a b"|) =~ "invalid_namespace"
    end
  end

  describe "domain namespace" do
    test "resource inherits domain namespace; resource namespace overrides" do
      assert "billing" ==
               AshSurface.Domain.Info.namespace(AshSurface.TypedQueryFieldsTest.NsDomain)

      assert "billing" ==
               AshSurface.Resource.Info.effective_namespace(
                 AshSurface.TypedQueryFieldsTest.DomRes
               )
    end
  end
end
