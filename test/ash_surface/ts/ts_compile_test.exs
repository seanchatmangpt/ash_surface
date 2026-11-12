defmodule AshSurface.TS.TsCompileTest do
  @moduledoc "Real `tsc --strict`: shouldPass compiles clean, shouldFail errors."
  use ExUnit.Case, async: false

  alias AshSurface.ZodFixtures.Harness

  setup_all do
    tsc = Harness.tool!("tsc")
    ts_dir = Harness.workspace!(Harness.artifact!())
    on_exit(fn -> Harness.cleanup!(ts_dir) end)
    %{tsc: tsc, ts_dir: ts_dir}
  end

  test "shouldPass tree compiles with zero errors", %{tsc: tsc, ts_dir: dir} do
    files =
      Path.wildcard(Path.join(dir, "shouldPass/*.ts")) |> Enum.map(&Path.relative_to(&1, dir))

    assert files != []

    {out, status} =
      Harness.run(tsc, project_for(files), dir)

    assert status == 0, "tsc shouldPass failed:\n" <> out
  end

  test "shouldFail tree produces tsc errors for every file", %{tsc: tsc, ts_dir: dir} do
    files =
      Path.wildcard(Path.join(dir, "shouldFail/*.ts")) |> Enum.map(&Path.relative_to(&1, dir))

    assert files != []

    for f <- files do
      {out, status} =
        Harness.run(
          tsc,
          [
            "--strict",
            "--noEmit",
            "--allowJs",
            "--skipLibCheck",
            "--module",
            "esnext",
            "--moduleResolution",
            "bundler",
            "--target",
            "es2022",
            f
          ],
          dir
        )

      assert status != 0, "#{f} unexpectedly compiled:\n" <> out
      assert out =~ "error TS"
    end
  end

  # Shared strict flags; no tsconfig (tsc refuses config + file args).
  defp project_for(files) do
    [
      "--strict",
      "--noEmit",
      "--allowJs",
      "--skipLibCheck",
      "--module",
      "esnext",
      "--moduleResolution",
      "bundler",
      "--target",
      "es2022"
    ] ++ files
  end
end
