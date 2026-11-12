defmodule AshSurface.Ported.Rpc.A.ErrorProtocolGapTest do
  use ExUnit.Case, async: true

  describe "AshAuthentication error impls" do
    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "impls exist for both AshAuthentication error types" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "AuthenticationFailed is transformed into a typed error" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "AuthenticationFailed keeps its message generic so it cannot enumerate users" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "InvalidToken is transformed into a typed error" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "InvalidToken without a reason still produces a message" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "a failed sign-in surfaces as a typed error, not a generic internal error" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "an invalid token surfaces as a typed error through the full pipeline" do
      :ok
    end

    @tag skip:
           "T8 gap: needs real AshAuthentication.Errors.{AuthenticationFailed,InvalidToken} structs, but ash_authentication is not a dependency of ash_surface (module not available under mix test; AshSurface.Errors only lists them in its classification table), and hand-building lookalike structs would be a mock of an unavailable collaborator"
    test "auth errors survive JSON encoding" do
      :ok
    end
  end
end
