defmodule AshSurface.RpcSupportInstallIsolationCourtTest do
  @moduledoc """
  RBY court: `Rpc.Support.install/2` writes one global `:persistent_term` key. Any test file whose
  AST calls `Support.install`/`Rpc.install|parse|run|error|run_with_result` (each of which
  re-installs the shared table) must declare `async: false`; an async file doing so races every
  other module (witnessed: private_arguments_surface_test `action_not_found` in a whole run).
  """
  use ExUnit.Case, async: false

  @root Path.expand("../..", __DIR__)
  @installers [:install, :parse, :run, :error, :run_with_result]

  def violations(files) do
    for f <- files, src = File.read!(f), {:ok, ast} <- [Code.string_to_quoted(src)],
        async_true?(ast), line = installer_call_line(ast), do: {Path.relative_to(f, @root), line}
  end

  defp async_true?(ast) do
    {_, found} =
      Macro.prewalk(ast, false, fn
        {{:., _, [{:__aliases__, _, [:ExUnit, :Case]}, :__info__]}, _, _} = n, a -> {n, a}
        {:use, _, [{:__aliases__, _, [:ExUnit, :Case]}, opts]} = n, a when is_list(opts) ->
          {n, a or Keyword.get(opts, :async) == true}

        n, a ->
          {n, a}
      end)

    found
  end

  defp installer_call_line(ast) do
    {_, line} =
      Macro.prewalk(ast, nil, fn
        {{:., _, [{:__aliases__, _, segs}, fun]}, meta, _} = n, nil ->
          last = List.last(segs)

          if (last == :Support and fun == :install) or (last == :Rpc and fun in @installers),
            do: {n, meta[:line] || 0},
            else: {n, nil}

        n, acc ->
          {n, acc}
      end)

    line
  end

  test "no async test file installs/re-installs the shared Rpc.Support table" do
    files = Path.wildcard(Path.join(@root, "test/**/*_test.exs"))
    assert files != []
    assert violations(files) == []
  end

  @tag :tmp_dir
  test "non-vacuous: a planted async installer is flagged, an async:false one is not", %{
    tmp_dir: dir
  } do
    bad = Path.join(dir, "bad_test.exs")
    ok = Path.join(dir, "ok_test.exs")

    File.write!(bad, """
    defmodule Bad do
      use ExUnit.Case, async: true
      test "x", do: AshSurface.RuntimeParity.Rpc.Support.install(%{}, [])
    end
    """)

    File.write!(ok, """
    defmodule Ok do
      use ExUnit.Case, async: false
      test "x", do: AshSurface.RuntimeParity.Rpc.Support.install(%{}, [])
    end
    """)

    assert [{_, 3}] = violations([bad])
    assert violations([ok]) == []
  end
end
