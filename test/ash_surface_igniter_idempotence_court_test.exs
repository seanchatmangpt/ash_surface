defmodule AshSurfaceIgniterIdempotenceCourtTest do
  use ExUnit.Case, async: false
  # Each test drives real `mix <pkg>.install` subprocesses (which compile the vendored
  # extension package); under a loaded machine one install can exceed ExUnit's 60s
  # default, so the whole court gets a wide budget.
  # Per-test ExUnit budget is above the per-install deadline below so a slow-but-live
  # install is bounded by run_bounded/3 (typed exit 124), not by an opaque ExUnit timeout.
  @moduletag timeout: 720_000
  @install_deadline_ms 600_000

  @package_name "ash_surface"
  @task_name "ash_surface.install"
  @extension_module "AshSurface.Resource"

  @mutant_env "AEX_INSTALLER_MUTANT"

  # Vendored files are DERIVED, never listed: the compile closure of the modules the
  # installer needs, computed from the AST of lib/ash_surface (alias-expanded module
  # references, transitive). Seeds: the extension module under test (@extension_module)
  # plus every module the real install task references.
  @install_task_rel "lib/mix/tasks/ash_surface.install.ex"

  @scratch_root System.tmp_dir!()
                |> Path.join(
                  "spark-closure-consumer-court-scratch-#{AshSurface.TestTmp.suffix()}"
                )

  # The scratch app is a copy of the spark-closure-consumer fixture app. In a
  # standalone fixture run (mix test in packs/.../fixture) that app lives one level
  # down (fixture/spark-closure-consumer/); the court's original home had it AT cwd.
  # First candidate whose lib/spark_closure_consumer exists wins;
  # AEX_IGNITER_FIXTURE_ROOT overrides (the live chain can export it).
  @fixture_root Enum.find(
                  [
                    System.get_env("AEX_IGNITER_FIXTURE_ROOT"),
                    Path.join(File.cwd!(), "spark-closure-consumer"),
                    # This checkout vendors the fixture app at fixture/spark-closure-consumer
                    # (a tiny real Mix project: one Ash resource + domain, ets, no network).
                    Path.join(File.cwd!(), "fixture/spark-closure-consumer"),
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

  test "clean install: exit 0, extension, section block and formatter import_deps land (no retired plugin)" do
    scratch = fresh_scratch()
    assert {_, 0} = run_install(scratch, ["--target", "SparkClosureConsumer.Example.Post"])
    assert extension_added?(scratch)
    assert section_block?(scratch)
    assert formatter_wired?(scratch)
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
    assert formatter_wired?(scratch)
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
        entry not in [
          "_build",
          "deps",
          ".fetch",
          "ggen.toml",
          "ontology.ttl",
          "templates",
          ".ggen",
          ".ggen-v2",
          "sync.json",
          "sync.log",
          ".rendered"
        ],
        not String.starts_with?(entry, "sync-"),
        # sibling lanes' _build-* roots are transient; never part of the fixture copy
        not String.starts_with?(entry, "_build") do
      src = Path.join(@fixture_root, entry)
      dest = Path.join(@scratch_root, entry)
      if File.dir?(src), do: File.cp_r!(src, dest), else: File.cp!(src, dest)
    end

    case System.get_env(@mutant_env) do
      nil ->
        :ok

      "" ->
        :ok

      path ->
        real = Path.join([@scratch_root, "lib/mix/tasks/ash_surface.install.ex"])
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
        # In-repo run: the real installer task lives in this checkout's lib/mix/tasks.
        task = Path.join(File.cwd!(), "lib/mix/tasks/ash_surface.install.ex")
        dest = Path.join([@scratch_root, "lib/mix/tasks/"])
        File.mkdir_p!(dest)
        File.cp!(task, Path.join(dest, "ash_surface.install.ex"))

      gen ->
        task = Path.join([gen, "mix/tasks/ash_surface.install.ex"])

        if File.exists?(task) do
          dest = Path.join([@scratch_root, "lib/mix/tasks/"])
          File.mkdir_p!(dest)
          File.cp!(task, Path.join(dest, "ash_surface.install.ex"))
        end
    end

    vendor_extension_package()
    @scratch_root
  end

  # The fixture app has no hex dep on the manufactured extension package, so the
  # generated `lib/ash_surface/` projection is vendored into the scratch app as a
  # real path dependency `:ash_surface`: the extension modules must exist for the
  # patched resource to compile, and `.formatter.exs`'s `import_deps: [:ash_surface]`
  # must resolve against a real dependency.
  defp vendor_closure(src) do
    files =
      for path <- Path.wildcard(Path.join(src, "**/*.ex")), into: %{} do
        {Path.relative_to(path, src), parse_module_refs(path)}
      end

    defined = for {rel, {defs, _, _}} <- files, m <- defs, into: %{}, do: {m, rel}

    {_, task_refs, _} = parse_module_refs(Path.join(File.cwd!(), @install_task_rel))

    seeds =
      for m <- [Module.concat([@extension_module]) | task_refs],
          f = Map.get(defined, m),
          uniq: true,
          do: f

    reach = walk(seeds, MapSet.new(), files, defined)
    reach |> prune(files, defined) |> MapSet.to_list() |> Enum.sort()
  end

  defp walk([], seen, _files, _defined), do: seen

  defp walk([rel | rest], seen, files, defined) do
    if MapSet.member?(seen, rel) do
      walk(rest, seen, files, defined)
    else
      {_, refs, _} = Map.fetch!(files, rel)
      deps = for m <- refs, f = Map.get(defined, m), do: f
      # Elixir layout convention: foo.ex owns the foo/ namespace dir (reached by atom or
      # DSL reference, not by a struct/alias edge).
      ns = Path.rootname(rel) <> "/"
      deps = deps ++ for f <- Map.keys(files), String.starts_with?(f, ns), do: f
      walk(deps ++ rest, MapSet.put(seen, rel), files, defined)
    end
  end

  defp prune(set, files, defined) do
    bad =
      Enum.filter(set, fn rel ->
        {_, _, compile_refs} = Map.fetch!(files, rel)

        Enum.any?(compile_refs, fn m ->
          case Map.get(defined, m) do
            nil -> not vendor_available?(m)
            f -> not MapSet.member?(set, f)
          end
        end)
      end)

    if bad == [], do: set, else: prune(MapSet.difference(set, MapSet.new(bad)), files, defined)
  end

  # External module satisfiable with the vendor package's deps: the transitive
  # application closure of spark + ash (which brings decimal, jason, ... and stdlib).
  defp vendor_available?(m) do
    Code.ensure_loaded?(m) and Application.get_application(m) in vendor_apps()
  end

  defp vendor_apps, do: app_closure([:spark, :ash], [])

  defp app_closure([], seen), do: seen

  defp app_closure([app | rest], seen) do
    if app in seen do
      app_closure(rest, seen)
    else
      _ = Application.load(app)
      app_closure((Application.spec(app, :applications) || []) ++ rest, [app | seen])
    end
  end

  # {defined modules, referenced modules (aliases expanded)} for one source file.
  defp parse_module_refs(path) do
    ast = path |> File.read!() |> Code.string_to_quoted!()

    {_, acc} =
      Macro.prewalk(ast, %{defs: [], aliases: %{}, refs: []}, fn
        {:defmodule, _, [{:__aliases__, _, parts} | _]} = n, acc ->
          {n, %{acc | defs: [Module.concat(parts) | acc.defs]}}

        {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, subs}]} = n, acc ->
          al =
            for {:__aliases__, _, sub} <- subs, into: acc.aliases do
              {List.first(sub), base ++ sub}
            end

          {n, %{acc | aliases: al}}

        {:alias, _, [{:__aliases__, _, parts}]} = n, acc ->
          {n, %{acc | aliases: Map.put(acc.aliases, List.last(parts), parts)}}

        {:alias, _, [{:__aliases__, _, parts}, [as: {:__aliases__, _, [as]}]]} = n, acc ->
          {n, %{acc | aliases: Map.put(acc.aliases, as, parts)}}

        n, acc ->
          {n, acc}
      end)

    # Compile-time edges: struct expansion, use/import/require, @behaviour. A file whose
    # compile-time edge cannot be satisfied inside the vendor package (ash_r2rml/a2a, or a
    # lib module outside the closure) is pruned, so the closure compiles with only the
    # vendor mix.exs deps (spark, ash).
    expand = fn parts ->
      [first | rest] = parts
      Module.concat(Map.get(acc.aliases, first, [first]) ++ rest)
    end

    {_, all_refs} =
      Macro.prewalk(ast, [], fn
        {:__aliases__, _, [f | _] = parts} = n, refs when is_atom(f) ->
          {n, [expand.(parts) | refs]}

        n, refs ->
          {n, refs}
      end)

    {_, refs} =
      Macro.prewalk(ast, [], fn
        {:%, _, [{:__aliases__, _, [f | _] = parts}, _]} = n, refs when is_atom(f) ->
          {n, [expand.(parts) | refs]}

        {d, _, [{:__aliases__, _, [f | _] = parts} | _]} = n, refs
        when d in [:use, :import, :require] and is_atom(f) ->
          {n, [expand.(parts) | refs]}

        {:@, _, [{:behaviour, _, [{:__aliases__, _, [f | _] = parts}]}]} = n, refs
        when is_atom(f) ->
          {n, [expand.(parts) | refs]}

        n, refs ->
          {n, refs}
      end)

    {acc.defs, all_refs, refs}
  end

  defp vendor_extension_package do
    # The extension lib to vendor: standalone fixture runs have lib/<pkg> under the
    # fixture dir; the live-fixture capsule exposes the generated projection at
    # ASH_PACK_GENERATED/<pkg> (copied flat, no lib/ level).
    env = System.get_env("ASH_PACK_GENERATED")

    src =
      Enum.find(
        [
          Path.join(File.cwd!(), "lib/ash_surface"),
          env && Path.join(env, "ash_surface")
        ]
        |> Enum.reject(&is_nil/1),
        &File.dir?/1
      )

    if src do
      vendor = Path.join([@scratch_root, "vendor/ash_surface"])
      File.mkdir_p!(Path.join(vendor, "lib"))
      # Vendor ONLY the derived compile closure of the installer (see vendor_closure/1).
      for rel <- vendor_closure(src) do
        from = Path.join(src, rel)
        to = Path.join(vendor, Path.join("lib/ash_surface", rel))
        File.mkdir_p!(Path.dirname(to))
        File.cp!(from, to)
      end

      File.write!(Path.join(vendor, "mix.exs"), """
      defmodule AshSurfacePkg.MixProject do
        use Mix.Project

        def project do
          [
            app: :ash_surface,
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

      unless String.contains?(content, ":ash_surface, path:") do
        File.write!(
          mix_exs,
          String.replace(
            content,
            needle,
            needle <> "\n      {:ash_surface, path: \"vendor/ash_surface\"},"
          )
        )
      end
    end
  end

  # The scratch app vendors a SUBSET of this package under the same app name, so it must
  # never compile into the parent's build root (it would clobber the parent's beams).
  # Seed a sibling root from the parent's compiled deps (minus :ash_surface) once.
  defp court_build_root do
    parent = System.get_env("MIX_BUILD_ROOT") || Path.join(File.cwd!(), "_build")
    root = parent <> "-igniter-court"
    marker = Path.join(root, ".seeded")

    unless File.exists?(marker) do
      File.rm_rf!(root)
      if File.dir?(parent), do: File.cp_r!(parent, root)

      for lib <- Path.wildcard(Path.join(root, "*/lib/ash_surface")), do: File.rm_rf!(lib)

      File.mkdir_p!(root)
      File.write!(marker, "seeded\n")
    end

    root
  end

  defp run_install(scratch, argv) do
    env = %{
      "MIX_ENV" => "test",
      "MIX_DEPS_PATH" => System.get_env("MIX_DEPS_PATH") || Path.join(File.cwd!(), "deps"),
      # Default to the PARENT app's build root: the scratch install only needs to
      # compile the vendored extension package, not ash/spark/igniter from scratch
      # (a per-scratch build root makes every install a multi-minute cold build and
      # times the court out). AEX_SCRATCH_BUILD_ROOT still overrides.
      "MIX_BUILD_ROOT" => System.get_env("AEX_SCRATCH_BUILD_ROOT") || court_build_root()
    }

    {out, code} = result = run_bounded([@task_name | argv], scratch, env)

    # ExUnit truncates the {out, code} diff; keep the full output of a failed install.
    if code != 0,
      do:
        File.write!(
          Path.join(
            System.tmp_dir!(),
            "ash_surface_install_failure.txt"
          ),
          out
        )

    result
  end

  # Each install is a real `mix` subprocess that compiles the vendored extension package
  # (measured 175-580s on a loaded machine, first call also seeds the court build root), so
  # the court is legitimately slow, not hung. The deadline is an observable bound, never a
  # sleep: Task.yield returns as soon as the subprocess finishes, and a subprocess that
  # outlives @install_deadline_ms fails the test with a typed exit 124 instead of eating
  # the whole ExUnit timeout.
  defp run_bounded(argv, scratch, env) do
    task =
      Task.async(fn ->
        System.cmd("mix", argv, cd: scratch, stderr_to_stdout: true, env: env)
      end)

    case Task.yield(task, @install_deadline_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, reason} -> {"install subprocess exited: #{inspect(reason)}", 125}
      nil -> {"install exceeded #{@install_deadline_ms}ms deadline", 124}
    end
  end

  defp extension_added?(scratch) do
    source = File.read!(Path.join([scratch, "lib/spark_closure_consumer/example/post.ex"]))
    source =~ @extension_module
  end

  defp section_block?(scratch) do
    source = File.read!(Path.join([scratch, "lib/spark_closure_consumer/example/post.ex"]))
    source =~ "surface do"
  end

  defp formatter_wired?(scratch) do
    fm = Path.join(scratch, ".formatter.exs")
    assert File.exists?(fm)
    {map, _} = Code.eval_string(File.read!(fm))
    import_deps = Keyword.get(map, :import_deps, [])
    assert String.to_atom(@package_name) in import_deps
    # AshSurface.Formatter is retired (formatter_registration_canary_test LAW 2):
    # the installer must wire import_deps only, never a plugin.
    plugins = Keyword.get(map, :plugins, [])
    refute AshSurface.Formatter in plugins
    true
  end

  defp occurrences(source, str), do: length(:binary.matches(source, str))

  defp snapshot(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(fn p ->
      File.regular?(p) and
        not (p |> Path.relative_to(root) |> String.starts_with?("_build") or
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
