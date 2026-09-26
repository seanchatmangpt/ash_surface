defmodule AshSurface.LineageCourtTest do
  @moduledoc """
  Falsifier corpus for the PR #7 lineage-reconciliation claim (ASF-26922-01),
  hardened in v26.9.26.

  CHICAGO: every scenario builds a REAL git repository in a temp dir with the
  real `git` binary (fixed author/committer dates, so object ids are
  reproducible) and asks `AshSurface.TestSupport.LineageCourt.verdict/2` to
  judge it. Assertions are on the returned verdict/receipt, never on calls.

  Adversarial axes covered: malformed subject, unknown subject, a non-commit
  object posing as a commit, base-not-ancestor (the claim is false),
  reordered subjects (base/head swapped), stale subject (pinned tree from an
  older head), wrong digest, merge that silently takes base content, a
  non-merge / wrong-second-parent merge, retired path resurrection, an
  `-s ours` merge that drops base capability, and duplicate delivery (the
  same claim judged twice must yield the byte-identical receipt).

  The LIVE test re-judges the real PR #7 subjects (base main 7d54927, head
  6b87f05c, reconciliation merge 1fc2506) when real history is reachable:
  `ASH_SURFACE_LINEAGE_GIT_DIR` or a non-shallow `.git` at the repo root that
  contains the head. Otherwise it is a named skip (a shallow CI checkout
  cannot see ancestry), never a silent pass.
  """

  use ExUnit.Case, async: true

  alias AshSurface.TestSupport.LineageCourt

  @repo_root Path.expand("../..", __DIR__)

  # Real PR #7 subjects (seanchatmangpt/ash_surface).
  @pr7_base "7d5492795d9b9a0956f51545ed1ad1932768b77e"
  @pr7_head "6b87f05c3cc75858ce671b2a698e70097d521b1e"
  @pr7_head_tree "4c3b9b3369cd724d01c8a26a8a9604820f86814b"
  @pr7_merge "1fc2506c116b0b4efb897fc9d149a1739124718d"
  @pr7_retired ["lib/ash_surface/formatter.ex"]
  @pr7_claim %{
    base: @pr7_base,
    head: @pr7_head,
    head_tree: @pr7_head_tree,
    merge: @pr7_merge,
    retired: @pr7_retired
  }

  @live_git_dir (fn ->
                   candidates =
                     [
                       System.get_env("ASH_SURFACE_LINEAGE_GIT_DIR"),
                       Path.join(@repo_root, ".git")
                     ]
                     |> Enum.reject(&is_nil/1)

                   Enum.find(candidates, fn dir ->
                     File.exists?(dir) and
                       match?(
                         {"commit\n", 0},
                         System.cmd("git", ["--git-dir", dir, "cat-file", "-t", @pr7_head],
                           stderr_to_stdout: true
                         )
                       ) and
                       match?(
                         {"false\n", 0},
                         System.cmd(
                           "git",
                           ["--git-dir", dir, "rev-parse", "--is-shallow-repository"],
                           stderr_to_stdout: true
                         )
                       )
                   end)
                 end).()

  # ---------------------------------------------------------------------------
  # Real-repo builder
  # ---------------------------------------------------------------------------

  defp new_repo!(ctx) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "ash_surface_lineage_#{ctx}_#{System.unique_integer([:positive])}"
      )

    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    run!(dir, ["init", "-q", "-b", "main"])
    dir
  end

  @env [
    {"GIT_CONFIG_NOSYSTEM", "1"},
    {"GIT_AUTHOR_NAME", "court"},
    {"GIT_AUTHOR_EMAIL", "court@example.invalid"},
    {"GIT_COMMITTER_NAME", "court"},
    {"GIT_COMMITTER_EMAIL", "court@example.invalid"},
    {"GIT_AUTHOR_DATE", "2026-09-26T00:00:00Z"},
    {"GIT_COMMITTER_DATE", "2026-09-26T00:00:00Z"}
  ]

  defp run!(dir, args) do
    {out, status} =
      System.cmd("git", ["-C", dir, "-c", "commit.gpgsign=false" | args],
        stderr_to_stdout: true,
        env: @env
      )

    assert status == 0, "git #{Enum.join(args, " ")} failed (#{status}): #{out}"
    String.trim(out)
  end

  defp write!(dir, rel, content) do
    path = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp commit!(dir, msg) do
    run!(dir, ["add", "-A"])
    run!(dir, ["commit", "-q", "--allow-empty", "-m", msg])
    run!(dir, ["rev-parse", "HEAD"])
  end

  defp tree!(dir, rev), do: run!(dir, ["rev-parse", rev <> "^{tree}"])

  defp git_dir(dir), do: Path.join(dir, ".git")

  # The PR #7 shape in miniature: `main` is a squash snapshot carrying a
  # to-be-retired plugin; the feature branch evolved past it and retired the
  # plugin; the reconciliation is a plain merge of main into the branch
  # resolved to the branch side (tree == first parent tree).
  defp lawful_shape!(ctx) do
    dir = new_repo!(ctx)
    write!(dir, "lib/core.ex", "core v1\n")
    write!(dir, "lib/formatter.ex", "retired plugin\n")
    root = commit!(dir, "root")

    run!(dir, ["checkout", "-q", "-b", "feat"])
    write!(dir, "lib/core.ex", "core v2 evolved\n")
    write!(dir, "lib/extra.ex", "extra\n")
    File.rm!(Path.join(dir, "lib/formatter.ex"))
    commit!(dir, "evolve + retire formatter")

    run!(dir, ["checkout", "-q", "main"])
    write!(dir, "README.md", "squash snapshot\n")
    base = commit!(dir, "squash-publish")

    run!(dir, ["checkout", "-q", "feat"])
    # The branch already carries every base-only addition (conservation), so
    # a plain merge resolves to exactly the branch-side tree.
    write!(dir, "README.md", "squash snapshot\n")
    feat_tip2 = commit!(dir, "carry README")
    run!(dir, ["merge", "--no-ff", "-q", "-m", "merge: reconcile main (plain)", "main"])
    merge = run!(dir, ["rev-parse", "HEAD"])

    %{
      dir: dir,
      root: root,
      base: base,
      pre_merge: feat_tip2,
      merge: merge,
      head: merge,
      retired: ["lib/formatter.ex"]
    }
  end

  defp claim(s, overrides \\ %{}) do
    Map.merge(
      %{
        base: s.base,
        head: s.head,
        head_tree: tree!(s.dir, s.head),
        merge: s.merge,
        retired: s.retired
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # GREEN: the lawful reconciliation is admitted, with replayable receipt
  # ---------------------------------------------------------------------------

  test "ADMIT: plain merge resolved to branch side, retired path absent, base conserved" do
    s = lawful_shape!("admit")

    assert {:admitted, receipt} = LineageCourt.verdict(git_dir(s.dir), claim(s))
    assert receipt.base == s.base
    assert receipt.head == s.head
    assert receipt.merge == s.merge
    assert receipt.head_tree == tree!(s.dir, s.pre_merge)
    assert receipt.retired == ["lib/formatter.ex"]
    assert receipt.head_paths == 3
  end

  test "DUPLICATE DELIVERY: judging the same claim twice yields the byte-identical receipt" do
    s = lawful_shape!("dup")
    c = claim(s)

    first = LineageCourt.verdict(git_dir(s.dir), c)
    second = LineageCourt.verdict(git_dir(s.dir), c)

    assert {:admitted, _} = first
    assert :erlang.term_to_binary(first) == :erlang.term_to_binary(second)
  end

  test "ADMIT without optional pins: head_tree and merge omitted still judges lineage" do
    s = lawful_shape!("nopins")

    assert {:admitted, %{merge: nil}} =
             LineageCourt.verdict(git_dir(s.dir), %{
               base: s.base,
               head: s.head,
               retired: s.retired
             })
  end

  # ---------------------------------------------------------------------------
  # RED: malformed / unknown subjects
  # ---------------------------------------------------------------------------

  test "REFUSE malformed_subject: short, uppercase, non-hex, and non-string ids" do
    s = lawful_shape!("malformed")

    for bad <- [
          String.slice(s.head, 0, 7),
          String.upcase(s.head),
          "zz" <> String.slice(s.head, 2, 38),
          s.head <> "0",
          "HEAD",
          :head
        ] do
      assert {:refused, :malformed_subject, [^bad]} =
               LineageCourt.verdict(git_dir(s.dir), claim(s, %{head: bad})),
             "malformed head #{inspect(bad)} was not refused"
    end

    assert {:refused, :malformed_subject, ["abc"]} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{head_tree: "abc"}))
  end

  test "REFUSE unknown_subject: well-formed id absent from the object database" do
    s = lawful_shape!("unknown")
    ghost = String.duplicate("0", 40)

    assert {:refused, :unknown_subject, [^ghost]} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{base: ghost}))
  end

  test "REFUSE unknown_subject: a tree id posing as a commit" do
    s = lawful_shape!("treeposing")
    tree = tree!(s.dir, s.head)

    assert {:refused, :unknown_subject, [^tree]} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{head: tree}))
  end

  # ---------------------------------------------------------------------------
  # RED: lineage false / reordered
  # ---------------------------------------------------------------------------

  test "REFUSE base_not_ancestor: the pre-merge branch tip does not contain base" do
    s = lawful_shape!("notanc")

    assert {:refused, :base_not_ancestor, {base, head}} =
             LineageCourt.verdict(
               git_dir(s.dir),
               claim(s, %{head: s.pre_merge, head_tree: nil, merge: nil})
             )

    assert {base, head} == {s.base, s.pre_merge}
  end

  test "REFUSE base_not_ancestor: reordered subjects (base and head swapped)" do
    s = lawful_shape!("reorder")

    assert {:refused, :base_not_ancestor, _} =
             LineageCourt.verdict(
               git_dir(s.dir),
               claim(s, %{base: s.head, head: s.base, head_tree: nil, merge: nil})
             )
  end

  # ---------------------------------------------------------------------------
  # RED: stale subject / wrong digest
  # ---------------------------------------------------------------------------

  test "REFUSE head_tree_mismatch: tree pinned at the old head after the branch moved (stale subject)" do
    s = lawful_shape!("stale")
    pinned = tree!(s.dir, s.head)
    write!(s.dir, "lib/core.ex", "core v3 moved on\n")
    moved = commit!(s.dir, "branch moves after the claim was pinned")

    assert {:refused, :head_tree_mismatch, {^pinned, actual}} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{head: moved, head_tree: pinned}))

    assert actual == tree!(s.dir, moved)
  end

  test "REFUSE head_tree_mismatch: wrong digest" do
    s = lawful_shape!("wrongdigest")
    wrong = String.duplicate("a", 40)

    assert {:refused, :head_tree_mismatch, {^wrong, _}} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{head_tree: wrong}))
  end

  # ---------------------------------------------------------------------------
  # RED: merge shape / conservation
  # ---------------------------------------------------------------------------

  test "REFUSE merge_tree_not_conserved: the merge silently took base content" do
    dir = new_repo!("takebase")
    write!(dir, "lib/core.ex", "v1\n")
    commit!(dir, "root")
    run!(dir, ["checkout", "-q", "-b", "feat"])
    write!(dir, "lib/core.ex", "feat side\n")
    commit!(dir, "feat")
    run!(dir, ["checkout", "-q", "main"])
    write!(dir, "lib/new_on_main.ex", "main-only\n")
    base = commit!(dir, "main moves")
    run!(dir, ["checkout", "-q", "feat"])
    run!(dir, ["merge", "--no-ff", "-q", "-m", "merge main (takes base content)", "main"])
    merge = run!(dir, ["rev-parse", "HEAD"])

    assert {:refused, :merge_tree_not_conserved, {merge_tree, first_tree}} =
             LineageCourt.verdict(git_dir(dir), %{base: base, head: merge, merge: merge})

    refute merge_tree == first_tree
  end

  test "REFUSE merge_not_found: a non-merge commit named as the reconciliation" do
    s = lawful_shape!("nonmerge")

    assert {:refused, :merge_not_found, [_single, _parent]} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{merge: s.pre_merge}))
  end

  test "REFUSE merge_not_found: merge whose second parent is not the claimed base" do
    s = lawful_shape!("wrongparent")

    assert {:refused, :merge_not_found, parents} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{base: s.root}))

    assert length(parents) == 3
    assert List.last(parents) == s.base
  end

  test "REFUSE retired_path_resurrected: the retired plugin comes back after the merge" do
    s = lawful_shape!("resurrect")
    write!(s.dir, "lib/formatter.ex", "retired plugin\n")
    back = commit!(s.dir, "resurrect retired plugin")

    assert {:refused, :retired_path_resurrected, ["lib/formatter.ex"]} =
             LineageCourt.verdict(git_dir(s.dir), claim(s, %{head: back, head_tree: nil}))
  end

  test "REFUSE base_path_dropped: an -s ours merge conserves the first-parent tree but drops base capability" do
    dir = new_repo!("ours")
    write!(dir, "lib/core.ex", "v1\n")
    commit!(dir, "root")
    run!(dir, ["checkout", "-q", "-b", "feat"])
    write!(dir, "lib/core.ex", "feat side\n")
    commit!(dir, "feat")
    run!(dir, ["checkout", "-q", "main"])
    write!(dir, "lib/capability.ex", "capability only main has\n")
    base = commit!(dir, "main adds capability")
    run!(dir, ["checkout", "-q", "feat"])
    run!(dir, ["merge", "-s", "ours", "--no-ff", "-q", "-m", "ours-merge", "main"])
    merge = run!(dir, ["rev-parse", "HEAD"])

    # The merge-tree check alone is fooled (tree == first parent), which is
    # exactly why conservation is a separate term.
    assert {:refused, :base_path_dropped, ["lib/capability.ex"]} =
             LineageCourt.verdict(git_dir(dir), %{base: base, head: merge, merge: merge})

    # Declaring it retired is the only lawful way to admit the drop.
    assert {:admitted, _} =
             LineageCourt.verdict(git_dir(dir), %{
               base: base,
               head: merge,
               merge: merge,
               retired: ["lib/capability.ex"]
             })
  end

  test "REFUSE unknown_subject: a git dir that is not a repository" do
    empty =
      Path.join(
        System.tmp_dir!(),
        "ash_surface_lineage_nogit_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(empty)
    on_exit(fn -> File.rm_rf!(empty) end)
    sha = String.duplicate("1", 40)

    assert {:refused, :unknown_subject, [^sha, ^sha]} =
             LineageCourt.verdict(empty, %{base: sha, head: sha})
  end

  # ---------------------------------------------------------------------------
  # LIVE: the real PR #7 subjects
  # ---------------------------------------------------------------------------

  if @live_git_dir do
    test "LIVE PR #7: main is an ancestor, merge 1fc2506 conserves the branch tree, formatter.ex stays retired" do
      assert {:admitted, receipt} = LineageCourt.verdict(@live_git_dir, @pr7_claim)

      assert receipt.head_tree == @pr7_head_tree
    end

    test "LIVE PR #7 anti-vacuity: without the retirement the drop of formatter.ex is refused" do
      assert {:refused, :base_path_dropped, ["lib/ash_surface/formatter.ex"]} =
               LineageCourt.verdict(
                 @live_git_dir,
                 Map.drop(@pr7_claim, [:retired, :head_tree])
               )
    end
  else
    @tag skip:
           "real PR #7 history unreachable (shallow/absent .git); set ASH_SURFACE_LINEAGE_GIT_DIR to a full clone's .git"
    test "LIVE PR #7: lineage claim re-judged on real history" do
      flunk("unreachable: #{inspect(@pr7_claim)}")
    end
  end
end
