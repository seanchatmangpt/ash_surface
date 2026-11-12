Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.VerifyTypedQueryFieldsTest do
  @moduledoc """
  Port of ash_typescript `rpc/verify_typed_query_fields_test.exs` (9 tests).

  Reference drives `AshTypescript.Manifest.verify_for_domains/1` over a domain with
  `typescript_rpc do typed_query ... end`. ash_surface declares `typed_query` in the resource
  `surface` section; `AshSurface.VerifierChecker.check_all_verifiers/1` is the counterpart
  entry point. Message assertions use the ash_surface refusal codes (same facts as the
  reference messages). Fixtures are real Ash resources compiled per test.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.E

  defp resource(name, typed_fields, opts \\ []) do
    extra_attr = Keyword.get(opts, :attr, "")
    rels = Keyword.get(opts, :rels, "")
    calcs = Keyword.get(opts, :calcs, "")
    comment = Keyword.get(opts, :comment, "")

    """
    #{comment}
    defmodule #{name} do
      use Ash.Resource,
        domain: nil,
        data_layer: Ash.DataLayer.Ets,
        validate_domain_inclusion?: false,
        extensions: [AshSurface.Resource]

      surface do
        type_name "#{name |> String.split(".") |> List.last()}"

        typed_query :list_items, :read do
          fields_const_name "listItems"
          result_type_name "ListItemsResult"
          fields #{typed_fields}
        end
      end

      attributes do
        uuid_primary_key :id, public?: true
        attribute :title, :string, public?: true
        attribute :description, :string, public?: true
        #{extra_attr}
      end

      #{rels}
      #{calcs}

      actions do
        defaults [:read]
      end
    end
    """
  end

  defp comment_resource(name) do
    """
    defmodule #{name} do
      use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets,
        validate_domain_inclusion?: false

      attributes do
        uuid_primary_key :id, public?: true
        attribute :parent_id, :uuid, public?: false
        attribute :content, :string, public?: true
      end

      actions do
        defaults [:read]
      end
    end
    """
  end

  defp with_comments(name, typed_fields) do
    comment = "#{name}Comment"

    source =
      comment_resource(comment) <>
        resource(name, typed_fields,
          rels: """
          relationships do
            has_many :comments, #{comment}, public?: true, destination_attribute: :parent_id
          end
          """
        )

    [m | _] = Enum.reverse(E.compile!(source))
    m
  end

  defp simple(name, typed_fields, opts \\ []) do
    [m | _] = Enum.reverse(E.compile!(resource(name, typed_fields, opts)))
    m
  end

  describe "typed query field validation - invalid fields" do
    test "detects unknown field in typed query" do
      mod = simple(E.uniq("T12.Unknown"), "[:id, :title, :nonexistent_field]")

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/typed_query_unknown_field/
      assert message =~ ~r/nonexistent_field/i
    end

    test "detects private field in typed query" do
      mod =
        simple(E.uniq("T12.Private"), "[:id, :title, :internal_data]",
          attr: "attribute :internal_data, :string, public?: false"
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/typed_query_private_field/
      assert message =~ ~r/internal_data/i
    end

    test "detects duplicate fields in typed query" do
      mod = simple(E.uniq("T12.Dup"), "[:id, :title, :title]")

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/typed_query_duplicate_field/
      assert message =~ ~r/title/i
    end
  end

  describe "typed query field validation - relationships" do
    test "detects relationship without nested field selection" do
      mod = with_comments(E.uniq("T12.RelNoNested"), "[:id, :title, :comments]")

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/typed_query_requires_nested_fields/
      assert message =~ ~r/comments/i
    end

    test "detects unknown field in nested relationship" do
      mod =
        with_comments(E.uniq("T12.RelBad"), "[:id, :title, comments: [:id, :nonexistent]]")

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/typed_query_unknown_field/
      assert message =~ ~r/nonexistent/i
    end
  end

  describe "typed query field validation - complex types" do
    test "detects calculation requiring arguments but not provided" do
      mod =
        simple(E.uniq("T12.CalcArgs"), "[:id, :title, :prefixed]",
          calcs: """
          calculations do
            calculate :prefixed, :string, expr(^arg(:prefix) <> title) do
              public? true
              argument :prefix, :string, allow_nil?: false
            end
          end
          """
        )

      assert {:error, message} = E.check(mod)
      assert message =~ ~r/typed_query_calculation_requires_args/
      assert message =~ ~r/requires arguments/i
    end
  end

  describe "typed query field validation - valid cases" do
    test "accepts valid typed query with simple fields" do
      mod = simple(E.uniq("T12.Valid"), "[:id, :title, :description]")

      assert :ok = E.check(mod)
    end

    test "accepts valid typed query with nested relationships" do
      mod = with_comments(E.uniq("T12.ValidRel"), "[:id, :title, comments: [:id, :content]]")

      assert :ok = E.check(mod)
    end
  end
end
