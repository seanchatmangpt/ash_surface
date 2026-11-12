Code.require_file("support/tc_support.exs", __DIR__)

defmodule AshSurface.Ported.TypedController.BasePathTest do
  @moduledoc """
  Port of ash_typescript typed_controller/base_path_test.exs onto descriptor-only
  `RouteSchema.build/2` (`:base_path`, `:mode`; defaults read from `AshSurface.Config`).
  `_basePath` constants and TS path helpers are not generated (README: no generated `.ts`);
  the same facts are carried by `base_path` / `full_path` / `path_template` / `mode`.
  Config-default tests mutate Application env, so this module is `async: false`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Ported.TypedController.Support, as: S

  @routes [
    S.route("auth", "get", "/auth"),
    S.route("provider_page", "get", "/auth/:provider", [S.arg("provider")]),
    S.route("login", "post", "/auth/login", [S.arg("code")])
  ]

  defp build(opts), do: elem(RouteSchema.build(@routes, opts), 1)

  defp with_env(key, value, fun) do
    prev = Application.fetch_env(:ash_surface, key)
    Application.put_env(:ash_surface, key, value)

    try do
      fun.()
    after
      case prev do
        {:ok, v} -> Application.put_env(:ash_surface, key, v)
        :error -> Application.delete_env(:ash_surface, key)
      end
    end
  end

  describe "default (no base path)" do
    test "paths remain simple and no base_path key is emitted" do
      built = build(base_path: "")

      assert Enum.map(built, & &1["path"]) |> Enum.sort() == [
               "/auth",
               "/auth/:provider",
               "/auth/login"
             ]

      for r <- built,
          do: refute(Enum.any?(["base_path", "full_path", "path_template"], &Map.has_key?(r, &1)))
    end
  end

  describe "static string base path" do
    test "every route carries base_path and a prefixed full_path" do
      for r <- build(base_path: "https://api.example.com") do
        assert r["base_path"] == "https://api.example.com"
        assert r["full_path"] == "https://api.example.com" <> r["path"]
      end
    end

    test "path params keep their descriptor and schema" do
      r = Enum.find(build(base_path: "https://api.example.com"), &(&1["name"] == "provider_page"))
      assert r["path_params"] == ["provider"]
      assert r["full_path"] == "https://api.example.com/auth/:provider"
      assert [true, false] = S.node_parse(r["params"], [%{"provider" => "x"}, %{}])
    end
  end

  describe "runtime expression base path" do
    test "routes carry the runtime expression and a ${_basePath} template" do
      for r <- build(base_path: {:runtime_expr, "AppConfig.getBasePath()"}) do
        assert r["base_path"] == %{"runtime_expr" => "AppConfig.getBasePath()"}
        assert r["path_template"] == "${_basePath}" <> r["path"]
        refute Map.has_key?(r, "full_path")
      end
    end
  end

  describe "base_path option passthrough" do
    test "option overrides the configured typed_controller_base_path" do
      with_env(:typed_controller_base_path, "https://config.example.com", fn ->
        assert Enum.all?(build([]), &(&1["base_path"] == "https://config.example.com"))

        assert Enum.all?(
                 build(base_path: "https://override.example.com"),
                 &(&1["base_path"] == "https://override.example.com")
               )
      end)
    end
  end

  describe "paths_only mode with base path" do
    test "base path is kept, schemas and request shapes are dropped" do
      built = build(base_path: "https://api.example.com", mode: :paths_only)

      for r <- built do
        assert r["mode"] == "paths_only"
        assert r["full_path"] == "https://api.example.com" <> r["path"]
        for k <- ["params", "query", "body", "response"], do: refute(Map.has_key?(r, k))
      end
    end

    test "mode is read from the typed_controller_mode config key" do
      with_env(:typed_controller_mode, :paths_only, fn ->
        assert Enum.all?(build([]), &(&1["mode"] == "paths_only"))
      end)

      assert Enum.all?(build([]), &Map.has_key?(&1, "body"))
    end
  end

  describe "controller namespace config consumers" do
    test "namespace_plan reads enable_controller_namespace_files and controller_namespace_output_dir" do
      {:ok, built} =
        RouteSchema.build(
          [S.route("a", "get", "/a", [], %{"namespace" => "ns1"}), S.route("b", "get", "/b")],
          []
        )

      assert RouteSchema.namespace_plan(built) == []

      with_env(:enable_controller_namespace_files, true, fn ->
        with_env(:controller_namespace_output_dir, "out/ns", fn ->
          assert [%{"file" => "out/ns/ns1.json", "namespace" => "ns1", "routes" => ["a"]}] =
                   RouteSchema.namespace_plan(built)
        end)
      end)
    end
  end
end
