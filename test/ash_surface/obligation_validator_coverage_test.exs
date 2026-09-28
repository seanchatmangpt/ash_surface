defmodule AshSurface.ObligationValidatorCoverageTest do
  @moduledoc """
  Pins two default/vacuous-admission laws:

    * `AshSurface.Obligation.create/3` is `create/4` with empty opts: an
      `:open`, unassigned, OBSERVE-only obligation with the same identity
      and state digest;
    * `AshSurface.Resource.Validator.validate/1` admits an empty projection
      list vacuously — there is nothing to check against the public action
      set, so no resource reference is required — while a non-empty list
      without a resolvable resource is still refused typed.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Obligation
  alias AshSurface.Resource.Validator

  test "Obligation.create/3 applies the documented defaults and equals create/4 with []" do
    three = Obligation.create("zoe:event#gate", "Zoe.Security.reinforce", "obs_1")
    four = Obligation.create("zoe:event#gate", "Zoe.Security.reinforce", "obs_1", [])

    assert three == four
    assert three.status == :open
    assert three.assigned_to == nil
    assert three.escalation_path == []
    assert three.evidence_refs == []
    assert three.authority_boundary == :OBSERVE
    assert "obl_" <> suffix = three.obligation_id
    assert byte_size(suffix) == 16
  end

  test "an empty projection list is admitted vacuously, with or without a resource" do
    assert Validator.validate(%{surface: []}) == :ok
    assert Validator.validate(%{resource: :not_a_resource, surface: []}) == :ok
  end

  test "a non-empty projection list without a resolvable resource is refused" do
    assert {:error, [%{code: "invalid_surface_compilation"}]} =
             Validator.validate(%{surface: [%{action: :read}]})
  end
end
