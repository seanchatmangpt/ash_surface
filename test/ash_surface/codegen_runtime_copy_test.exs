defmodule AshSurface.CodegenRuntimeCopyTest do
  use ExUnit.Case, async: false

  @files ~w(ash_surface_runtime.mjs ash_surface_http_transport.mjs
            ash_surface_channel_transport.mjs)

  defp tmp do
    dir = Path.join(System.tmp_dir!(), "ash_surface_rt_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp run(args) do
    Mix.Task.reenable("ash_surface.codegen")

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      ExUnit.CaptureIO.capture_io(fn -> Mix.Tasks.AshSurface.Codegen.run(args) end)
    end)
  end

  defp src(name), do: File.read!(Path.join("priv/static", name))

  test "copies byte-equal runtime files next to artifacts" do
    dir = tmp()
    run(["--output", dir])

    for f <- @files, do: assert(File.read!(Path.join(dir, f)) == src(f))
  end

  test "re-run is idempotent: mtimes untouched" do
    dir = tmp()
    run(["--output", dir])
    path = Path.join(dir, hd(@files))
    File.touch!(path, {{2020, 1, 1}, {0, 0, 0}})
    before = File.stat!(path).mtime
    run(["--output", dir])
    assert File.stat!(path).mtime == before
  end

  test "--check raises when a runtime copy is stale or missing, passes when fresh" do
    dir = tmp()
    run(["--output", dir])
    run(["--check", "--output", dir])

    File.write!(Path.join(dir, hd(@files)), "stale")
    assert_raise Ash.Error.Framework.PendingCodegen, fn -> run(["--check", "--output", dir]) end

    File.rm!(Path.join(dir, List.last(@files)))
    assert_raise Ash.Error.Framework.PendingCodegen, fn -> run(["--check", "--output", dir]) end
  end

  test "--no-runtime skips the copies" do
    dir = tmp()
    run(["--no-runtime", "--output", dir])
    for f <- @files, do: refute(File.exists?(Path.join(dir, f)))
  end

  test "every package.json export exists on disk" do
    exports = "package.json" |> File.read!() |> Jason.decode!() |> Map.fetch!("exports")
    assert map_size(exports) >= 3

    for {_sub, path} <- exports, do: assert(File.regular?(path), "missing #{path}")
  end
end
