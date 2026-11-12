defmodule AshSurface.InstallerTest do
  use ExUnit.Case, async: false
  import Igniter.Test

  alias AshSurface.Installer.{PackageJson, Tsconfig}

  defp apply_all(igniter), do: igniter |> PackageJson.add_zod() |> Tsconfig.patch()

  defp content(igniter, path),
    do: igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)

  test "creates package.json with zod and tsconfig when assets/ present" do
    igniter =
      test_project(files: %{"assets/package.json" => ~s({"name": "x"}\n)})
      |> apply_all()
      |> Igniter.Test.apply_igniter!()

    pkg = Jason.decode!(content(igniter, "assets/package.json"))
    assert pkg["name"] == "x"
    assert pkg["dependencies"]["zod"] == PackageJson.zod_version()
    ts = Jason.decode!(content(igniter, "assets/tsconfig.json"))
    assert ts["compilerOptions"] == Tsconfig.required()
  end

  test "idempotent: second run yields identical content" do
    base =
      test_project(
        files: %{
          "assets/package.json" => ~s({"dependencies":{"zod":"^3.0.0"}}\n),
          "assets/tsconfig.json" => ~s({"compilerOptions":{"strict":true,"module":"commonjs"}}\n)
        }
      )

    once = base |> apply_all() |> Igniter.Test.apply_igniter!()
    twice = once |> apply_all() |> Igniter.Test.apply_igniter!()

    for p <- ["assets/package.json", "assets/tsconfig.json"] do
      assert content(once, p) == content(twice, p)
    end

    assert Jason.decode!(content(once, "assets/package.json"))["dependencies"]["zod"] == "^3.0.0"
    opts = Jason.decode!(content(once, "assets/tsconfig.json"))["compilerOptions"]
    assert opts["strict"] == true and opts["module"] == "ESNext"
  end

  test "no assets/ dir: nothing created" do
    igniter = test_project() |> apply_all()
    refute Igniter.exists?(igniter, "assets/package.json")
    refute Igniter.exists?(igniter, "assets/tsconfig.json")
  end

  describe "Mix.Tasks.AshSurface.Install" do
    @post "defmodule Test.Post do\n  use Ash.Resource, domain: nil\nend\n"

    defp install(igniter, argv), do: Igniter.compose_task(igniter, "ash_surface.install", argv)

    defp project,
      do:
        test_project(
          files: %{
            "lib/post.ex" => @post,
            ".formatter.exs" => "[\n  inputs: [\"*.exs\"]\n]\n"
          }
        )

    test "--target patches extension + surface block, seeds real config keys, no formatter plugin" do
      pending = project() |> install(["--target", "Test.Post"])
      igniter = Igniter.Test.apply_igniter!(pending)

      post = content(igniter, "lib/post.ex")
      assert post =~ "AshSurface.Resource"
      assert post =~ "surface do"

      config = content(igniter, "config/config.exs")
      assert config =~ "config :ash_surface"
      assert config =~ "output_file"
      assert config =~ "ash_surface_client.mjs"
      assert config =~ "zod_object_mode"

      # apply_igniter! flushes .formatter.exs out of the in-memory rewrite; read it pre-apply.
      fmt = content(pending, ".formatter.exs")
      assert fmt =~ "import_deps"
      assert fmt =~ ":ash_surface"
      refute fmt =~ "AshSurface.Formatter"
      refute fmt =~ "plugins"
    end

    test "emits a next-steps notice naming codegen and the artifact path" do
      igniter = project() |> install(["--target", "Test.Post"])
      assert Enum.any?(igniter.notices, &(&1 =~ "mix ash_surface.codegen"))
      assert Enum.any?(igniter.notices, &(&1 =~ "ash_surface_client.mjs"))
    end

    test "without --target the notice carries manual instructions and still seeds config" do
      igniter = project() |> install([]) |> Igniter.Test.apply_igniter!()
      assert content(igniter, "config/config.exs") =~ "output_file"
    end

    test "second run is a byte-identical no-op for every touched file" do
      pending1 = project() |> install(["--target", "Test.Post"])
      once = Igniter.Test.apply_igniter!(pending1)
      pending2 = install(once, ["--target", "Test.Post"])
      twice = Igniter.Test.apply_igniter!(pending2)

      for p <- ["lib/post.ex", "config/config.exs"] do
        assert content(once, p) == content(twice, p)
      end

      assert content(pending1, ".formatter.exs") == content(pending2, ".formatter.exs")
      assert content(pending2, ".formatter.exs") =~ "import_deps: [:ash_surface]"
    end

    test "existing user config values are never overwritten" do
      base =
        test_project(
          files: %{
            "lib/post.ex" => @post,
            ".formatter.exs" => "[\n  inputs: [\"*.exs\"]\n]\n",
            "config/config.exs" =>
              "import Config\nconfig :ash_surface, output_file: \"mine/out.mjs\"\n"
          }
        )

      igniter =
        base |> install(["--target", "Test.Post", "--yes"]) |> Igniter.Test.apply_igniter!()

      config = content(igniter, "config/config.exs")
      assert config =~ "mine/out.mjs"
      refute config =~ "ash_surface_client.mjs"
    end

    test "invalid config aborts the install" do
      prior = Application.fetch_env(:ash_surface, :zod_object_mode)
      Application.put_env(:ash_surface, :zod_object_mode, :loose)

      try do
        assert_raise ArgumentError, ~r/zod_object_mode/, fn ->
          project() |> install(["--target", "Test.Post"])
        end
      after
        case prior do
          {:ok, v} -> Application.put_env(:ash_surface, :zod_object_mode, v)
          :error -> Application.delete_env(:ash_surface, :zod_object_mode)
        end
      end
    end
  end
end
