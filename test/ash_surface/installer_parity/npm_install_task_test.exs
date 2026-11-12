defmodule AshSurface.InstallerParity.NpmInstallTaskTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  test "npm_install task runs a real npm install inside assets/", %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "assets"))
    File.write!(Path.join(dir, "assets/package.json"), ~s({"name":"x","version":"1.0.0"}\n))

    File.cd!(dir, fn ->
      Mix.Task.rerun("ash_surface.npm_install", [])
    end)

    assert File.exists?(Path.join(dir, "assets/package-lock.json"))
  end

  test "npm_install task raises when the package manager fails", %{tmp_dir: dir} do
    File.mkdir_p!(Path.join(dir, "assets"))
    File.write!(Path.join(dir, "assets/package.json"), "{not json")

    assert_raise Mix.Error, ~r/install failed/, fn ->
      File.cd!(dir, fn -> Mix.Task.rerun("ash_surface.npm_install", []) end)
    end
  end
end
