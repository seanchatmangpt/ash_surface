defmodule AshSurface.ParityDeepen.MappedNamesCourtsTest do
  @moduledoc """
  Wave-3 F1-deepen court for `verifier.VerifyMappedFieldNames`: the resource-level
  `field_names` / `argument_names` mappings are verified by the real Spark verifier
  (refusals are `Spark.Error.DslError` codes on stderr; valid mappings compile clean and are
  readable back). Real compiled resources, no doubles.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Resource.Info

  defp compile(surface) do
    name =
      "Elixir.AshSurface.ParityDeepen.MappedNamesCourtsTest.R#{System.unique_integer([:positive])}"

    out =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule #{name} do
          use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
            validate_domain_inclusion?: false, extensions: [AshSurface.Resource]
          attributes do
            uuid_primary_key :id, public?: true
            attribute :item_1, :string, public?: true
            attribute :plain, :string, public?: true
          end
          actions do
            defaults [:read]
            read :search do
              argument :arg_1, :string
              argument :other, :string
            end
          end
          surface do
            projection :read
            #{surface}
          end
        end
        """)
      end)

    {String.to_existing_atom(name), out}
  end

  test "a valid field_names mapping for an awkward name compiles clean and reads back" do
    {mod, out} = compile(~s(field_names item_1: "item1"))
    refute out =~ "invalid_field_names"
    assert Info.field_names(mod) == [item_1: "item1"]
  end

  test "field_names refusals: unknown field, needless mapping, bad identifier, collision" do
    assert {_, out} = compile(~s(field_names ghost: "g"))
    assert out =~ "invalid_field_names"
    assert {_, out} = compile(~s(field_names plain: "plain2"))
    assert out =~ "invalid_field_names"
    assert {_, out} = compile(~s(field_names item_1: "1 bad"))
    assert out =~ "invalid_field_names"
    assert {_, out} = compile(~s(field_names item_1: "plain"))
    assert out =~ "invalid_field_names"
  end

  test "a valid argument_names mapping compiles clean and reads back" do
    {mod, out} = compile(~s(argument_names search: [arg_1: "arg1"]))
    refute out =~ "invalid_argument_names"
    assert Info.argument_names(mod) == [search: [arg_1: "arg1"]]
  end

  test "argument_names refusals: unknown action, unknown argument, bad identifier, non-keyword" do
    assert {_, out} = compile(~s(argument_names ghost: [arg_1: "a"]))
    assert out =~ "invalid_argument_names"
    assert out =~ "does not exist on the resource"
    assert {_, out} = compile(~s(argument_names search: [nope: "a"]))
    assert out =~ "invalid_argument_names"
    assert {_, out} = compile(~s(argument_names search: [arg_1: "1 bad"]))
    assert out =~ "invalid_argument_names"
    assert {_, out} = compile(~s(argument_names [:search]))
    assert out =~ "invalid_argument_names" or out =~ "expected"
  end
end
