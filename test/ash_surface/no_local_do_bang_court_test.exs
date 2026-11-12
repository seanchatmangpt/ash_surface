defmodule AshSurface.NoLocalDoBangCourtTest do
  @moduledoc """
  Non-vacuity court for the no-local-DO tripwire's bang variants. A scratch COPY
  of lib/ + the tripwire is mutated with `Ash.create!(Resource, %{})` (and the
  other bang action funs); the tripwire, run as a real `elixir` subprocess over
  the scratch tree, must FAIL. Restore is sha256 byte-exact; a self-check
  corrupts a restore and proves the detector notices.
  """
  use ExUnit.Case, async: false
  @moduletag timeout: 300_000

  @repo Path.expand("../..", __DIR__)
  @bangs ~w(create! update! destroy! calculate! bulk_create! bulk_update! bulk_destroy! run_action!)

  defp sha(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  defp scratch! do
    dir = Path.join(System.tmp_dir!(), "f1nb_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(dir, "test/ash_surface"))
    File.cp_r!(Path.join(@repo, "lib"), Path.join(dir, "lib"))

    src = File.read!(Path.join(@repo, "test/ash_surface/no_local_do_test.exs"))

    File.write!(
      Path.join(dir, "test/ash_surface/no_local_do_test.exs"),
      String.replace(src, "AshSurface.NoLocalDoTest", "ScratchNoLocalDoTest")
    )

    File.write!(Path.join(dir, "run.exs"), """
    ExUnit.start()
    Code.require_file("test/ash_surface/no_local_do_test.exs", #{inspect(dir)})
    """)

    dir
  end

  defp tripwire(dir) do
    {out, rc} = System.cmd("elixir", ["run.exs"], cd: dir, stderr_to_stdout: true)
    {rc, out}
  end

  defp restore_ok?(target, baseline), do: File.exists?(target) and sha(target) == baseline

  test "baseline scratch copy passes the tripwire" do
    dir = scratch!()
    on_exit(fn -> File.rm_rf!(dir) end)
    {rc, out} = tripwire(dir)
    assert rc == 0, out
  end

  test "every bang action fun mutation is flagged, and restore is byte-exact" do
    dir = scratch!()
    on_exit(fn -> File.rm_rf!(dir) end)
    target = Path.join(dir, "lib/ash_surface/zz_bang_mut.ex")
    File.write!(target, "defmodule AshSurface.ZzBangMut do\n  def ok, do: :ok\nend\n")
    baseline = sha(target)

    defs =
      for {fun, i} <- Enum.with_index(@bangs), mod <- ["Ash", "Some.Api"] do
        "  def f#{i}_#{String.replace(mod, ".", "")}, do: #{mod}.#{fun}(Some.Resource, %{})\n"
      end

    File.write!(target, "defmodule AshSurface.ZzBangMut do\n#{defs}end\n")
    {rc, out} = tripwire(dir)
    assert rc != 0, "tripwire did not flag bang mutations"
    assert out =~ "zz_bang_mut.ex"

    for fun <- @bangs, mod <- ["Ash", "Some.Api"] do
      assert out =~ "#{mod}.#{fun} ", "tripwire did not flag #{mod}.#{fun}"
    end

    File.write!(target, "defmodule AshSurface.ZzBangMut do\n  def ok, do: :ok\nend\n")
    assert restore_ok?(target, baseline)
    {rc, out} = tripwire(dir)
    assert rc == 0, out
  end

  test "self-check: a corrupted restore is detected" do
    dir = scratch!()
    on_exit(fn -> File.rm_rf!(dir) end)
    target = Path.join(dir, "lib/ash_surface/zz_bang_mut.ex")
    File.write!(target, "defmodule AshSurface.ZzBangMut do\nend\n")
    baseline = sha(target)
    File.write!(target, "defmodule AshSurface.ZzBangMut do\nend\n\n")
    refute restore_ok?(target, baseline)
  end
end
