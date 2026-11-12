defmodule AshSurface.Ported.Top.CodegenCheckTest do
  @moduledoc """
  Adaptation of ash_typescript `codegen_check_test.exs` onto `mix ash_surface.codegen --check`.
  The reference's "single-file output" describe ports one-to-one (stale file, `--check` vs
  `always_regenerate`, `--dev --check`). Its "manifests" (JSON/Markdown RPC manifest files) and
  "multi-file output" (`enable_namespace_files`) describes have no ash_surface counterpart (no
  manifest emission, one artifact file) and live as loud skips in `codegen_check_gap_test.exs`.
  Lib change disclosed in the lane receipt: `ash_surface.codegen` now gates `--check` unless
  BOTH `--dev` and `always_regenerate: true` (reference semantics); previously either bypassed it.
  """
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    prior = Application.fetch_env(:ash_surface, :always_regenerate)
    Application.delete_env(:ash_surface, :always_regenerate)

    on_exit(fn ->
      case prior do
        {:ok, v} -> Application.put_env(:ash_surface, :always_regenerate, v)
        :error -> Application.delete_env(:ash_surface, :always_regenerate)
      end
    end)

    output_file = Path.join(tmp_dir, "generated.mjs")
    File.write!(output_file, "")
    %{output_file: output_file}
  end

  defp run(args) do
    Mix.Task.reenable("ash_surface.codegen")

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      ExUnit.CaptureIO.capture_io(fn -> Mix.Tasks.AshSurface.Codegen.run(args) end)
    end)
  end

  describe "single-file output" do
    test "--check raises PendingCodegen when file is stale", %{output_file: file} do
      assert_raise Ash.Error.Framework.PendingCodegen, fn ->
        run(["--check", "--output", file])
      end

      assert File.read!(file) == ""
    end

    test "--check raises PendingCodegen even with always_regenerate enabled", %{output_file: file} do
      Application.put_env(:ash_surface, :always_regenerate, true)

      assert_raise Ash.Error.Framework.PendingCodegen, fn ->
        run(["--check", "--output", file])
      end

      assert File.read!(file) == ""
    end

    test "--dev --check raises PendingCodegen when always_regenerate is false", %{
      output_file: file
    } do
      Application.put_env(:ash_surface, :always_regenerate, false)

      assert_raise Ash.Error.Framework.PendingCodegen, fn ->
        run(["--dev", "--check", "--output", file])
      end

      assert File.read!(file) == ""
    end

    test "--dev --check silently regenerates when always_regenerate is true", %{
      output_file: file
    } do
      Application.put_env(:ash_surface, :always_regenerate, true)
      run(["--dev", "--check", "--output", file])
      assert File.read!(file) =~ "ash_surface"
      # and the artifact is now current: a plain --check passes
      run(["--check", "--output", file])
    end
  end
end
