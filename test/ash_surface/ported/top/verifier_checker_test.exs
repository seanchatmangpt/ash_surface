Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.VerifierCheckerTest do
  @moduledoc """
  Port of ash_typescript `verifier_checker_test.exs`. The three reference "error formatting"
  tests and the "detects verifier errors" test have empty bodies upstream; here each is a real
  assertion against real resources (invalid inline surface resource, non-resource module).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Domain, EmptyResource, Post, T2}
  alias AshSurface.VerifierChecker

  describe "check_all_verifiers/1" do
    test "returns :ok for valid resources" do
      assert :ok = VerifierChecker.check_all_verifiers([Post])
    end

    test "returns :ok for valid domains" do
      assert :ok = VerifierChecker.check_all_verifiers([Domain])
    end

    test "returns :ok for valid resources and domains together" do
      assert :ok = VerifierChecker.check_all_verifiers([Post, EmptyResource, Domain])
    end

    test "returns :ok for empty list" do
      assert :ok = VerifierChecker.check_all_verifiers([])
    end

    test "detects verifier errors in invalid resources" do
      {bad, _stderr} =
        T2.compile_resource(
          """
          attributes do
            uuid_primary_key :id, public?: true
            attribute :plain, :string, public?: true
          end
          actions do
            defaults [:read]
          end
          """,
          ~s(projection :read\nfield_names plain: "plain2")
        )

      assert {:error, message} = VerifierChecker.check_all_verifiers([Post, bad])
      assert message =~ "Module: #{inspect(bad)}"
      assert message =~ "Verifier: AshSurface.Resource.Verify"
      assert message =~ "invalid_field_names"
      refute message =~ "Module: #{inspect(Post)}"
    end
  end

  describe "error formatting" do
    test "formats Spark.Error.DslError correctly" do
      {bad, _} =
        T2.compile_resource(
          """
          attributes do
            uuid_primary_key :id, public?: true
          end
          actions do
            defaults [:read]
          end
          """,
          ~s(projection :read\nfield_names ghost: "g")
        )

      assert {:error, message} = VerifierChecker.check_all_verifiers([bad])
      # the DslError's message is extracted (no struct inspect noise)
      assert message =~ "Error: invalid_field_names"
      refute message =~ "%Spark.Error.DslError"
    end

    test "formats exception errors correctly" do
      # A module whose DSL cannot be read raises inside the checker; the exception message
      # is reported against that module instead of crashing the aggregate.
      assert {:error, message} = VerifierChecker.check_all_verifiers([Enum, Post])
      assert message =~ "Module: Enum"
      assert message =~ "Error: "
      refute message =~ "Module: #{inspect(Post)}"
    end

    test "aggregates several failing modules, separated by a blank line" do
      {a, _} =
        T2.compile_resource(
          "attributes do\nuuid_primary_key :id, public?: true\nend\nactions do\ndefaults [:read]\nend",
          ~s(projection :read\nfield_names ghost: "g")
        )

      {b, _} =
        T2.compile_resource(
          "attributes do\nuuid_primary_key :id, public?: true\nend\nactions do\ndefaults [:read]\nend",
          ~s(projection :read\nfield_names nope: "n")
        )

      assert {:error, message} = VerifierChecker.check_all_verifiers([a, b])
      assert [first, second] = String.split(message, "\n\n")
      assert first =~ inspect(a)
      assert second =~ inspect(b)
    end
  end
end
