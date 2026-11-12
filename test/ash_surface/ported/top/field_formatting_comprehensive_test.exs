Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.FieldFormattingComprehensiveTest do
  @moduledoc """
  Adaptation of ash_typescript `field_formatting_comprehensive_test.exs` (42 tests).

  * Core `FieldFormatter` describes (format/parse, builtin + custom, `format_fields`,
    `parse_input_fields`, edge cases): ported against `AshSurface.FieldName` and the ported
    `AshSurface.RuntimeParity.Rpc.FieldFormatter`. Deliberate ash_surface differences, each
    pinned here: an empty/unknown client name parses to the string (never an atom: `""` instead of
    `:""`), and a custom `{m, f}` formatter has no hand-written inverse — the inverse is derived from
    the admitted field set (`FieldName.client_to_internal/3`), so the reference's
    `parse_input_with_prefix` parser tests become derived-inverse tests.
  * "RPC runtime field formatting": ash_surface never actuates, so the reference's
    `Rpc.run_action` create/read round trips become real input parsing
    (`Rpc.FieldFormatter.parse_input_fields/2`) validated by a real Ash changeset (no data-layer
    call), and real output key formatting (`format_output_field_names/2`).
  * "TypeScript codegen" describes assert `.ts` text: see `formatter_artifact_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.FieldName
  alias AshSurface.RuntimeParity.Rpc.FieldFormatter
  alias AshSurface.Ported.{T1, Todo, User}

  defmodule Formatters do
    @moduledoc "Hand-written real custom formatter functions (counterpart of AshTypescript.Test.Formatters)."
    def custom_format(field_name), do: "custom_#{field_name}"
    def custom_format_with_suffix(field_name, suffix), do: "#{field_name}_#{suffix}"

    def custom_format_with_multiple_args(field_name, prefix, suffix),
      do: "#{prefix}_#{field_name}_#{suffix}"

    def uppercase_format(field_name), do: field_name |> to_string() |> String.upcase()
    def error_format(_field_name), do: raise("Custom formatter error")
  end

  # keep the atoms the parse tests resolve alive in this VM
  _ = [:user_name, :email_address, :created_at, :name, :email, :title]

  describe "core field formatting - format_field_name/2 with built-in formatters" do
    test "formats fields with :camel_case" do
      assert FieldFormatter.format_field_name(:user_name, :camel_case) == "userName"
      assert FieldFormatter.format_field_name("user_name", :camel_case) == "userName"
      assert FieldFormatter.format_field_name(:email_address, :camel_case) == "emailAddress"
      assert FieldFormatter.format_field_name("created_at", :camel_case) == "createdAt"
    end

    test "formats fields with :pascal_case" do
      assert FieldFormatter.format_field_name(:user_name, :pascal_case) == "UserName"
      assert FieldFormatter.format_field_name("user_name", :pascal_case) == "UserName"
      assert FieldFormatter.format_field_name(:email_address, :pascal_case) == "EmailAddress"
      assert FieldFormatter.format_field_name("created_at", :pascal_case) == "CreatedAt"
    end

    test "formats fields with :snake_case" do
      assert FieldFormatter.format_field_name(:user_name, :snake_case) == "user_name"
      assert FieldFormatter.format_field_name("user_name", :snake_case) == "user_name"
      assert FieldFormatter.format_field_name(:email_address, :snake_case) == "email_address"
      assert FieldFormatter.format_field_name("created_at", :snake_case) == "created_at"
    end

    test "handles single word fields" do
      assert FieldFormatter.format_field_name(:name, :camel_case) == "name"
      assert FieldFormatter.format_field_name(:email, :pascal_case) == "Email"
      assert FieldFormatter.format_field_name(:title, :snake_case) == "title"
    end

    test "handles empty fields" do
      assert FieldFormatter.format_field_name("", :camel_case) == ""
      assert FieldFormatter.format_field_name("", :pascal_case) == ""
      assert FieldFormatter.format_field_name("", :snake_case) == ""
    end
  end

  describe "core field formatting - format_field_name/2 with custom formatters" do
    test "formats fields with {module, function}" do
      assert FieldFormatter.format_field_name(:user_name, {Formatters, :custom_format}) ==
               "custom_user_name"

      assert FieldFormatter.format_field_name("email", {Formatters, :uppercase_format}) == "EMAIL"
    end

    test "formats fields with {module, function, extra_args}" do
      assert FieldFormatter.format_field_name(
               :user_name,
               {Formatters, :custom_format_with_suffix, ["test"]}
             ) == "user_name_test"

      assert FieldFormatter.format_field_name(
               "email",
               {Formatters, :custom_format_with_multiple_args, ["prefix", "suffix"]}
             ) == "prefix_email_suffix"
    end

    test "raises error for unsupported formatter" do
      invalid_formatter = String.to_atom("invalid_formatter")

      assert_raise ArgumentError, "Unsupported formatter: :invalid_formatter", fn ->
        FieldFormatter.format_field_name(:user_name, invalid_formatter)
      end
    end

    test "raises error when custom formatter function fails" do
      assert_raise RuntimeError, "Custom formatter error", fn ->
        FieldFormatter.format_field_name(:user_name, {Formatters, :error_format})
      end
    end
  end

  describe "core field formatting - parse_input_field/2 with built-in formatters" do
    test "parses input fields with :camel_case" do
      assert FieldFormatter.parse_input_field("userName", :camel_case) == :user_name
      assert FieldFormatter.parse_input_field("emailAddress", :camel_case) == :email_address
      assert FieldFormatter.parse_input_field("createdAt", :camel_case) == :created_at
    end

    test "parses input fields with :pascal_case" do
      assert FieldFormatter.parse_input_field("UserName", :pascal_case) == :user_name
      assert FieldFormatter.parse_input_field("EmailAddress", :pascal_case) == :email_address
      assert FieldFormatter.parse_input_field("CreatedAt", :pascal_case) == :created_at
    end

    test "parses input fields with :snake_case" do
      assert FieldFormatter.parse_input_field("user_name", :snake_case) == :user_name
      assert FieldFormatter.parse_input_field("email_address", :snake_case) == :email_address
      assert FieldFormatter.parse_input_field("created_at", :snake_case) == :created_at
    end

    test "handles single word input fields" do
      assert FieldFormatter.parse_input_field("name", :camel_case) == :name
      assert FieldFormatter.parse_input_field("Email", :pascal_case) == :email
      assert FieldFormatter.parse_input_field("title", :snake_case) == :title
    end

    test "handles empty input fields (pinned: stays the empty string, never an atom)" do
      assert FieldFormatter.parse_input_field("", :camel_case) == ""
      assert FieldFormatter.parse_input_field("", :pascal_case) == ""
      assert FieldFormatter.parse_input_field("", :snake_case) == ""
    end
  end

  describe "core field formatting - parse with custom formatters (derived inverse)" do
    test "parses input fields with a custom formatter inverse derived from the admitted set" do
      admitted = [:user_name, :email]
      fmt = {Formatters, :custom_format}

      assert FieldName.parse_input("custom_user_name", fmt, admitted) == {:ok, :user_name}
      assert FieldName.parse_input("custom_email", fmt, admitted) == {:ok, :email}
      assert FieldName.parse_input("user_name", fmt, admitted) == :error
    end

    test "raises error for unsupported input formatter" do
      invalid_formatter = String.to_atom("invalid_formatter")

      assert_raise ArgumentError, "Unsupported formatter: :invalid_formatter", fn ->
        FieldFormatter.parse_input_field("userName", invalid_formatter)
      end
    end
  end

  describe "core field formatting - format_fields/2" do
    test "formats all keys in a map with built-in formatters" do
      input_map = %{
        user_name: "John",
        email_address: "john@example.com",
        created_at: "2023-01-01"
      }

      assert FieldName.format_fields(input_map, :camel_case) == %{
               "userName" => "John",
               "emailAddress" => "john@example.com",
               "createdAt" => "2023-01-01"
             }

      assert FieldName.format_fields(input_map, :pascal_case) == %{
               "UserName" => "John",
               "EmailAddress" => "john@example.com",
               "CreatedAt" => "2023-01-01"
             }

      assert FieldName.format_fields(input_map, :snake_case) == %{
               "user_name" => "John",
               "email_address" => "john@example.com",
               "created_at" => "2023-01-01"
             }
    end

    test "formats all keys in a map with custom formatters" do
      input_map = %{user_name: "John", email: "john@example.com"}

      assert FieldName.format_fields(input_map, {Formatters, :custom_format}) ==
               %{"custom_user_name" => "John", "custom_email" => "john@example.com"}

      assert FieldName.format_fields(
               input_map,
               {Formatters, :custom_format_with_suffix, ["test"]}
             ) == %{"user_name_test" => "John", "email_test" => "john@example.com"}
    end

    test "handles empty map" do
      assert FieldName.format_fields(%{}, :camel_case) == %{}
      assert FieldName.format_fields(%{}, {Formatters, :custom_format}) == %{}
    end

    test "handles maps with string keys" do
      assert FieldName.format_fields(
               %{"user_name" => "John", "email_address" => "john@example.com"},
               :camel_case
             ) == %{"userName" => "John", "emailAddress" => "john@example.com"}
    end
  end

  describe "core field formatting - parse_input_fields/2" do
    test "parses all keys in a map with built-in formatters" do
      expected = %{user_name: "John", email_address: "john@example.com", created_at: "2023-01-01"}

      assert FieldFormatter.parse_input_fields(
               %{
                 "userName" => "John",
                 "emailAddress" => "john@example.com",
                 "createdAt" => "2023-01-01"
               },
               :camel_case
             ) == expected

      assert FieldFormatter.parse_input_fields(
               %{
                 "UserName" => "John",
                 "EmailAddress" => "john@example.com",
                 "CreatedAt" => "2023-01-01"
               },
               :pascal_case
             ) == expected

      assert FieldFormatter.parse_input_fields(
               %{
                 "user_name" => "John",
                 "email_address" => "john@example.com",
                 "created_at" => "2023-01-01"
               },
               :snake_case
             ) == expected
    end

    test "parses all keys in a map with custom formatters (derived inverse)" do
      fmt = {Formatters, :custom_format}
      {:ok, inverse} = FieldName.client_to_internal([:user_name, :email], fmt)

      parsed =
        Map.new(%{"custom_user_name" => "John", "custom_email" => "john@example.com"}, fn {k, v} ->
          {Map.fetch!(inverse, k), v}
        end)

      assert parsed == %{user_name: "John", email: "john@example.com"}
    end

    test "handles empty map" do
      assert FieldFormatter.parse_input_fields(%{}, :camel_case) == %{}

      assert FieldName.client_to_internal([], {Formatters, :custom_format}) == {:ok, %{}}
    end

    test "preserves values when converting keys" do
      assert FieldFormatter.parse_input_fields(
               %{"userName" => %{"nested" => "value"}, "emailAddress" => [1, 2, 3]},
               :camel_case
             ) == %{user_name: %{nested: "value"}, email_address: [1, 2, 3]}
    end
  end

  describe "core field formatting - edge cases and error handling" do
    test "handles nil values in maps" do
      assert FieldName.format_fields(
               %{user_name: nil, email_address: "john@example.com"},
               :camel_case
             ) ==
               %{"userName" => nil, "emailAddress" => "john@example.com"}
    end

    test "handles complex nested values (shallow: nested keys untouched)" do
      input_map = %{
        user_info: %{nested_field: "value", another_nested: [1, 2, 3]},
        settings: %{enabled: true}
      }

      assert FieldName.format_fields(input_map, :camel_case) == %{
               "userInfo" => %{nested_field: "value", another_nested: [1, 2, 3]},
               "settings" => %{enabled: true}
             }
    end

    test "handles numeric and boolean keys gracefully" do
      assert FieldName.format_fields(%{123 => "value", true => "another"}, :snake_case) ==
               %{"123" => "value", "true" => "another"}
    end
  end

  # ---- RPC runtime field formatting (adapted: real parse/format + real Ash changeset, no actuation)

  defp create_todo_changeset(input) do
    Ash.Changeset.for_create(Todo, :create, input)
  end

  describe "RPC runtime field formatting - input field formatting with built-in formatters" do
    test "formats camelCase input fields to snake_case for internal processing" do
      user_id = Ash.UUID.generate()

      parsed =
        FieldFormatter.parse_input_fields(
          %{"title" => "Test Todo", "userId" => user_id},
          :camel_case
        )

      assert parsed == %{title: "Test Todo", user_id: user_id}
      cs = create_todo_changeset(parsed)
      assert cs.valid?, inspect(cs.errors)
      assert Ash.Changeset.get_attribute(cs, :title) == "Test Todo"
      assert Ash.Changeset.get_argument_or_attribute(cs, :user_id) == user_id
    end

    test "formats PascalCase input fields when output formatter is PascalCase" do
      user_id = Ash.UUID.generate()

      parsed =
        FieldFormatter.parse_input_fields(
          %{"Title" => "Test Todo", "UserId" => user_id},
          :pascal_case
        )

      assert parsed == %{title: "Test Todo", user_id: user_id}
      assert create_todo_changeset(parsed).valid?

      user =
        FieldFormatter.parse_input_fields(
          %{"Name" => "Test User", "Email" => "t@example.com"},
          :pascal_case
        )

      assert user == %{name: "Test User", email: "t@example.com"}
      assert Ash.Changeset.for_create(User, :create, user).valid?
    end

    test "handles snake_case input fields as-is" do
      user_id = Ash.UUID.generate()

      parsed =
        FieldFormatter.parse_input_fields(
          %{"title" => "Test Todo", "user_id" => user_id},
          :snake_case
        )

      assert parsed == %{title: "Test Todo", user_id: user_id}
      assert create_todo_changeset(parsed).valid?
    end
  end

  describe "RPC runtime field formatting - output field formatting with built-in formatters" do
    @row %{id: "1", title: "Test Todo", user_id: "u1", completed: false}

    test "formats snake_case output fields to camelCase" do
      assert FieldFormatter.format_output_field_names([@row], :camel_case) ==
               [%{"id" => "1", "title" => "Test Todo", "userId" => "u1", "completed" => false}]
    end

    test "formats snake_case output fields to PascalCase" do
      [formatted] = FieldFormatter.format_output_field_names([@row], :pascal_case)
      assert Map.has_key?(formatted, "Id")
      assert Map.has_key?(formatted, "Title")
      assert Map.has_key?(formatted, "UserId")
      refute Map.has_key?(formatted, "user_id")
      # envelope keys follow the same formatter
      assert %{"Success" => true, "Data" => _} =
               FieldFormatter.format_output_field_names(
                 %{success: true, data: [@row]},
                 :pascal_case
               )
    end

    test "leaves snake_case output fields as-is" do
      [formatted] = FieldFormatter.format_output_field_names([@row], :snake_case)
      assert Map.has_key?(formatted, "id")
      assert Map.has_key?(formatted, "title")
      assert Map.has_key?(formatted, "user_id")
    end
  end

  describe "RPC runtime field formatting - custom formatters" do
    test "formats input fields using output formatter for expected keys" do
      user_id = Ash.UUID.generate()

      parsed =
        FieldFormatter.parse_input_fields(
          %{"title" => "Test Todo", "userId" => user_id},
          :camel_case
        )

      cs = create_todo_changeset(parsed)
      assert cs.valid?
      assert Ash.Changeset.get_attribute(cs, :title) == "Test Todo"
    end
  end

  test "resource-mapped names win over the formatter (User.is_active? -> isActive)" do
    assert FieldName.format_field_for_client(:is_active?, User, :camel_case) == "isActive"
    assert :ok == T1.with_env(:output_field_formatter, :camel_case, fn -> :ok end)
  end
end
