defmodule AshSurface.Test.RpcInstall do
  @moduledoc """
  RBY: `AshSurface.RuntimeParity.Rpc.Support.install/2` writes ONE global `:persistent_term` key
  (last writer wins). Any test that installs a table must run `async: false` and restore the
  previous value on exit. `with_restore/0` snapshots the current value and registers the
  `on_exit` restore (call it from `setup`/`setup_all`).
  """
  @key {AshSurface.RuntimeParity.Rpc.Support, :installed}

  def with_restore do
    prev = :persistent_term.get(@key, :__none__)

    ExUnit.Callbacks.on_exit(fn ->
      case prev do
        :__none__ -> :persistent_term.erase(@key)
        v -> :persistent_term.put(@key, v)
      end
    end)

    :ok
  end
end
