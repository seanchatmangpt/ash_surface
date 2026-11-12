defmodule AshSurface.Parity.CourtMap do
  @moduledoc """
  The checked-in court map (`parity/court_map.json`): hand-authored, mechanically
  validated.

      {"entries": {"<id-or-prefix*>": <entry>, ...}}

  Entry forms:

    * `{"status":"pass","tests":[{"file":F,"test":NAME} | {"file":F,"contains":TOKEN}]}`
      (all references must hold; `"any_of"` instead of `"tests"` passes when at least
      one reference holds, and a stale pointer in any of them is still broken)
      - `test`: F must exist and contain a `test`/`describe`/`property` line whose
        title contains NAME; `contains`: F must exist and contain TOKEN. In both,
        the placeholder `{leaf}` is replaced by the inventory id's last
        dot-segment, so a wildcard rule only passes for ids the file really names.
    * `{"status":"divergence","kd":"KD-nn"}` - row must exist in the KD register AND be
      a witnessed better-implementation (`Register.witnessed?/2`); otherwise the
      capability is MISSING (operator divergence law, 2026-11-11).
    * `{"status":"unmapped","reason":"..."}` - a documented implementation debt: the
      capability is MISSING (it exists so a wildcard rule cannot over-claim a
      capability whose real court is absent, and the debt carries its reason).
    * `{"status":"non_goal","reason":"...","readme":"<verbatim README.md text>"}` -
      lawful only for README-declared non-goals: the quoted text must occur in
      README.md; otherwise the capability is MISSING.

  Keys ending in `*` are prefix rules; resolution is exact key first, else the
  longest matching prefix rule.
  """

  alias AshSurface.Parity.{ExcludeSpec, Register, TestIndex}

  def load!(path), do: path |> File.read!() |> Jason.decode!() |> Map.fetch!("entries")

  @doc "Resolve the entry for `id` (or nil)."
  def resolve(entries, id) do
    case Map.fetch(entries, id) do
      {:ok, e} ->
        {id, e}

      :error ->
        entries
        |> Enum.filter(fn {k, _} ->
          String.ends_with?(k, "*") and String.starts_with?(id, String.trim_trailing(k, "*"))
        end)
        |> Enum.max_by(fn {k, _} -> String.length(k) end, fn -> nil end)
    end
  end

  @doc """
  Validate `entry` for `id` against the disk. Returns `{status, problems}` where
  status is `:pass | :divergence | :non_goal` and problems is a list of strings.
  """
  def validate(id, entry, root, kd) do
    leaf = id |> String.split(".") |> List.last()

    case entry do
      %{"status" => "pass", "tests" => [_ | _] = tests} ->
        problems = Enum.flat_map(tests, &check_test(&1, leaf, root))

        case Enum.split_with(problems, &match?({:hard, _}, &1)) do
          {[], []} -> {:pass, []}
          {[], soft} -> {:unwitnessed, Enum.map(soft, &elem(&1, 1))}
          {hard, _} -> {:pass, Enum.map(hard, &elem(&1, 1))}
        end

      %{"status" => "pass", "any_of" => [_]} ->
        {:pass, ["any_of needs >= 2 alternatives (one reference is `tests`)"]}

      %{"status" => "pass", "any_of" => [_ | _] = tests} ->
        problems = Enum.map(tests, &check_test(&1, leaf, root))
        flat = List.flatten(problems)

        cond do
          Enum.any?(flat, &match?({:hard, _}, &1)) ->
            {:pass, for({:hard, m} <- flat, do: m)}

          Enum.any?(problems, &(&1 == [])) ->
            {:pass, []}

          true ->
            {:unwitnessed, Enum.map(flat, &elem(&1, 1))}
        end

      %{"status" => "pass"} ->
        {:pass, ["pass entry names no tests"]}

      %{"status" => "divergence", "kd" => kd_id} when is_binary(kd_id) ->
        case Map.fetch(kd, kd_id) do
          :error ->
            {:divergence, ["#{kd_id} is not a row in KNOWN_DIVERGENCES.md"]}

          {:ok, row} ->
            case Register.witnessed?(row, root) do
              :ok ->
                {:divergence, []}

              {:unwitnessed, why} ->
                {:unwitnessed, ["#{kd_id} unwitnessed divergence: " <> Enum.join(why, "; ")]}
            end
        end

      %{"status" => "unmapped", "reason" => r} when is_binary(r) and r != "" ->
        {:unwitnessed, ["unmapped debt: " <> r]}

      %{"status" => "non_goal", "reason" => r} = e when is_binary(r) ->
        cond do
          String.trim(r) == "" ->
            {:non_goal, ["non_goal reason is empty"]}

          readme_declares?(e["readme"], root) ->
            {:non_goal, []}

          true ->
            {:unwitnessed,
             ["non_goal is not README-declared (no verbatim `readme` quote found in README.md)"]}
        end

      _ ->
        {:invalid, ["entry shape not in {pass|divergence|non_goal}"]}
    end
  end

  defp readme_declares?(quote_text, root)
       when is_binary(quote_text) and byte_size(quote_text) > 8 do
    case File.read(Path.join(root, "README.md")) do
      {:ok, text} -> String.contains?(text, quote_text)
      _ -> false
    end
  end

  defp readme_declares?(_, _), do: false

  @doc """
  Literal `{file, title}` references of a pass entry (templated `{leaf}` references are
  per-id by construction and excluded). Used by the gate's rows-per-test cap.
  """
  def literal_refs(%{"status" => "pass"} = e) do
    for t <- Map.get(e, "tests", []) ++ Map.get(e, "any_of", []),
        is_map(t),
        key <- ["test", "contains"],
        is_binary(t[key]),
        not String.contains?(t[key], "{leaf}"),
        do: {t["file"], t[key]}
  end

  def literal_refs(_), do: []

  @min_token 4
  @max_files 25

  @doc "Minimum token length and maximum matching test files (vacuity fences)."
  def fences, do: %{min_token: @min_token, max_files: @max_files}

  defp check_test(%{"file" => file} = t, leaf, root) when is_binary(file) do
    cond do
      Path.type(file) == :absolute or ".." in Path.split(file) ->
        [{:hard, "#{file}: test path must be repo-relative"}]

      not test_file?(file) ->
        [{:hard, "#{file}: not a court file (must be test/**/*_test.exs or test/**/*.test.mjs)"}]

      not File.regular?(Path.join(root, file)) ->
        [{:hard, "#{file}: test file does not exist"}]

      true ->
        with {:ok, body} <- read(root, file),
             {:ok, idx} <- TestIndex.analyze(file, body),
             [] <- js_reachability(root, file) do
          check_body(t, file, body, idx, leaf, root)
        else
          {:error, why} -> [{:hard, "#{file}: #{why}"}]
          [_ | _] = problems -> problems
        end
    end
  end

  defp check_test(_, _, _), do: [{:hard, "test reference lacks a file"}]

  defp read(root, file) do
    case File.read(Path.join(root, file)) do
      {:ok, b} -> {:ok, b}
      {:error, r} -> {:error, "unreadable (#{:file.format_error(r)})"}
    end
  end

  defp test_file?(file) do
    String.starts_with?(file, "test/") and
      (String.ends_with?(file, "_test.exs") or String.ends_with?(file, [".test.mjs", ".test.js"]))
  end

  # .mjs courts run only under `npm test`, never `mix test`: the file must be reachable from
  # a package.json test script or be named by a mix-run court
  defp js_reachability(root, file) do
    if Path.extname(file) in [".mjs", ".js"] do
      base = Path.basename(file)
      dir = Path.dirname(file)

      npm =
        case File.read(Path.join(root, "package.json")) do
          {:ok, t} ->
            case Jason.decode(t) do
              {:ok, %{"scripts" => sc}} when is_map(sc) ->
                sc
                |> Map.values()
                |> Enum.filter(&is_binary/1)
                |> Enum.any?(&reaches?(&1, file, dir, base))

              _ ->
                false
            end

          _ ->
            false
        end

      mix =
        root
        |> corpus()
        |> Enum.any?(fn {p, b} ->
          String.ends_with?(p, "_test.exs") and String.contains?(b, base)
        end)

      if npm or mix,
        do: [],
        else: [
          {:hard, "#{file}: JS court unreachable (no package.json script or mix court runs it)"}
        ]
    else
      []
    end
  end

  defp reaches?(script, file, dir, base) do
    String.contains?(script, file) or String.contains?(script, base) or
      (String.contains?(script, dir) and String.contains?(script, "*"))
  end

  defp skip_msg(file, what),
    do: {:hard, "#{file}: SKIPPED #{what} (skip tag); skipped court is not a pass"}

  defp check_body(%{"test" => name}, file, body, idx, leaf, root) when is_binary(name) do
    needle = String.replace(name, "{leaf}", leaf)

    with [] <- generic(needle, root) do
      hits =
        Enum.filter(idx.tests, fn t ->
          String.contains?(t.title, needle) or
            (t.describe != nil and String.contains?(t.describe, needle))
        end)

      judge(hits, idx, file, needle, kind(name), "no test titled like", {body, root})
    end
  end

  defp check_body(%{"contains" => token}, file, body, idx, leaf, root) when is_binary(token) do
    needle = String.replace(token, "{leaf}", leaf)

    with [] <- generic(needle, root) do
      hits =
        Enum.filter(idx.tests, fn t ->
          String.contains?(t.title, needle) or
            (t.describe != nil and String.contains?(t.describe, needle)) or
            Enum.any?(t.asserts, &String.contains?(&1, needle))
        end)

      judge(
        hits,
        idx,
        file,
        needle,
        kind(token),
        "no test assertion or title contains",
        {body, root}
      )
    end
  end

  defp check_body(_, file, _, _, _, _),
    do: [{:hard, "#{file}: test reference needs `test` or `contains`"}]

  defp judge(hits, idx, file, needle, miss_kind, miss_what, {body, root}) do
    spec = ExcludeSpec.read(root)
    hits_all = hits
    hits = Enum.reject(hits, &excluded_test?(&1, body, spec))
    unresolvable = Enum.map(spec.problems, &{:hard, "#{file}: #{&1}"})

    cond do
      unresolvable != [] ->
        unresolvable

      hits_all != [] and hits == [] and not Enum.all?(hits_all, & &1.skipped) ->
        [
          {:hard,
           "#{file}: EXCLUDED test #{inspect(needle)} carries a tag excluded by test/test_helper.exs or mix.exs; excluded court is not a pass"}
        ]

      hits == [] and idx.dynamic != [] ->
        [
          {miss_kind,
           "#{file}: UNINDEXABLE-DYNAMIC-TEST #{inspect(needle)} not found among static tests, but #{length(idx.dynamic)} test(s) are generated by for-comprehension/macro (line #{hd(idx.dynamic).line}); a court cannot rely on a generated test"}
        ]

      hits == [] and idx.module_skip ->
        [skip_msg(file, "module")]

      hits == [] ->
        [{miss_kind, "#{file}: #{miss_what} #{inspect(needle)}"}]

      Enum.all?(hits, & &1.skipped) ->
        [skip_msg(file, "test #{inspect(needle)}")]

      true ->
        active = Enum.reject(hits, & &1.skipped)

        cond do
          not Enum.any?(active, & &1.has_assert) ->
            [{:hard, "#{file}: VACUOUS test #{inspect(needle)} has no assert/refute"}]

          Enum.all?(active, & &1.guarded) ->
            [
              {:hard,
               "#{file}: GUARDED test #{inspect(needle)} sits behind Code.ensure_loaded?/compiled guard"}
            ]

          true ->
            []
        end
    end
  end

  @doc """
  Names of tags unconditionally excluded by `test/test_helper.exs` / `mix.exs` (a filter on a
  tag with value `true`, not overridden by an `include`). Empty when absent. Use
  `AshSurface.Parity.ExcludeSpec.read/1` for the full spec and unresolvable-exclude problems.
  """
  def excluded_tags(root) do
    spec = ExcludeSpec.read(root)

    for {k, true} <- spec.exclude, {k, true} not in spec.include, uniq: true, do: k
  end

  # exclusion by tag VALUE with ExUnit semantics (include overrides exclude; --only)
  defp excluded_test?(t, _body, spec), do: ExcludeSpec.excluded?(spec, t.tag_values)

  # vacuity fence: a token that is too short, or that names too many test files, proves nothing
  defp generic(needle, root) do
    cond do
      String.length(needle) < @min_token ->
        [{:hard, "GENERIC token #{inspect(needle)} shorter than #{@min_token} chars"}]

      (n = corpus_hits(root, needle)) > @max_files ->
        [{:hard, "GENERIC token #{inspect(needle)} matches #{n} test files (> #{@max_files})"}]

      true ->
        []
    end
  end

  defp corpus_hits(root, needle) do
    root
    |> corpus()
    |> Enum.count(fn {_p, body} -> String.contains?(body, needle) end)
  end

  # test-file corpus, memoised per root+mtime-free in the process dictionary for one evaluate
  defp corpus(root) do
    key = {__MODULE__, :corpus, root}

    case Process.get(key) do
      nil ->
        c =
          for ext <- ["exs", "mjs"],
              p <-
                Path.wildcard(Path.join(root, "test/**/*_test.#{ext}")) ++
                  Path.wildcard(Path.join(root, "test/**/*.test.#{ext}")),
              {:ok, b} <- [File.read(p)],
              uniq: true,
              do: {p, b}

        Process.put(key, c)
        c

      c ->
        c
    end
  end

  @doc "Drop the per-process test-file corpus cache (call at the start of an evaluation)."
  def reset_cache,
    do:
      Process.get()
      |> Enum.each(fn
        {{__MODULE__, :corpus, _} = k, _} -> Process.delete(k)
        _ -> :ok
      end)

  # a miss on a `{leaf}`-templated reference means "no court names this
  # capability" (MISSING); a miss on a literal reference is a stale pointer (broken)
  defp kind(text), do: if(String.contains?(text, "{leaf}"), do: :soft, else: :hard)

  @doc false
  def standing_vocabulary, do: Register.vocabulary()
end
