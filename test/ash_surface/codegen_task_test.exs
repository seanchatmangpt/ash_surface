defmodule AshSurface.CodegenTaskTest do
  use ExUnit.Case, async: false

  alias AshSurface.Projectors.JS

  test "write_artifacts writes the artifacts map and target_dir wraps it identically" do
    {:ok, artifacts, _} = JS.project_ir([])
    a = Path.join(System.tmp_dir!(), "ash_surface_cg_a_#{AshSurface.TestTmp.suffix()}")
    b = Path.join(System.tmp_dir!(), "ash_surface_cg_b_#{AshSurface.TestTmp.suffix()}")
    on_exit(fn -> File.rm_rf(a) && File.rm_rf(b) end)

    paths = JS.write_artifacts(artifacts, a)
    {:ok, ^artifacts, _} = JS.project_ir([], target_dir: b)

    for {name, content} <- artifacts do
      assert File.read!(Path.join(a, name)) == content
      assert File.read!(Path.join(b, name)) == content
    end

    assert length(paths) == map_size(artifacts)
  end

  test "task is lenient about foreign flags and --dry-run writes nothing" do
    out = Path.join(System.tmp_dir!(), "ash_surface_cg_c_#{AshSurface.TestTmp.suffix()}")
    on_exit(fn -> File.rm_rf(out) end)

    ExUnit.CaptureIO.capture_io(fn ->
      Mix.Tasks.AshSurface.Codegen.run(["--dry-run", "--name", "x", "--output", out])
    end)

    refute File.exists?(out)
  end

  defp tmp(name) do
    dir =
      Path.join(System.tmp_dir!(), "ash_surface_cg_#{name}_#{AshSurface.TestTmp.suffix()}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp run(args) do
    Mix.Task.reenable("ash_surface.codegen")
    ExUnit.CaptureIO.capture_io(fn -> Mix.Tasks.AshSurface.Codegen.run(args) end)
  end

  test "--output FILE.mjs writes the artifact to exactly that path" do
    file = Path.join(tmp("file"), "nested/client.mjs")
    run(["--output", file])
    assert File.regular?(file)
    assert File.read!(file) =~ "ash_surface"
  end

  test "--output DIR writes the artifact under the directory" do
    dir = tmp("dir")
    run(["--output", dir])
    assert Path.wildcard(Path.join(dir, "*.mjs")) != []
  end

  test "reruns are byte-identical and unchanged files are not rewritten" do
    file = Path.join(tmp("idem"), "client.mjs")
    run(["--output", file])
    bytes = File.read!(file)
    File.touch!(file, {{2001, 1, 1}, {0, 0, 0}})
    mtime = File.stat!(file).mtime

    out = run(["--output", file])
    assert File.read!(file) == bytes
    assert File.stat!(file).mtime == mtime
    refute out =~ "wrote"
  end

  test "--check passes when disk matches" do
    file = Path.join(tmp("ok"), "client.mjs")
    run(["--output", file])
    run(["--check", "--output", file])
  end

  test "--check raises PendingCodegen with the diff on drift and writes nothing" do
    file = Path.join(tmp("drift"), "client.mjs")
    run(["--output", file])
    File.write!(file, "// drifted\n")

    err =
      assert_raise Ash.Error.Framework.PendingCodegen, fn ->
        ExUnit.CaptureIO.capture_io(:stderr, fn -> run(["--check", "--output", file]) end)
      end

    assert [{^file, diff}] = err.diff
    assert diff =~ "-// drifted"
    assert File.read!(file) == "// drifted\n"
  end

  test "--check on a missing file raises with a new-file diff" do
    file = Path.join(tmp("missing"), "client.mjs")

    err =
      assert_raise Ash.Error.Framework.PendingCodegen, fn ->
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          run(["--check", "--no-runtime", "--output", file])
        end)
      end

    assert [{^file, "(new file" <> _}] = err.diff
    refute File.exists?(file)
  end

  test "--dev --check still raises when always_regenerate is not enabled" do
    file = Path.join(tmp("dev"), "client.mjs")
    File.write!(file, "// stale\n")

    assert_raise Ash.Error.Framework.PendingCodegen, fn ->
      ExUnit.CaptureIO.capture_io(:stderr, fn -> run(["--check", "--dev", "--output", file]) end)
    end

    assert File.read!(file) == "// stale\n"
  end

  test "--dev --check with Config.always_regenerate bypasses --check and regenerates" do
    file = Path.join(tmp("always"), "client.mjs")
    File.write!(file, "// stale\n")
    prior = Application.fetch_env(:ash_surface, :always_regenerate)
    Application.put_env(:ash_surface, :always_regenerate, true)

    on_exit(fn ->
      case prior do
        {:ok, v} -> Application.put_env(:ash_surface, :always_regenerate, v)
        :error -> Application.delete_env(:ash_surface, :always_regenerate)
      end
    end)

    run(["--check", "--dev", "--output", file])
    assert File.read!(file) =~ "ash_surface"
  end

  test "--check alone raises even with Config.always_regenerate enabled" do
    file = Path.join(tmp("always_check"), "client.mjs")
    File.write!(file, "// stale\n")
    prior = Application.fetch_env(:ash_surface, :always_regenerate)
    Application.put_env(:ash_surface, :always_regenerate, true)

    on_exit(fn ->
      case prior do
        {:ok, v} -> Application.put_env(:ash_surface, :always_regenerate, v)
        :error -> Application.delete_env(:ash_surface, :always_regenerate)
      end
    end)

    assert_raise Ash.Error.Framework.PendingCodegen, fn ->
      ExUnit.CaptureIO.capture_io(:stderr, fn -> run(["--check", "--output", file]) end)
    end

    assert File.read!(file) == "// stale\n"
  end

  test "default target is read from Config.output_file" do
    file = Path.join(tmp("cfg"), "from_config.mjs")
    prior = Application.fetch_env(:ash_surface, :output_file)
    Application.put_env(:ash_surface, :output_file, file)

    on_exit(fn ->
      case prior do
        {:ok, v} -> Application.put_env(:ash_surface, :output_file, v)
        :error -> Application.delete_env(:ash_surface, :output_file)
      end
    end)

    run([])
    assert File.regular?(file)
  end

  test "invalid config aborts before writing" do
    file = Path.join(tmp("bad"), "client.mjs")
    prior = Application.fetch_env(:ash_surface, :zod_object_mode)
    Application.put_env(:ash_surface, :zod_object_mode, :loose)

    on_exit(fn ->
      case prior do
        {:ok, v} -> Application.put_env(:ash_surface, :zod_object_mode, v)
        :error -> Application.delete_env(:ash_surface, :zod_object_mode)
      end
    end)

    assert_raise ArgumentError, ~r/zod_object_mode/, fn -> run(["--output", file]) end
    refute File.exists?(file)
  end
end
