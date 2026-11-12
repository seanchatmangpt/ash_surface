defmodule AshSurface.ErrorTypeParity.ErrorTypeParityTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType
  alias AshSurface.Errors
  alias AshSurface.Projectors.JS.ZodGuard

  @auth Module.concat(["AshAuthentication", "Errors", "AuthenticationFailed"])
  @token Module.concat(["AshAuthentication", "Errors", "InvalidToken"])

  # AshAuthentication is not a dependency; real Splode error structs under the reference's
  # module names (the table dispatches on the struct module, like the reference defimpl).

  test "AuthenticationFailed and InvalidToken tables are keyed by the real module names" do
    src = File.read!("lib/ash_surface/errors.ex")
    assert src =~ "AshAuthentication.Errors.AuthenticationFailed =>"
    assert src =~ "AshAuthentication.Errors.InvalidToken =>"
  end

  test "authentication_failed reaches the wire with the right type" do
    [err] = Errors.to_errors([struct(@auth, message: "nope", field: :email)])
    assert err["type"] == "authentication_failed" or err[:type] == "authentication_failed"

    assert err["shortMessage"] == "Authentication failed" or
             err[:short_message] == "Authentication failed"
  end

  test "invalid_token reaches the wire with the right type" do
    [err] = Errors.to_errors([struct(@token, message: "nope", field: :email)])
    assert err["type"] == "invalid_token" or err[:type] == "invalid_token"
    assert err["shortMessage"] == "Invalid token" or err[:short_message] == "Invalid token"
  end

  test "binary_id and date_time kinds render through ZodType and admit in zod guard" do
    for {kind, expected} <- [{"binary_id", "z.guid()"}, {"date_time", "z.iso.datetime()"}] do
      out = ZodType.fragment(%{"type" => %{"kind" => kind}})
      assert out == expected
      assert {:ok, _, _} = ZodGuard.admit(out)
    end
  end

  test "constraint escape? selects the ltree array form" do
    flex = ZodType.fragment(%{"type" => %{"kind" => "ltree"}})

    arr =
      ZodType.fragment(%{"type" => %{"kind" => "ltree"}, "constraints" => %{"escape?" => true}})

    assert flex == "z.union([z.string(), z.array(z.string())])"
    assert arr == "z.array(z.string())"
    assert {:ok, _, _} = ZodGuard.admit(arr)
  end

  test "constraint instance_of leaves a struct record shape intact" do
    out =
      ZodType.fragment(%{
        "type" => %{"kind" => "struct"},
        "constraints" => %{"instance_of" => "Elixir.Some.Struct"}
      })

    assert out == "z.record(z.string(), z.unknown())"
    assert {:ok, _, _} = ZodGuard.admit(out)
  end
end
