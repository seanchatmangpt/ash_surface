defmodule AshSurface.TestSupport.CompilerEchoSection do
  @moduledoc false
  @behaviour AshSurface.Compiler.Section

  # Test double bound through `AshSurface.Compiler.compile/2`'s `:sections`
  # seam. Lives in test/support so it compiles to a beam the compiler's
  # `Code.ensure_loaded` validation can witness.

  def build(action, context) do
    key = {__MODULE__, :log}
    entry = Process.get(key, [])
    record = %{token: context.discovery.token, action_id: context.action_id, action: action}
    Process.put(key, [record | entry])

    {:ok, %{echo: context.action_id, token: context.discovery.token}}
  end
end
