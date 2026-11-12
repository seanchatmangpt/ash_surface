defmodule AshSurface.Ported.Rpc.Rba.ErrorPinsTest do
  @moduledoc """
  Pins AuthenticationFailed short message and the `:key` var (skeptic wave3 repair).
  AshAuthentication is not a dependency (UNVERIFIED against the real module): a Splode struct
  under the reference module name is constructed when unloadable.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Errors

  @auth Module.concat(["AshAuthentication", "Errors", "AuthenticationFailed"])


  defp get(m, k), do: Map.get(m, k) || Map.get(m, to_string(k))

  test "AuthenticationFailed short message is exact" do
    [err] = Errors.to_errors([struct(@auth, message: "nope", field: :email)])
    assert get(err, :shortMessage) === "Authentication failed"
    assert get(err, :type) === "authentication_failed"
  end

  test ":key is retained in vars" do
    e = %Ash.Error.Page.InvalidKeyset{key: :zork, value: 1}
    [err] = Errors.to_errors([e])
    vars = get(err, :vars)
    assert get(vars, :key) === "zork"
    assert get(vars, :value) === 1
  end
end
