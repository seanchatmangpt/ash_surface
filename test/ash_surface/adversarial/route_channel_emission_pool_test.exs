defmodule AshSurface.Adversarial.RouteChannelEmissionPoolTest do
  @moduledoc """
  Lane RBX (P1-P4). Uppercase / mixed-case / unicode declared names through RouteSchema, checked
  against HARD-CODED literals derived by hand from the reference rule (ash_typescript helpers.ex
  :25-30: snake_to_camel_case = lowercase-first(Macro.camelize(name))). No Macro.camelize call
  in this file. Consistent with conformance/vectors/field_name_emission.json (camel_case).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.RouteSchema

  # {declared, client key}; derivations: Macro.camelize upcases the first byte and each ASCII
  # a-z/0-9 after `_`; `_` before uppercase is kept; doubled/trailing `_` collapse/drop.
  @literals [
    {"HTTP_code", "hTTPCode"},
    {"a_bCd", "aBCd"},
    {"ab_cD_eF", "abCDEF"},
    {"Foo_bar", "fooBar"},
    {"a_B", "a_B"},
    {"x1_", "x1"},
    {"a__b", "aB"},
    {"über_straße", "überStraße"},
    {"user_ID", "user_ID"},
    {"A_b", "aB"}
  ]

  # non-injective pairs: both emit the same key
  @collisions [
    {"Foo_bar", "foo_bar", "fooBar"},
    {"A_b", "a_b", "aB"},
    {"a__b", "a_b", "aB"},
    {"x1_", "x1", "x1"}
  ]

  defp str(n), do: %{"name" => n, "type" => %{"kind" => "string"}, "allow_nil?" => false}

  defp route(args),
    do: %{"name" => "t", "method" => "post", "path" => "/t", "arguments" => args}

  for {declared, client} <- @literals do
    test "P1 literal #{declared} -> #{client} (body)" do
      {:ok, [b]} = RouteSchema.build([route([str(unquote(declared))])])
      assert b["body"] =~ ~s(#{unquote(client)}:) or b["body"] =~ ~s("#{unquote(client)}":),
             "#{unquote(declared)}: expected #{unquote(client)} in #{b["body"]}"
    end

    test "P2 literal #{declared} -> #{client} (query + path param)" do
      {:ok, [q]} =
        RouteSchema.build([
          %{"name" => "t", "method" => "get", "path" => "/t", "arguments" => [str(unquote(declared))]}
        ])

      assert q["query"] =~ ~s(#{unquote(client)}:) or q["query"] =~ ~s("#{unquote(client)}":)
    end
  end

  test "P3 path param keeps URL template verbatim, params key emitted" do
    {:ok, [b]} =
      RouteSchema.build([
        %{"name" => "t", "method" => "get", "path" => "/t/:HTTP_code", "arguments" => [str("HTTP_code")]}
      ])

    assert b["path"] == "/t/:HTTP_code"
    assert b["params"] =~ "hTTPCode:"
  end

  for {a, b, key} <- @collisions do
    test "P4 collision #{a} / #{b} -> #{key} refused" do
      assert {:error, {:emitted_key_collision, _container, unquote(key), names}} =
               RouteSchema.build([route([str(unquote(a)), str(unquote(b))])])

      assert names == Enum.sort([unquote(a), unquote(b)])
    end
  end
end
