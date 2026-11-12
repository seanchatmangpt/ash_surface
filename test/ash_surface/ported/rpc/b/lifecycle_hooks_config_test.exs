defmodule AshSurface.Ported.Rpc.B.LifecycleHooksConfigTest do
  # async: false (global application env).
  use ExUnit.Case, async: false

  @keys [
    :rpc_action_before_request_hook,
    :rpc_action_after_request_hook,
    :rpc_validation_before_request_hook,
    :rpc_validation_after_request_hook,
    :rpc_action_hook_context_type,
    :rpc_validation_hook_context_type
  ]

  setup do
    snapshot = for k <- @keys, do: {k, Application.fetch_env(:ash_surface, k)}

    on_exit(fn ->
      for {k, res} <- snapshot do
        case res do
          {:ok, v} -> Application.put_env(:ash_surface, k, v)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)

    :ok
  end

  describe "lifecycle hooks configuration" do
    test "rpc_action_before_request_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_action_before_request_hook)
      assert AshSurface.Config.rpc_action_before_request_hook() == nil
    end

    test "rpc_action_before_request_hook/0 returns configured value" do
      Application.put_env(:ash_surface, :rpc_action_before_request_hook, "myHooks.before")
      assert AshSurface.Config.rpc_action_before_request_hook() == "myHooks.before"
    end

    test "rpc_action_after_request_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_action_after_request_hook)
      assert AshSurface.Config.rpc_action_after_request_hook() == nil
    end

    test "rpc_action_after_request_hook/0 returns configured value" do
      Application.put_env(:ash_surface, :rpc_action_after_request_hook, "myHooks.after")
      assert AshSurface.Config.rpc_action_after_request_hook() == "myHooks.after"
    end

    test "rpc_validation_before_request_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_validation_before_request_hook)
      assert AshSurface.Config.rpc_validation_before_request_hook() == nil
    end

    test "rpc_validation_before_request_hook/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_before_request_hook,
        "myHooks.beforeValidation"
      )

      assert AshSurface.Config.rpc_validation_before_request_hook() == "myHooks.beforeValidation"
    end

    test "rpc_validation_after_request_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_validation_after_request_hook)
      assert AshSurface.Config.rpc_validation_after_request_hook() == nil
    end

    test "rpc_validation_after_request_hook/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_after_request_hook,
        "myHooks.afterValidation"
      )

      assert AshSurface.Config.rpc_validation_after_request_hook() == "myHooks.afterValidation"
    end

    test "rpc_action_hook_context_type/0 returns default when not configured" do
      Application.delete_env(:ash_surface, :rpc_action_hook_context_type)
      assert AshSurface.Config.rpc_action_hook_context_type() == "Record<string, any>"
    end

    test "rpc_action_hook_context_type/0 returns configured value" do
      Application.put_env(:ash_surface, :rpc_action_hook_context_type, "MyCustomType")
      assert AshSurface.Config.rpc_action_hook_context_type() == "MyCustomType"
    end

    test "rpc_validation_hook_context_type/0 returns default when not configured" do
      Application.delete_env(:ash_surface, :rpc_validation_hook_context_type)
      assert AshSurface.Config.rpc_validation_hook_context_type() == "Record<string, any>"
    end

    test "rpc_validation_hook_context_type/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_hook_context_type,
        "MyValidationType"
      )

      assert AshSurface.Config.rpc_validation_hook_context_type() == "MyValidationType"
    end
  end

  describe "hooks enabled helpers" do
    test "rpc_action_hooks_enabled?/0 returns false when no hooks configured" do
      Application.delete_env(:ash_surface, :rpc_action_before_request_hook)
      Application.delete_env(:ash_surface, :rpc_action_after_request_hook)
      assert AshSurface.Config.rpc_action_hooks_enabled?() == false
    end

    test "rpc_action_hooks_enabled?/0 returns true when beforeRequest hook configured" do
      Application.put_env(:ash_surface, :rpc_action_before_request_hook, "myHooks.before")
      Application.delete_env(:ash_surface, :rpc_action_after_request_hook)
      assert AshSurface.Config.rpc_action_hooks_enabled?() == true
    end

    test "rpc_action_hooks_enabled?/0 returns true when afterRequest hook configured" do
      Application.delete_env(:ash_surface, :rpc_action_before_request_hook)
      Application.put_env(:ash_surface, :rpc_action_after_request_hook, "myHooks.after")
      assert AshSurface.Config.rpc_action_hooks_enabled?() == true
    end

    test "rpc_action_hooks_enabled?/0 returns true when both hooks configured" do
      Application.put_env(:ash_surface, :rpc_action_before_request_hook, "myHooks.before")
      Application.put_env(:ash_surface, :rpc_action_after_request_hook, "myHooks.after")
      assert AshSurface.Config.rpc_action_hooks_enabled?() == true
    end

    test "rpc_validation_hooks_enabled?/0 returns false when no hooks configured" do
      Application.delete_env(:ash_surface, :rpc_validation_before_request_hook)
      Application.delete_env(:ash_surface, :rpc_validation_after_request_hook)
      assert AshSurface.Config.rpc_validation_hooks_enabled?() == false
    end

    test "rpc_validation_hooks_enabled?/0 returns true when beforeRequest hook configured" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_before_request_hook,
        "myHooks.beforeValidation"
      )

      Application.delete_env(:ash_surface, :rpc_validation_after_request_hook)
      assert AshSurface.Config.rpc_validation_hooks_enabled?() == true
    end

    test "rpc_validation_hooks_enabled?/0 returns true when afterRequest hook configured" do
      Application.delete_env(:ash_surface, :rpc_validation_before_request_hook)

      Application.put_env(
        :ash_surface,
        :rpc_validation_after_request_hook,
        "myHooks.afterValidation"
      )

      assert AshSurface.Config.rpc_validation_hooks_enabled?() == true
    end

    test "rpc_validation_hooks_enabled?/0 returns true when both hooks configured" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_before_request_hook,
        "myHooks.beforeValidation"
      )

      Application.put_env(
        :ash_surface,
        :rpc_validation_after_request_hook,
        "myHooks.afterValidation"
      )

      assert AshSurface.Config.rpc_validation_hooks_enabled?() == true
    end
  end
end
