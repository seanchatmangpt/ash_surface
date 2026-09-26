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

  Regression bound: the court is a fixed 11 `git` subprocesses independent of
  path count. Measured on the authoring machine (Apple silicon, 2026-09-26,
  under concurrent multi-agent compile load): median 241 ms, p95 1808 ms,
  min 120 ms. The bound (median < 2 s, p95 < 6 s) trips on a per-HEAD-path
  loop of real object-database git calls (measured: `git cat-file -e` over
  the 302 head paths exceeds it), not on scheduler noise. It does NOT catch
  a loop of cheap subprocesses over a handful of paths (measured: a
  `git --version` loop over 3 base paths stays under the bound); that class
  is out of scope for a wall-clock bound. Every run must also return the
  identical admitted receipt.

  Timeout: 25 runs at the median bound is 50 s plus repo construction, which
  can exceed ExUnit's default 60 s on a heavily loaded host while still
  inside the bound, so the module timeout is raised to 300 s: the assertion
  on the bound, not the ExUnit timer, is the regression gate.
  """

  use ExUnit.Case, async: true

  @moduletag timeout: 300_000

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
