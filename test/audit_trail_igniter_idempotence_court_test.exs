

defmodule AuditTrailIgniterIdempotenceCourtTest do
  use ExUnit.Case, async: false
  # Each test drives real `mix <pkg>.install` subprocesses (which compile the vendored
  # extension package); under a loaded machine one install can exceed ExUnit's 60s
  # default, so the whole court gets a wide budget.
  @moduletag timeout: 300_000

  @package_name "audit_trail"
  @task_name "audit_trail.install"
  @extension_module "AuditTrail.Resource"
  

  @mutant_env "AEX_INSTALLER_MUTANT"

  @scratch_root System.tmp_dir!()
                |> Path.join("spark-closure-consumer-court-scratch-#{System.unique_integer([:positive])}")

  # The scratch app is a copy of the spark-closure-consumer fixture app. In a
  # standalone fixture run (mix test in packs/.../fixture) that app lives one level
  # down (fixture/spark-closure-consumer/); the court's original home had it AT cwd.
  # First candidate whose lib/spark_closure_consumer exists wins;
  # AEX_IGNITER_FIXTURE_ROOT overrides (the live chain can export it).
  @fixture_root Enum.find(
                  [
                    System.get_env("AEX_IGNITER_FIXTURE_ROOT"),
                    Path.join(File.cwd!(), "spark-closure-consumer"),
                    File.cwd!()
                  ]
                  |> Enum.reject(&is_nil/1),
                  &File.dir?(Path.join(&1, "lib/spark_closure_consumer"))
                ) || File.cwd!()

  setup do
    File.rm_rf!(@scratch_root)
    File.mkdir_p!(Path.dirname(@scratch_root))
    on_exit(fn -> File.rm_rf!(@scratch_root) end)
    :ok
  end

  test "clean install: exit 0, extension, section block and formatter plugin land" do
    scratch = fresh_scratch()
    assert {_, 0} = run_install(scratch, ["--target", "SparkClosureConsumer.Example.Post"])
    assert extension_added?(scratch)
    assert section_block?(scratch)
    assert formatter_plugin?(scratch)
  end

  test "install twice: second run is byte or AST stable" do
    scratch = fresh_scratch()
    assert {_, 0} = run_install(scratch, ["--target", "SparkClosureConsumer.Example.Post"])
    before = snapshot(scratch)
    assert {_, 0} = run_install(scratch, ["--target", "SparkClosureConsumer.Example.Post"])
    after_ = snapshot(scratch)
    assert_stable(before, after_)
  end

  test "sibling-preserved install: existing sibling extension kept, no duplicate" do
    scratch = fresh_scratch()
    post = Path.join([scratch, "lib/spark_closure_consumer/example/post.ex"])
    source = File.read!(post)
    File.write!(
      post,
      String.replace(
        source,
        "data_layer: Ash.DataLayer.Ets",
        "data_layer: Ash.DataLayer.Ets,\n    extensions: [Ash.Policy.Authorizer]"
      )
    )
    assert {_, 0} = run_install(scratch, ["--target", "SparkClosureConsumer.Example.Post"])
    source = File.read!(post)
    assert source =~ "Ash.Policy.Authorizer"
    assert source =~ @extension_module
    assert occurrences(source, @extension_module) == 1
    assert occurrences(source, "Ash.Policy.Authorizer") == 1
  end

  test "missing target resource: typed refusal, not a crash" do
    scratch = fresh_scratch()
    assert {out, exit} = run_install(scratch, ["--target", "SparkClosureConsumer.Missing.Thing"])
    assert exit != 0
    assert out =~ "SparkClosureConsumer.Missing"
    refute out =~ "no case clause"
  end

  test "formatter/plugin insertion present after install" do
    scratch = fresh_scratch()
    assert {_, 0} = run_install(scratch, ["--target", "SparkClosureConsumer.Example.Post"])
    assert formatter_plugin?(scratch)
  end

  test "install -> regenerate -> install: stable between every consecutive pair" do
    scratch = fresh_scratch()
    argv = ["--target", "SparkClosureConsumer.Example.Post"]
    assert {_, 0} = run_install(scratch, argv)
    s1 = snapshot(scratch)
    assert {_, 0} = run_install(scratch, argv)
    s2 = snapshot(scratch)
    assert_stable(s1, s2)
    assert {_, 0} = run_install(scratch, argv)
    s3 = snapshot(scratch)
    assert_stable(s2, s3)
  end

  ## -- helpers --

  defp fresh_scratch do
    File.rm_rf!(@scratch_root)
    File.mkdir_p!(@scratch_root)
    for entry <- File.ls!(@fixture_root),
        entry not in ["_build", "deps", ".fetch", "ggen.toml", "ontology.ttl", "templates", ".ggen", ".ggen-v2", "sync.json", "sync.log", ".rendered"],
        not String.starts_with?(entry, "sync-") do
      src = Path.join(@fixture_root, entry)
      dest = Path.join(@scratch_root, entry)
      if File.dir?(src), do: File.cp_r!(src, dest), else: File.cp!(src, dest)
    end
    case System.get_env(@mutant_env) do
      nil -> :ok
      "" -> :ok
      path ->
        real = Path.join([@scratch_root, "lib/mix/tasks/audit_trail.install.ex"])
        File.cp!(path, real)
    end

    # Lock the scratch's deps against the parent app's lock, so the install
    # subprocess finds locked deps in the shared MIX_DEPS_PATH instead of refusing
    # with "the dependency is not locked ... each subprocess reuses the parent's
    # compiled beams for ash/spark/igniter.
    parent_lock = Path.join(File.cwd!(), "mix.lock")

    if File.exists?(parent_lock) do
      File.cp!(parent_lock, Path.join(@scratch_root, "mix.lock"))
    end

    # The generated `mix <pkg>.install` task is projected into the live chain's
    # capsule (ASH_PACK_GENERATED/mix/tasks/) rather than living in the committed
    # consumer fixture (the standalone runner, installer_court.sh, syncs it into
    # its own capsule instead). The scratch app has neither, so copy it in.
    case System.get_env("ASH_PACK_GENERATED") do
      nil ->
        :ok

      gen ->
        task = Path.join([gen, "mix/tasks/audit_trail.install.ex"])

        if File.exists?(task) do
          dest = Path.join([@scratch_root, "lib/mix/tasks/"])
          File.mkdir_p!(dest)
          File.cp!(task, Path.join(dest, "audit_trail.install.ex"))
        end
    end

    vendor_extension_package()
    @scratch_root
  end

  # The fixture app has no hex dep on the manufactured extension package, so the
  # generated `lib/audit_trail/` projection is vendored into the scratch app as a
  # real path dependency `:audit_trail`: the extension modules must exist for the
  # patched resource to compile, and `.formatter.exs`'s `import_deps: [:audit_trail]`
  # must resolve against a real dependency.
  defp vendor_extension_package do
    # The extension lib to vendor: standalone fixture runs have lib/<pkg> under the
    # fixture dir; the live-fixture capsule exposes the generated projection at
    # ASH_PACK_GENERATED/<pkg> (copied flat, no lib/ level).
    env = System.get_env("ASH_PACK_GENERATED")

    src =
      Enum.find(
        [
          Path.join(File.cwd!(), "lib/audit_trail"),
          env && Path.join(env, "audit_trail")
        ]
        |> Enum.reject(&is_nil/1),
        &File.dir?/1
      )

    if src do
      vendor = Path.join([@scratch_root, "vendor/audit_trail"])
      File.mkdir_p!(Path.join(vendor, "lib"))
      File.cp_r!(src, Path.join(vendor, "lib/audit_trail"))
      # The vendor package ships only the DSL surface the extension needs; the
      # generated Reactor pipeline + steps are pack-level capabilities the minimal
      # fixture dep set (ash/spark/igniter/sourceror) does not include.
      File.rm_rf!(Path.join(vendor, "lib/audit_trail/reactor"))
      File.rm_rf!(Path.join(vendor, "lib/audit_trail/reactor_pipeline.ex"))

      # The pack registers aex:formatterModule into .formatter.exs but does not generate
      # the module file itself (pack gap, reported); the vendor ships a minimal
      # mix-format plugin stub so the plugin resolves.
      File.write!(Path.join(vendor, "lib/audit_trail/formatter.ex"), """
      defmodule AuditTrail.Formatter do
        @moduledoc \"\"\"
        Mix-format plugin stub (court vendor; the pack does not generate this module).
        \"\"\"

        def features(_opts), do: [extendors: [], sigils: []]
      end
      """)

      File.write!(Path.join(vendor, "mix.exs"), """
      defmodule AuditTrailPkg.MixProject do
        use Mix.Project

        def project do
          [
            app: :audit_trail,
            version: "0.1.0",
            elixir: "~> 1.18",
            deps: [
              {:spark, "~> 2.2"},
              {:ash, "~> 3.33", override: true}
            ]
          ]
        end
      end
      """)

      mix_exs = Path.join(@scratch_root, "mix.exs")
      content = File.read!(mix_exs)
      needle = "{:ash, \"~> 3.33\"},"

      unless String.contains?(content, ":audit_trail, path:") do
        File.write!(
          mix_exs,
          String.replace(
            content,
            needle,
            needle <> "\n      {:audit_trail, path: \"vendor/audit_trail\"},"
          )
        )
      end
    end
  end

  defp run_install(scratch, argv) do
    env = %{
      "MIX_ENV" => "test",
      "MIX_DEPS_PATH" => System.get_env("MIX_DEPS_PATH") || Path.join(File.cwd!(), "deps"),
      # Default to the PARENT app's build root: the scratch install only needs to
      # compile the vendored extension package, not ash/spark/igniter from scratch
      # (a per-scratch build root makes every install a multi-minute cold build and
      # times the court out). AEX_SCRATCH_BUILD_ROOT still overrides.
      "MIX_BUILD_ROOT" =>
        System.get_env("AEX_SCRATCH_BUILD_ROOT") || Path.join(File.cwd!(), "_build")
    }

    System.cmd("mix", [@task_name | argv], cd: scratch, stderr_to_stdout: true, env: env)
  end

  defp extension_added?(scratch) do
    source = File.read!(Path.join([scratch, "lib/spark_closure_consumer/example/post.ex"]))
    source =~ @extension_module
  end
  defp section_block?(scratch) do
    source = File.read!(Path.join([scratch, "lib/spark_closure_consumer/example/post.ex"]))
    source =~ "audit do"
  end
  defp formatter_plugin?(scratch) do
    fm = Path.join(scratch, ".formatter.exs")
    assert File.exists?(fm)
    {map, _} = Code.eval_string(File.read!(fm))
    import_deps = Keyword.get(map, :import_deps, [])
    assert String.to_atom(@package_name) in import_deps
    plugins = Keyword.get(map, :plugins, [])
    assert [AuditTrail.Formatter] = plugins
  end
  defp occurrences(source, str), do: length(:binary.matches(source, str))
  defp snapshot(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(fn p ->
      File.regular?(p) and
        not (p |> Path.relative_to(root) |> String.starts_with?("_build/") or
             p |> Path.relative_to(root) |> String.starts_with?("deps/"))
    end)
    |> Map.new(fn p ->
      {Path.relative_to(p, root), Base.encode16(:crypto.hash(:sha256, File.read!(p)))}
    end)
  end
  defp assert_stable(before, after_) do
    added = Map.keys(after_) -- Map.keys(before)
    removed = Map.keys(before) -- Map.keys(after_)
    changed = for {k, v} <- before, Map.get(after_, k) != v, do: k

    if added == [] and removed == [] and changed == [] do
      :ok
    else
      ast_stable? =
        changed != [] and Enum.all?(changed, fn k -> ast_equal?(before[k], after_[k]) end)

      unless ast_stable? do
        flunk("""
        install not stable between runs:
        added: #{inspect(added)}
        removed: #{inspect(removed)}
        changed: #{inspect(changed)}
        """)
      end
    end
  end

  defp ast_equal?(a, b) do
    qa = Code.string_to_quoted(a)
    qb = Code.string_to_quoted(b)

    match?({:ok, _}, qa) and match?({:ok, _}, qb) and elem(qa, 1) == elem(qb, 1)
  end
end
