defmodule AshSurface.InstallerParity.FrameworkParityTest do
  use ExUnit.Case, async: false
  import Igniter.Test

  alias AshSurface.Installer.{Esbuild, Framework, Vite}

  defp content(igniter, path),
    do: igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

  defp install(igniter), do: Igniter.compose_task(igniter, "ash_surface.install", [])

  test "Framework detects esbuild from config, vite from config files, none otherwise" do
    assert Framework.detect(test_project()) == :none

    esb =
      test_project(
        files: %{"config/config.exs" => "import Config\nconfig :esbuild, version: \"0.25\"\n"}
      )

    assert Framework.detect(esb) == :esbuild

    vite = test_project(files: %{"assets/vite.config.mjs" => "export default {}\n"})
    assert Framework.detect(vite) == :vite

    dep = test_project(files: %{"assets/package.json" => ~s({"devDependencies":{"vite":"^6"}})})
    assert Framework.detect(dep) == :vite
  end

  test "Framework chooses the output file inside the bundler source tree" do
    root_vite = test_project(files: %{"vite.config.ts" => "export default {}\n"})
    assert Framework.output_file(root_vite) == "src/ash_surface/ash_surface_client.mjs"

    phoenix = test_project(files: %{"assets/vite.config.js" => "export default {}\n"})
    assert Framework.output_file(phoenix) == "assets/js/ash_surface/ash_surface_client.mjs"
  end

  test "Esbuild installer seeds output_file under assets/js and is idempotent" do
    base =
      test_project(
        files: %{"config/config.exs" => "import Config\nconfig :esbuild, version: \"0.25\"\n"}
      )

    once = base |> Esbuild.patch() |> Igniter.Test.apply_igniter!()
    twice = once |> Esbuild.patch() |> Igniter.Test.apply_igniter!()

    assert content(once, "config/config.exs") =~ "assets/js/ash_surface/ash_surface_client.mjs"
    assert content(once, "config/config.exs") == content(twice, "config/config.exs")
    assert Esbuild.notice() =~ "esbuild"
  end

  test "Vite installer seeds output_file under src/ for a root vite project and is idempotent" do
    base = test_project(files: %{"vite.config.ts" => "export default {}\n"})
    once = base |> Vite.patch() |> Igniter.Test.apply_igniter!()
    twice = once |> Vite.patch() |> Igniter.Test.apply_igniter!()

    assert content(once, "config/config.exs") =~ "src/ash_surface/ash_surface_client.mjs"
    assert content(once, "config/config.exs") == content(twice, "config/config.exs")
    assert Vite.notice() =~ "vite"
  end

  test "Vite and Esbuild are no-ops when the other bundler (or none) is detected" do
    none = test_project()

    refute Igniter.Test.apply_igniter!(Esbuild.patch(none))
           |> Igniter.exists?("config/config.exs")

    refute Igniter.Test.apply_igniter!(Vite.patch(none)) |> Igniter.exists?("config/config.exs")
  end

  test "install task honors the detected bundler output location, once" do
    base = test_project(files: %{"vite.config.ts" => "export default {}\n"})
    once = base |> install() |> Igniter.Test.apply_igniter!()
    assert content(once, "config/config.exs") =~ "src/ash_surface/ash_surface_client.mjs"
    twice = once |> install() |> Igniter.Test.apply_igniter!()
    assert content(once, "config/config.exs") == content(twice, "config/config.exs")
  end
end
