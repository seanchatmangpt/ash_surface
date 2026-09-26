defmodule AshSurface.LineageCourtBenchTest do
  @moduledoc """
  Deterministic timing benchmark + regression bound for the lineage court
  (ASF-26922-01 hardening, v26.9.26).

  Subject: a REAL git repository built in a temp dir at the PR #7 scale
  (the real head tree carries ~270 paths): 300 paths spread over 60 commits
  on a feature branch, a squash-snapshot base on main, and a plain
  reconciliation merge. The court is judged `@runs` times after one warm-up;
  median and p95 wall-clock (microseconds, `:timer.tc`) are printed as a
  `LINEAGE_COURT_BENCH` line so a receipt can cite exact numbers.

  Regression bound: the court is a fixed 10 `git` subprocesses independent of
  path count. Measured on the authoring machine (Apple silicon, 2026-09-26,
  under concurrent multi-agent compile load): median 241 ms, p95 1808 ms,
  min 120 ms. The bound (median < 2 s, p95 < 6 s) only trips on a real
  algorithmic regression -- e.g. a per-path subprocess loop at 302 paths
  costs >= 302 x ~10 ms = 3 s median -- not on scheduler noise. Every run
  must also return the identical admitted receipt.
  """

  use ExUnit.Case, async: true

  alias AshSurface.TestSupport.LineageCourt

  @runs 25
  @median_bound_us 2_000_000
  @p95_bound_us 6_000_000

  @env [
    {"GIT_CONFIG_NOSYSTEM", "1"},
    {"GIT_AUTHOR_NAME", "bench"},
    {"GIT_AUTHOR_EMAIL", "bench@example.invalid"},
    {"GIT_COMMITTER_NAME", "bench"},
    {"GIT_COMMITTER_EMAIL", "bench@example.invalid"},
    {"GIT_AUTHOR_DATE", "2026-09-26T00:00:00Z"},
    {"GIT_COMMITTER_DATE", "2026-09-26T00:00:00Z"}
  ]

  defp run!(dir, args) do
    {out, 0} =
      System.cmd("git", ["-C", dir, "-c", "commit.gpgsign=false" | args],
        stderr_to_stdout: true,
        env: @env
      )

    String.trim(out)
  end

  defp build_repo! do
    dir =
      Path.join(
        System.tmp_dir!(),
        "ash_surface_lineage_bench_#{System.unique_integer([:positive])}"
      )

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    run!(dir, ["init", "-q", "-b", "main"])
    File.mkdir_p!(Path.join(dir, "lib"))
    File.write!(Path.join(dir, "lib/formatter.ex"), "retired\n")
    File.write!(Path.join(dir, "README.md"), "snapshot\n")
    run!(dir, ["add", "-A"])
    run!(dir, ["commit", "-q", "-m", "root"])

    run!(dir, ["checkout", "-q", "-b", "feat"])
    File.rm!(Path.join(dir, "lib/formatter.ex"))

    for c <- 1..60 do
      for f <- 1..5 do
        n = (c - 1) * 5 + f
        path = Path.join(dir, "lib/mod_#{n}.ex")
        File.write!(path, "defmodule M#{n} do\n  def v, do: #{c}\nend\n")
      end

      run!(dir, ["add", "-A"])
      run!(dir, ["commit", "-q", "-m", "c#{c}"])
    end

    run!(dir, ["checkout", "-q", "main"])
    File.write!(Path.join(dir, "NOTICE"), "base-only\n")
    run!(dir, ["add", "-A"])
    run!(dir, ["commit", "-q", "-m", "squash-publish"])
    base = run!(dir, ["rev-parse", "HEAD"])

    run!(dir, ["checkout", "-q", "feat"])
    File.write!(Path.join(dir, "NOTICE"), "base-only\n")
    run!(dir, ["add", "-A"])
    run!(dir, ["commit", "-q", "-m", "carry NOTICE"])
    run!(dir, ["merge", "--no-ff", "-q", "-m", "reconcile", "main"])
    head = run!(dir, ["rev-parse", "HEAD"])

    {Path.join(dir, ".git"), base, head, run!(dir, ["rev-parse", "HEAD^{tree}"])}
  end

  test "BENCH lineage court at PR #7 scale stays within the regression bound" do
    {git_dir, base, head, head_tree} = build_repo!()

    claim = %{
      base: base,
      head: head,
      head_tree: head_tree,
      merge: head,
      retired: ["lib/formatter.ex"]
    }

    assert {:admitted, receipt} = LineageCourt.verdict(git_dir, claim)
    assert receipt.head_paths == 302

    samples =
      for _ <- 1..@runs do
        {us, result} = :timer.tc(fn -> LineageCourt.verdict(git_dir, claim) end)
        assert result == {:admitted, receipt}
        us
      end
      |> Enum.sort()

    median = Enum.at(samples, div(@runs, 2))
    p95 = Enum.at(samples, min(@runs - 1, round(@runs * 0.95) - 1))

    IO.puts(
      "LINEAGE_COURT_BENCH runs=#{@runs} paths=#{receipt.head_paths} " <>
        "median_us=#{median} p95_us=#{p95} min_us=#{hd(samples)} max_us=#{List.last(samples)}"
    )

    assert median < @median_bound_us,
           "lineage court median #{median}us exceeds bound #{@median_bound_us}us"

    assert p95 < @p95_bound_us, "lineage court p95 #{p95}us exceeds bound #{@p95_bound_us}us"
  end
end
