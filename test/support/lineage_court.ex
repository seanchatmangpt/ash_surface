defmodule AshSurface.TestSupport.LineageCourt do
  @moduledoc """
  Lineage-reconciliation court (ticket ASF-26922-01 hardening, v26.9.26).

  PR #7 claims: "origin/main is now an ancestor of feat/dfcm-surface-core;
  plain merge (no -s ours); merged tree byte-identical to the pre-merge
  branch tree; the single tree delta origin/main contributed
  (lib/ash_surface/formatter.ex) stays retired."

  This module turns that prose into an admission function over REAL git
  objects (every check shells out to the `git` binary against a real object
  database — no doubles). `verdict/2` admits only when every term holds and
  otherwise returns a typed refusal naming the first broken term:

    * `:malformed_subject`        — a subject is not a 40-hex object id
    * `:unknown_subject`          — a well-formed id that does not resolve to
                                    a commit in the object database
    * `:base_not_ancestor`        — base is not reachable from head (the
                                    lineage claim itself is false)
    * `:vacuous_lineage`          — base and head are the same commit (the
                                    claim asserts nothing)
    * `:head_tree_mismatch`       — head's tree digest differs from the
                                    pinned tree (stale subject / wrong digest)
    * `:merge_not_found`          — the named reconciliation commit is not a
                                    two-parent merge whose second parent is
                                    base
    * `:merge_not_in_lineage`     — the named reconciliation merge is not an
                                    ancestor of head (a lawful merge elsewhere
                                    in the object database cannot vouch for a
                                    head whose real reconciliation differs)
    * `:merge_tree_not_conserved` — the merge tree differs from its first
                                    parent's tree (the merge silently took
                                    content from base: not the claimed
                                    byte-identical reconciliation)
    * `:retired_not_in_base`      — a retired path was never in base (a
                                    vacuous retirement retires nothing)
    * `:retired_path_resurrected` — a retired path reappears in head's tree
    * `:base_path_dropped`        — a path present in base is absent from
                                    head without being on the retired list
                                    (conservation: an `-s ours`-class merge
                                    that silently deletes base capability)

  Replace refs (`refs/replace/*`) and grafts are ignored
  (`GIT_NO_REPLACE_OBJECTS=1`): the court judges the real objects, so a
  replacement cannot turn a refusal into an admission.

  Exclusion (declared scope): conservation is over path NAMES. A base path
  whose content is rewritten or emptied in head is not a conservation
  breach here; content drift is covered by the pinned head tree digest.

  The receipt returned on admission carries the exact subject identities
  (base, head, head tree, merge) so it can be replayed.
  """

  @hex40 ~r/\A[0-9a-f]{40}\z/

  @type refusal ::
          :malformed_subject
          | :unknown_subject
          | :base_not_ancestor
          | :vacuous_lineage
          | :merge_not_in_lineage
          | :retired_not_in_base
          | :head_tree_mismatch
          | :merge_not_found
          | :merge_tree_not_conserved
          | :retired_path_resurrected
          | :base_path_dropped

  @type claim :: %{
          required(:base) => String.t(),
          required(:head) => String.t(),
          optional(:head_tree) => String.t() | nil,
          optional(:merge) => String.t() | nil,
          optional(:retired) => [String.t()]
        }

  @doc """
  Judge a lineage claim against the git object database at `git_dir`.

  Returns `{:admitted, receipt}` or `{:refused, refusal, detail}`.
  """
  @spec verdict(Path.t(), claim()) ::
          {:admitted, map()} | {:refused, refusal(), term()}
  def verdict(git_dir, claim) do
    retired = Map.get(claim, :retired, [])

    with :ok <- well_formed(claim),
         :ok <- resolves(git_dir, claim),
         :ok <- ancestor(git_dir, claim.base, claim.head),
         :ok <- non_vacuous(claim.base, claim.head),
         {:ok, head_tree} <- tree(git_dir, claim.head),
         :ok <- pinned_tree(head_tree, Map.get(claim, :head_tree)),
         :ok <- merge_in_lineage(git_dir, Map.get(claim, :merge), claim.head),
         :ok <- merge_conserved(git_dir, Map.get(claim, :merge), claim.base),
         {:ok, head_paths} <- paths(git_dir, claim.head),
         {:ok, base_paths} <- paths(git_dir, claim.base),
         :ok <- retired_in_base(base_paths, retired),
         :ok <- retired_absent(head_paths, retired),
         :ok <- base_conserved(base_paths, head_paths, retired) do
      {:admitted,
       %{
         base: claim.base,
         head: claim.head,
         head_tree: head_tree,
         merge: Map.get(claim, :merge),
         retired: Enum.sort(retired),
         base_paths: MapSet.size(base_paths),
         head_paths: MapSet.size(head_paths)
       }}
    end
  end

  defp well_formed(claim) do
    ids =
      [claim.base, claim.head, Map.get(claim, :head_tree), Map.get(claim, :merge)]
      |> Enum.reject(&is_nil/1)

    case Enum.reject(ids, &(is_binary(&1) and Regex.match?(@hex40, &1))) do
      [] -> :ok
      bad -> {:refused, :malformed_subject, bad}
    end
  end

  defp resolves(git_dir, claim) do
    commits = [claim.base, claim.head] ++ List.wrap(Map.get(claim, :merge))

    case Enum.reject(commits, &commit?(git_dir, &1)) do
      [] -> :ok
      missing -> {:refused, :unknown_subject, missing}
    end
  end

  defp commit?(git_dir, sha) do
    match?({"commit\n", 0}, git(git_dir, ["cat-file", "-t", sha]))
  end

  defp ancestor(git_dir, base, head) do
    case git(git_dir, ["merge-base", "--is-ancestor", base, head]) do
      {_, 0} -> :ok
      {_, _} -> {:refused, :base_not_ancestor, {base, head}}
    end
  end

  defp non_vacuous(same, same), do: {:refused, :vacuous_lineage, same}
  defp non_vacuous(_base, _head), do: :ok

  defp merge_in_lineage(_git_dir, nil, _head), do: :ok

  defp merge_in_lineage(git_dir, merge, head) do
    case git(git_dir, ["merge-base", "--is-ancestor", merge, head]) do
      {_, 0} -> :ok
      {_, _} -> {:refused, :merge_not_in_lineage, {merge, head}}
    end
  end

  defp tree(git_dir, rev) do
    case git(git_dir, ["rev-parse", rev <> "^{tree}"]) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, _} -> {:refused, :unknown_subject, String.trim(out)}
    end
  end

  defp pinned_tree(_actual, nil), do: :ok
  defp pinned_tree(actual, actual), do: :ok
  defp pinned_tree(actual, expected), do: {:refused, :head_tree_mismatch, {expected, actual}}

  defp merge_conserved(_git_dir, nil, _base), do: :ok

  defp merge_conserved(git_dir, merge, base) do
    case git(git_dir, ["rev-list", "--parents", "-n", "1", merge]) do
      {out, 0} ->
        case String.split(String.trim(out), " ") do
          [^merge, first, ^base] ->
            {:ok, merge_tree} = tree(git_dir, merge)
            {:ok, first_tree} = tree(git_dir, first)

            if merge_tree == first_tree,
              do: :ok,
              else: {:refused, :merge_tree_not_conserved, {merge_tree, first_tree}}

          parents ->
            {:refused, :merge_not_found, parents}
        end

      {out, _} ->
        {:refused, :merge_not_found, String.trim(out)}
    end
  end

  defp paths(git_dir, rev) do
    case git(git_dir, ["ls-tree", "-r", "--name-only", "-z", rev]) do
      {out, 0} -> {:ok, out |> String.split(<<0>>, trim: true) |> MapSet.new()}
      {out, _} -> {:refused, :unknown_subject, String.trim(out)}
    end
  end

  defp retired_in_base(base_paths, retired) do
    case Enum.reject(retired, &MapSet.member?(base_paths, &1)) do
      [] -> :ok
      vacuous -> {:refused, :retired_not_in_base, Enum.sort(vacuous)}
    end
  end

  defp retired_absent(head_paths, retired) do
    case Enum.filter(retired, &MapSet.member?(head_paths, &1)) do
      [] -> :ok
      back -> {:refused, :retired_path_resurrected, back}
    end
  end

  defp base_conserved(base_paths, head_paths, retired) do
    dropped =
      base_paths
      |> MapSet.difference(head_paths)
      |> MapSet.difference(MapSet.new(retired))
      |> Enum.sort()

    case dropped do
      [] -> :ok
      _ -> {:refused, :base_path_dropped, dropped}
    end
  end

  @doc "Run `git` against `git_dir` (a `.git` directory) with a scrubbed config surface."
  @spec git(Path.t(), [String.t()]) :: {String.t(), non_neg_integer()}
  def git(git_dir, args) do
    System.cmd("git", ["--git-dir", git_dir | args],
      stderr_to_stdout: true,
      env: [
        {"GIT_CONFIG_NOSYSTEM", "1"},
        {"GIT_TERMINAL_PROMPT", "0"},
        {"GIT_NO_REPLACE_OBJECTS", "1"}
      ]
    )
  end
end
