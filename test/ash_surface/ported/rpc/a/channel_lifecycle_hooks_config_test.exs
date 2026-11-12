defmodule AshSurface.Ported.Rpc.A.ChannelLifecycleHooksConfigTest do
  use ExUnit.Case, async: false

  @keys ~w(rpc_action_before_channel_push_hook rpc_action_after_channel_response_hook
           rpc_action_channel_hook_context_type rpc_validation_before_channel_push_hook
           rpc_validation_after_channel_response_hook rpc_validation_channel_hook_context_type)a

  setup do
    # Snapshot the global hook config and restore it (value or absence) after each test.
    prev = for k <- @keys, do: {k, Application.fetch_env(:ash_surface, k)}

    on_exit(fn ->
      for {k, v} <- prev do
        case v do
          {:ok, val} -> Application.put_env(:ash_surface, k, val)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)

    :ok
  end

  describe "channel lifecycle hooks configuration" do
    test "rpc_action_before_channel_push_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_action_before_channel_push_hook)
      assert AshSurface.Config.rpc_action_before_channel_push_hook() == nil
    end

    test "rpc_action_before_channel_push_hook/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_action_before_channel_push_hook,
        "ChannelHooks.beforePush"
      )

      assert AshSurface.Config.rpc_action_before_channel_push_hook() == "ChannelHooks.beforePush"
    end

    test "rpc_action_after_channel_response_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_action_after_channel_response_hook)
      assert AshSurface.Config.rpc_action_after_channel_response_hook() == nil
    end

    test "rpc_action_after_channel_response_hook/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_action_after_channel_response_hook,
        "ChannelHooks.afterResponse"
      )

      assert AshSurface.Config.rpc_action_after_channel_response_hook() ==
               "ChannelHooks.afterResponse"
    end

    test "rpc_validation_before_channel_push_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_validation_before_channel_push_hook)
      assert AshSurface.Config.rpc_validation_before_channel_push_hook() == nil
    end

    test "rpc_validation_before_channel_push_hook/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_before_channel_push_hook,
        "ChannelHooks.beforeValidationPush"
      )

      assert AshSurface.Config.rpc_validation_before_channel_push_hook() ==
               "ChannelHooks.beforeValidationPush"
    end

    test "rpc_validation_after_channel_response_hook/0 returns nil when not configured" do
      Application.delete_env(:ash_surface, :rpc_validation_after_channel_response_hook)
      assert AshSurface.Config.rpc_validation_after_channel_response_hook() == nil
    end

    test "rpc_validation_after_channel_response_hook/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_after_channel_response_hook,
        "ChannelHooks.afterValidationResponse"
      )

      assert AshSurface.Config.rpc_validation_after_channel_response_hook() ==
               "ChannelHooks.afterValidationResponse"
    end

    test "rpc_action_channel_hook_context_type/0 returns default when not configured" do
      Application.delete_env(:ash_surface, :rpc_action_channel_hook_context_type)
      assert AshSurface.Config.rpc_action_channel_hook_context_type() == "Record<string, any>"
    end

    test "rpc_action_channel_hook_context_type/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_action_channel_hook_context_type,
        "MyChannelContext"
      )

      assert AshSurface.Config.rpc_action_channel_hook_context_type() == "MyChannelContext"
    end

    test "rpc_validation_channel_hook_context_type/0 returns default when not configured" do
      Application.delete_env(:ash_surface, :rpc_validation_channel_hook_context_type)

      assert AshSurface.Config.rpc_validation_channel_hook_context_type() ==
               "Record<string, any>"
    end

    test "rpc_validation_channel_hook_context_type/0 returns configured value" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_channel_hook_context_type,
        "MyValidationChannelContext"
      )

      assert AshSurface.Config.rpc_validation_channel_hook_context_type() ==
               "MyValidationChannelContext"
    end
  end

  describe "channel hooks enabled helpers" do
    test "rpc_action_channel_hooks_enabled?/0 returns false when no hooks configured" do
      Application.delete_env(:ash_surface, :rpc_action_before_channel_push_hook)
      Application.delete_env(:ash_surface, :rpc_action_after_channel_response_hook)
      assert AshSurface.Config.rpc_action_channel_hooks_enabled?() == false
    end

    test "rpc_action_channel_hooks_enabled?/0 returns true when beforeChannelPush hook configured" do
      Application.put_env(
        :ash_surface,
        :rpc_action_before_channel_push_hook,
        "ChannelHooks.before"
      )

      Application.delete_env(:ash_surface, :rpc_action_after_channel_response_hook)
      assert AshSurface.Config.rpc_action_channel_hooks_enabled?() == true
    end

    test "rpc_action_channel_hooks_enabled?/0 returns true when afterChannelResponse hook configured" do
      Application.delete_env(:ash_surface, :rpc_action_before_channel_push_hook)

      Application.put_env(
        :ash_surface,
        :rpc_action_after_channel_response_hook,
        "ChannelHooks.after"
      )

      assert AshSurface.Config.rpc_action_channel_hooks_enabled?() == true
    end

    test "rpc_action_channel_hooks_enabled?/0 returns true when both hooks configured" do
      Application.put_env(
        :ash_surface,
        :rpc_action_before_channel_push_hook,
        "ChannelHooks.before"
      )

      Application.put_env(
        :ash_surface,
        :rpc_action_after_channel_response_hook,
        "ChannelHooks.after"
      )

      assert AshSurface.Config.rpc_action_channel_hooks_enabled?() == true
    end

    test "rpc_validation_channel_hooks_enabled?/0 returns false when no hooks configured" do
      Application.delete_env(:ash_surface, :rpc_validation_before_channel_push_hook)
      Application.delete_env(:ash_surface, :rpc_validation_after_channel_response_hook)
      assert AshSurface.Config.rpc_validation_channel_hooks_enabled?() == false
    end

    test "rpc_validation_channel_hooks_enabled?/0 returns true when beforeChannelPush hook configured" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_before_channel_push_hook,
        "ChannelHooks.beforeValidation"
      )

      Application.delete_env(:ash_surface, :rpc_validation_after_channel_response_hook)
      assert AshSurface.Config.rpc_validation_channel_hooks_enabled?() == true
    end

    test "rpc_validation_channel_hooks_enabled?/0 returns true when afterChannelResponse hook configured" do
      Application.delete_env(:ash_surface, :rpc_validation_before_channel_push_hook)

      Application.put_env(
        :ash_surface,
        :rpc_validation_after_channel_response_hook,
        "ChannelHooks.afterValidation"
      )

      assert AshSurface.Config.rpc_validation_channel_hooks_enabled?() == true
    end

    test "rpc_validation_channel_hooks_enabled?/0 returns true when both hooks configured" do
      Application.put_env(
        :ash_surface,
        :rpc_validation_before_channel_push_hook,
        "ChannelHooks.beforeValidation"
      )

      Application.put_env(
        :ash_surface,
        :rpc_validation_after_channel_response_hook,
        "ChannelHooks.afterValidation"
      )

      assert AshSurface.Config.rpc_validation_channel_hooks_enabled?() == true
    end
  end
end
