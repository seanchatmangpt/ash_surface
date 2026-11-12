defmodule AshSurface.Ported.Rpc.C.PrivateArgumentsSurfaceTest do
  @moduledoc """
  Port of the reference describe "private arguments exist in action definition but are properly
  filtered" (4 tests): the `OrgTodo` fixture declares private (`public?: false`) arguments on a
  create, read, update and generic action. The 11 TypeScript/Zod/validation-error-schema text
  tests of the reference stay loud skips in `private_arguments_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{OrgTodo, Rpc}
  alias AshSurface.RuntimeParity.Rpc.Request

  test "OrgTodo create action has a private argument defined" do
    action = Ash.Resource.Info.action(OrgTodo, :create)
    private_arg = Enum.find(action.arguments, &(&1.name == :internal_tracking_id))
    assert private_arg, "internal_tracking_id argument should exist on the action"
    refute private_arg.public?, "internal_tracking_id should have public?: false"

    public_arg = Enum.find(action.arguments, &(&1.name == :user_id))
    assert public_arg, "user_id argument should exist on the action"
    assert public_arg.public?, "user_id should have public?: true (default)"
  end

  test "OrgTodo read action has a private argument defined" do
    action = Ash.Resource.Info.action(OrgTodo, :read)
    private_arg = Enum.find(action.arguments, &(&1.name == :internal_audit_mode))
    assert private_arg, "internal_audit_mode argument should exist on the action"
    refute private_arg.public?, "internal_audit_mode should have public?: false"
  end

  test "OrgTodo set_priority action has a private argument defined" do
    action = Ash.Resource.Info.action(OrgTodo, :set_priority)
    private_arg = Enum.find(action.arguments, &(&1.name == :bypass_validation))
    assert private_arg, "bypass_validation argument should exist on the action"
    refute private_arg.public?, "bypass_validation should have public?: false"
  end

  test "OrgTodo search action has a private argument defined" do
    action = Ash.Resource.Info.action(OrgTodo, :search)
    private_arg = Enum.find(action.arguments, &(&1.name == :debug_mode))
    assert private_arg, "debug_mode argument should exist on the action"
    refute private_arg.public?, "debug_mode should have public?: false"
  end

  describe "ash_surface behaviour: private arguments are not part of the public surface" do
    defp parsed(action, input) do
      assert {:ok, %Request{} = request} =
               Rpc.parse(%{"action" => action, "fields" => ["id"], "input" => input})

      request
    end

    test "parsed action inputs omit public?: false arguments and keep public ones" do
      request = parsed("create_org_todo", %{"userId" => "u1"})
      names = Enum.map(request.action.inputs, & &1.name)

      refute :internal_tracking_id in names
      assert :title in names
    end

    test "input parse formats the public argument key and never resolves the private one" do
      request = parsed("create_org_todo", %{"userId" => "u1", "internalTrackingId" => "z"})

      assert request.input.user_id == "u1"
      refute Map.has_key?(request.input, :internal_tracking_id)
      # reference parity (input_formatter.ex identical): unknown client key is passed through untouched;
      # Ash drops/refuses it at execution, which is out of scope for the non-actuating port
      assert request.input["internalTrackingId"] == "z"
    end

    test "private arguments on read and generic actions are omitted from parsed inputs" do
      read = parsed("list_org_todos", %{"internalAuditMode" => true})
      refute :internal_audit_mode in Enum.map(read.action.inputs, & &1.name)
      refute Map.has_key?(read.input, :internal_audit_mode)

      generic = parsed("set_priority_org_todo", %{"bypassValidation" => true})
      refute :bypass_validation in Enum.map(generic.action.inputs, & &1.name)
      refute Map.has_key?(generic.input, :bypass_validation)
    end

    test "emitted action manifest never mentions a private argument" do
      built =
        AshSurface.Manifest.ActionManifest.build(AshSurface.Ported.RFP.manifest(), Rpc.entries())

      json = AshSurface.Manifest.ActionManifest.to_json(built)

      for private <- ~w(internalTrackingId internal_tracking_id internalAuditMode bypassValidation) do
        refute json =~ private
      end
    end
  end
end
