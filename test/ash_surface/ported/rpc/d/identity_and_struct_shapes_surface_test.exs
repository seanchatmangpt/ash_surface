Code.require_file("../../top/support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.D.IdentityAndStructShapesSurfaceTest do
  @moduledoc """
  Behavioral adaptation (lane TSA-T11) of the TypeScript-text tests in
  `rpc_identities_test.exs`, `rpc_mapped_identity_fields_test.exs`,
  `struct_argument_integration_test.exs` and `struct_argument_test.exs`.

  The reference regexes over generated TypeScript prove input SHAPES: which identity forms an
  action admits (`identity: UUID`, `UUID | { email: string }`, `{ email: string }`, none), which
  client-facing names an identity map uses, and which input shape a struct argument takes.
  ash_surface generates no `.ts`; the same shapes are asserted as admission behavior:

    * identity shapes through `Pipeline.resolve_identity/1` (a form the type would not allow is
      a typed refusal; an allowed form resolves to the equality filter),
    * struct argument shapes through the compiled IR (`ir.schema.input`, `ir.schema.zod`)
      executed under real node + zod.
  """
  use ExUnit.Case, async: false

  @moduletag timeout: 300_000

  alias AshSurface.Ported.{Rpc, T2, Todo}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  @uuid "11111111-1111-1111-1111-111111111111"
  @email "shape@example.com"

  defp resolve(action, identity) do
    params = %{"action" => action, "fields" => ["id"], "input" => %{}} |> put_identity(identity)
    {:ok, request} = Rpc.parse(params)

    case Pipeline.resolve_identity(request) do
      {:ok, filter} -> {:ok, filter}
      {:error, reason} -> {:error, error_type(Pipeline.error_response(reason))}
    end
  end

  defp put_identity(params, :none), do: params
  defp put_identity(params, identity), do: Map.put(params, "identity", identity)

  defp error_type(%{"success" => false, "errors" => [%{"type" => type}]}), do: type

  describe "identity forms (was: identity: UUID | { email: string } regexes)" do
    test "update_user: identity: UUID, a bare primary key resolves, an email map does not" do
      assert {:ok, [id: @uuid]} = resolve("update_user", @uuid)
      assert {:error, "invalid_identity"} = resolve("update_user", %{"email" => @email})
      assert {:error, "missing_identity"} = resolve("update_user", :none)
    end

    test "update_user_by_identity: identity union UUID | { email: string }" do
      assert {:ok, [id: @uuid]} = resolve("update_user_by_identity", @uuid)
      assert {:ok, [email: @email]} = resolve("update_user_by_identity", %{"email" => @email})
      assert {:error, "invalid_identity"} = resolve("update_user_by_identity", %{"name" => "x"})
      assert {:error, "missing_identity"} = resolve("update_user_by_identity", :none)
    end

    test "update_user_by_email: identity: { email: string } only" do
      assert {:ok, [email: @email]} = resolve("update_user_by_email", %{"email" => @email})
      assert {:error, "invalid_identity"} = resolve("update_user_by_email", @uuid)
      assert {:error, "missing_identity"} = resolve("update_user_by_email", :none)
    end

    test "update_me has no identity field: it resolves to no filter without one" do
      assert {:ok, nil} = resolve("update_me", :none)
    end
  end

  describe "mapped identity field names (was: { userId: UUID; isActive: boolean })" do
    @sub_id "44444444-4444-4444-4444-444444444444"

    for action <- ["update_subscription_by_user_status", "destroy_subscription_by_user_status"] do
      test "#{action}: identity takes the client-facing names and requires every key" do
        client = %{"userId" => @uuid, "isActive" => true}
        assert {:ok, [user_id: @uuid, is_active?: true]} = resolve(unquote(action), client)

        partial = %{"userId" => @uuid}
        assert {:error, "invalid_identity"} = resolve(unquote(action), partial)

        wrong_type = %{"userId" => @uuid, "isActive" => %{"eq" => true}}
        assert {:error, _} = resolve(unquote(action), wrong_type)
        _ = @sub_id
      end
    end
  end

  describe "struct argument input shape (was: UserInputSchema text)" do
    test "assign_to_user: assignee is a required resource reference, reason an optional string" do
      ir = T2.ir(Todo, :assign_to_user)
      input = ir.schema.input

      assert input["assignee"]["allow_nil?"] == false
      assert input["assignee"]["type"]["kind"] == "resource"
      assert input["assignee"]["type"]["instance_of"] == "AshSurface.Ported.User"
      assert input["reason"]["allow_nil?"] == true
      assert input["reason"]["optional"] == true
    end

    test "assign_to_user zod: object assignee accepted, missing/non-object refused, reason optional" do
      zod = object_zod(T2.ir(Todo, :assign_to_user))
      user = %{"id" => @uuid, "name" => "n", "email" => @email}

      check(zod, [
        {"unknown key in struct refused (strict)", %{"assignee" => Map.put(user, "bogus", 1)},
         false},
        {"wrong member type refused", %{"assignee" => %{user | "name" => 3}}, false},
        {"required member name missing refused", %{"assignee" => Map.delete(user, "name")},
         false},
        {"null for non-nullable member refused", %{"assignee" => %{user | "email" => nil}},
         false},
        {"nullable member accepts null", %{"assignee" => Map.put(user, "addressLine1", nil)},
         true},
        {"user, no reason", %{"assignee" => user}, true},
        {"user with reason", %{"assignee" => user, "reason" => "r"}, true},
        {"reason null", %{"assignee" => user, "reason" => nil}, true},
        {"no assignee", %{"reason" => "r"}, false},
        {"string assignee", %{"assignee" => "u"}, false},
        {"array assignee", %{"assignee" => [user]}, false},
        {"reason wrong type", %{"assignee" => user, "reason" => 3}, false}
      ])
    end

    test "assign_to_users: assignees is an array of resource references" do
      ir = T2.ir(Todo, :assign_to_users)
      type = ir.schema.input["assignees"]["type"]
      assert type["kind"] == "array"
      assert type["items"]["type"]["kind"] == "resource"
      assert type["items"]["type"]["instance_of"] == "AshSurface.Ported.User"

      user = %{"id" => @uuid, "name" => "n", "email" => @email}

      check(object_zod(ir), [
        {"two users", %{"assignees" => [user, user]}, true},
        {"empty list", %{"assignees" => []}, true},
        {"missing", %{}, false},
        {"not an array", %{"assignees" => user}, false},
        {"array of strings", %{"assignees" => ["u"]}, false}
      ])
    end

    test "the struct argument shape carries input fields only: no metadata keys are required" do
      zod = object_zod(T2.ir(Todo, :assign_to_user))

      # The input shape of the referenced resource is its accepted fields (name, email, ...);
      # TypeScript `__type` / `__primitiveFields` metadata never takes part in admission.
      check(zod, [
        {"fields only", %{"assignee" => %{"name" => "n", "email" => @email}}, true},
        {"metadata keys are not required", %{"assignee" => %{"name" => "n", "email" => @email}},
         true},
        {"empty object refused: name/email are required members", %{"assignee" => %{}}, false},
        {"__type metadata key is an unknown key",
         %{"assignee" => %{"name" => "n", "email" => @email, "__type" => "User"}}, false}
      ])

      # Per-field object, not the z.record(z.string(), z.unknown()) fallback.
      refute zod =~ "z.record(z.string(), z.unknown())"
      assert zod =~ "name" and zod =~ "email"

      accepted = Ash.Resource.Info.action(AshSurface.Ported.User, :create).accept
      assert :name in accepted and :email in accepted
      refute :__type in accepted
    end

    test "resources used as struct arguments are discovered from the real manifest" do
      actions = AshSurface.Ported.RFP.manifest().action_lookup

      for name <- [:assign_to_user, :assign_to_users] do
        action = Map.fetch!(actions, {Todo, name})

        assert Enum.any?(action.inputs, &(&1.type.kind in [:resource, :array])),
               "#{name}: no resource-typed input on the manifest"
      end

      {reachable, _} = Ash.Info.Manifest.Generator.Reachability.find_reachable([Todo])
      assert AshSurface.Ported.User in reachable
    end
  end

  # The input-schema expression of the emitted `<name>_inputSchema` declaration.
  defp object_zod(ir) do
    [_, expr] = Regex.run(~r/_inputSchema = (z\.object.*?\)\.passthrough\(\));/s, ir.schema.zod)
    expr
  end

  defp check(zod, cases) do
    assert {:ok, oks} = T2.node_eval(zod, Enum.map(cases, &elem(&1, 1)))

    for {{label, _payload, expected}, ok} <- Enum.zip(cases, oks) do
      assert ok == expected, "#{label}: expected accept=#{expected}, got #{ok}"
    end
  end
end
