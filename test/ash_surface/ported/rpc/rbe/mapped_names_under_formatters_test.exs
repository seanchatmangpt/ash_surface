defmodule AshSurface.Ported.Rpc.Rbe.DocResource do
  @moduledoc "Lane RBE inline resource: pure (non-attribute) mapped argument `is_open?` -> `q`."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbe.DocDomain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbeDoc")
    field_names(line_1: "lineOne")
    argument_names(search: [is_open?: "q"])
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:line_1, :string, public?: true)
  end

  actions do
    read :read do
      primary?(true)
    end

    read :search do
      argument(:is_open?, :boolean)
      argument(:other_arg, :string)
    end
  end
end

defmodule AshSurface.Ported.Rpc.Rbe.DocDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rbe.DocResource)
  end
end

defmodule AshSurface.Ported.Rpc.Rbe.MappedNamesUnderFormattersTest do
  @moduledoc """
  Lane RBE. Mapped names (`field_names` / `argument_names`) are verbatim wire names that win over
  the output formatter (reference: ActionIntrospection.format_input_name `is_binary(mapped) ->
  mapped`, FieldFormatter.compute_field_for_client "Mapped fields return the exact string").
  Real `User` fixture through the real parse + format pipeline under every formatter.
  """
  use ExUnit.Case, async: false

  alias AshSurface.FieldName
  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.RuntimeParity.Rpc.Support

  defmodule Fmt do
    @moduledoc false
    def up(field), do: "x_" <> to_string(field)
  end

  @formatters [:camel_case, :snake_case, :pascal_case]

  defp user(attrs),
    do: struct(P.User, Map.merge(%{id: "u1", name: "Alice", email: "a@example.com"}, attrs))

  for f <- @formatters do
    test "mapped field name is accepted in input and fields under #{f}" do
      FieldName.with_formatter(unquote(f), fn ->
        params = %{
          "action" => "create_user",
          "input" => %{"addressLine1" => "1 Main"},
          "fields" => ["addressLine1"]
        }

        assert {:ok, request} = R.parse(params)
        assert request.input[:address_line_1] == "1 Main"

        assert %{} = res = R.run(params, user(%{address_line_1: "1 Main"}))
        data = res["data"] || res["Data"]
        assert data["addressLine1"] == "1 Main"
      end)
    end

    test "mapped argument name is kept in request input under #{f}" do
      FieldName.with_formatter(unquote(f), fn ->
        params = %{
          "action" => "read_with_invalid_arg",
          "input" => %{"isActive" => true},
          "fields" => [FieldName.compute(:id, unquote(f))]
        }

        assert {:ok, request} = R.parse(params)
        assert request.input == %{is_active?: true}
      end)
    end

    test "format_input_name returns mapped argument verbatim under #{f}" do
      Application.ensure_all_started(:ash_surface)
      R.install()

      assert Support.format_input_name(
               P.User,
               :read_with_invalid_arg,
               :is_active?,
               Support.resource_lookup(),
               unquote(f)
             ) == "isActive"
    end
  end

  test "mapped names under a {m,f} custom formatter" do
    FieldName.with_formatter({Fmt, :up}, fn ->
      R.install()

      assert Support.format_input_name(
               P.User,
               :read_with_invalid_arg,
               :is_active?,
               Support.resource_lookup(),
               {Fmt, :up}
             ) == "isActive"

      assert Support.format_input_name(
               P.User,
               :create_user,
               :address_line_1,
               Support.resource_lookup(),
               {Fmt, :up}
             ) == "addressLine1"
    end)
  end

  test "unmapped argument still follows the formatter" do
    R.install()

    assert Support.format_input_name(
             P.User,
             :create_user,
             :some_arg,
             Support.resource_lookup(),
             :pascal_case
           ) == "SomeArg"
  end
  describe "pure mapped argument (not an attribute) through the real pipeline" do
    alias AshSurface.Ported.Rpc.Rbe.DocResource
    alias AshSurface.RuntimeParity.RequestedFields.Compat
    alias AshSurface.RuntimeParity.Rpc.Pipeline

    @otp_app :ash_surface_ported_rbe

    defp install_doc do
      Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rbe.DocDomain])
      {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)

      Support.install(Compat.prepare(manifest), [
        Pipeline.entry(:search_docs, DocResource, :search)
      ])
    end

    for f <- @formatters do
      test "q is verbatim and other_arg follows the formatter under #{f}" do
        FieldName.with_formatter(unquote(f), fn ->
          install_doc()
          other = FieldName.compute(:other_arg, unquote(f))

          assert {:ok, request} =
                   Pipeline.parse_request(
                     %{
                       "action" => "search_docs",
                       "input" => %{"q" => true, other => "x"},
                       "fields" => [FieldName.compute(:id, unquote(f)), "lineOne"]
                     },
                     []
                   )

          assert request.input == %{is_open?: true, other_arg: "x"}

          assert Support.format_input_name(
                   DocResource,
                   :search,
                   :is_open?,
                   Support.resource_lookup(),
                   unquote(f)
                 ) == "q"
        end)
      end
    end

    test "q is verbatim under a {m,f} custom formatter" do
      install_doc()

      assert Support.format_input_name(
               DocResource,
               :search,
               :is_open?,
               Support.resource_lookup(),
               {Fmt, :up}
             ) == "q"

      assert Support.format_input_name(
               DocResource,
               :search,
               :other_arg,
               Support.resource_lookup(),
               {Fmt, :up}
             ) == "x_other_arg"
    end
  end
  describe "validation-error formatting" do
    alias AshSurface.ErrorFormatter

    @mapping %{address_line_1: "addressLine1"}

    for {f, other, key} <- [
          {:camel_case, "someField", "shortMessage"},
          {:snake_case, "some_field", "short_message"},
          {:pascal_case, "SomeField", "ShortMessage"}
        ] do
      test "mapped name verbatim, unmapped and keys follow #{f}" do
        error = %{
          short_message: "bad %{some_field}",
          fields: [:address_line_1, :some_field],
          path: [:address_line_1],
          vars: %{some_field: "v", field: :address_line_1}
        }

        mapped = ErrorFormatter.apply_field_names(error, @mapping, unquote(f))
        assert mapped.fields == ["addressLine1", unquote(other)]
        assert mapped.path == ["addressLine1"]
        assert mapped.vars.field == "addressLine1"

        formatted = ErrorFormatter.format(error, unquote(f))
        assert Map.has_key?(formatted, String.to_atom(unquote(key))) or
                 Map.has_key?(formatted, unquote(key))

        assert (formatted[unquote(key)] || formatted[String.to_atom(unquote(key))]) ==
                 "bad %{#{unquote(other)}}"
      end
    end
  end
end
