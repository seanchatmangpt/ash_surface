defmodule AshSurface.Ported.Top.EmptyManifestCodegenTest do
  @moduledoc """
  Adaptation of ash_typescript `empty_manifest_codegen_test.exs`: codegen over a manifest with no
  domains/entrypoints (fresh install) terminates and succeeds. ash_surface counterpart: the real
  compiler over an empty `%Ash.Info.Manifest{}` returns `{:ok, []}` and the JS projector over the
  empty IR list returns an artifacts map, both within a bounded deadline (no hang, no crash), and
  the codegen task over an app with no resources writes nothing it cannot regenerate.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Compiler, Projectors.JS}

  @deadline_ms 10_000

  defp bounded(fun) do
    task = Task.async(fun)

    case Task.yield(task, @deadline_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> flunk("codegen hung on an empty manifest (exceeded #{@deadline_ms}ms)")
      {:exit, reason} -> flunk("codegen crashed on empty manifest: #{inspect(reason)}")
    end
  end

  test "codegen terminates and succeeds with an empty manifest (fresh install)" do
    result =
      bounded(fn ->
        with {:ok, irs} <- Compiler.compile(%Ash.Info.Manifest{entrypoints: []}),
             {:ok, files, meta} <- JS.project_ir(irs) do
          {:ok, files, meta}
        end
      end)

    case result do
      {:ok, files, meta} ->
        assert [{name, code}] = Map.to_list(files)
        assert String.ends_with?(name, ".mjs")
        assert is_binary(code) and code != ""
        assert meta.action_count == 0
        assert meta.namespace_count == 0

      {:error, message} -> flunk("codegen errored on empty manifest: #{inspect(message)}")
    end
  end
end
