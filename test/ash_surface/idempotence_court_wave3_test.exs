defmodule AshSurface.IdempotenceCourtWave3Test do
  @moduledoc """
  W3-16 idempotence court: regenerating output twice is byte-identical across
  compiler, IR codec, JS projector, written artifacts, a real node+zod run,
  and the conformance corpus regenerator (a real `mix run` subprocess).
  No mocks, no sleeps; subprocesses are bounded by `Task.yield` deadlines.
  """
  use ExUnit.Case, async: false

  alias AshSurface.IR.Codec
  alias AshSurface.Projectors.JS
  alias AshSurface.ZodFixtures.Harness

  @moduletag timeout: 600_000
  @deadline_ms 300_000

  defp compile_irs! do
    Application.put_env(:ash_surface_zod_fixtures, :ash_domains, [AshSurface.ZodFixtures.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_zod_fixtures)
    {:ok, irs} = AshSurface.Compiler.compile(manifest)
    irs
  end

  test "compiler: two compiles of the same domain yield equal IR and equal digests" do
    a = compile_irs!()
    b = compile_irs!()
    assert a == b
    assert length(a) > 0
    da = Enum.map(a, &Codec.digest(Codec.to_map(&1)))
    db = Enum.map(b, &Codec.digest(Codec.to_map(&1)))
    assert da == db
  end

  test "codec: to_map -> from_map -> to_map is a fixed point, JSON bytes identical" do
    for ir <- compile_irs!() do
      m1 = Codec.to_map(ir)
      {:ok, back} = Codec.from_map(m1)
      m2 = Codec.to_map(back)
      assert m1 == m2
      assert Jason.encode!(m1) == Jason.encode!(m2)
      assert Codec.digest(m1) == Codec.digest(m2)
    end
  end

  test "projector: JS artifact bytes identical across repeated projections" do
    irs = compile_irs!()
    results = for _ <- 1..4, do: JS.project_ir(irs)
    assert [{:ok, arts, meta} | rest] = results
    assert Enum.all?(rest, &(&1 == {:ok, arts, meta}))
    assert arts |> Map.keys() |> Enum.sort() == ["ash_surface_client.mjs"]
    # reversed input order must not change output bytes
    assert JS.project_ir(Enum.reverse(irs)) == {:ok, arts, meta}
  end

  @tag :tmp_dir
  test "write_artifacts: two writes to separate dirs and a rewrite are byte-identical",
       %{tmp_dir: tmp} do
    {:ok, arts, _} = JS.project_ir(compile_irs!())
    p1 = JS.write_artifacts(arts, Path.join(tmp, "a"))
    JS.write_artifacts(arts, Path.join(tmp, "b"))
    before = Enum.map(p1, &File.read!/1)
    JS.write_artifacts(arts, Path.join(tmp, "a"))
    assert Enum.map(p1, &File.read!/1) == before

    for name <- Map.keys(arts) do
      assert File.read!(Path.join([tmp, "a", name])) == File.read!(Path.join([tmp, "b", name]))
      assert File.read!(Path.join([tmp, "a", name])) == Map.fetch!(arts, name)
    end
  end

  test "real node+zod: two regenerated artifacts load and print identical export surfaces" do
    node = Harness.tool!("node")

    outs =
      for _ <- 1..2 do
        ts = Harness.workspace!(Harness.artifact!())

        script = """
        const m = await import('./generated/ash_surface_client.mjs');
        const names = Object.keys(m).sort();
        const shape = {};
        for (const k of names) {
          const v = m[k];
          shape[k] = typeof v === 'function' ? 'fn' :
            (v && typeof v.safeParse === 'function') ? 'zod' :
            (v && typeof v === 'object') ? Object.keys(v).sort() : typeof v;
        }
        console.log(JSON.stringify(shape));
        """

        File.write!(Path.join(ts, "probe.mjs"), script)
        task = Task.async(fn -> Harness.run(node, ["probe.mjs"], ts) end)
        res = Task.yield(task, @deadline_ms) || Task.shutdown(task, :brutal_kill)
        Harness.cleanup!(ts)
        assert {:ok, {out, 0}} = res
        out
      end

    [o1, o2] = outs
    assert o1 == o2
    assert String.length(o1) > 10
  end

  test "ggen-owned conformance corpus: regenerating twice is byte-identical across runs" do
    root = Harness.repo_root()
    base = Path.join(System.tmp_dir!(), "w316b_conf_#{AshSurface.TestTmp.suffix()}")
    on_exit(fn -> File.rm_rf!(base) end)

    for n <- ["one", "two"] do
      out = Path.join(base, n)
      File.mkdir_p!(out)

      task =
        Task.async(fn ->
          System.cmd("mix", ["run", "scripts/conformance_regen.exs"],
            cd: root,
            stderr_to_stdout: true,
            env: [
              {"MIX_ENV", "test"},
              {"CONFORMANCE_OUT", out},
              {"MIX_BUILD_ROOT", System.get_env("MIX_BUILD_ROOT") || "_build-w316b"}
            ]
          )
        end)

      assert {:ok, {_o, 0}} = Task.yield(task, @deadline_ms) || Task.shutdown(task, :brutal_kill)
    end

    one = read_tree(Path.join(base, "one"))
    two = read_tree(Path.join(base, "two"))
    assert map_size(one) > 5
    assert one == two
  end

  defp read_tree(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Map.new(&{Path.relative_to(&1, dir), File.read!(&1)})
  end
end
