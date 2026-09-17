defmodule AshSurface.PathTruthTest do
  @moduledoc """
  Path-truth law enforcement anchor (ticket `chicago-pathtruth-anchor-035`).

  TESTING.md states the law but, before this suite, nothing enforced it:

  > Path-truth law for this document: every cited path either exists on this
  > branch, or is marked **[INTEGRATION]** — a sibling-canonical path owned
  > by a v-wave branch that is absent here by design ...

  This suite parses the two law-bearing documents (`TESTING.md`,
  `docs/PROJECTORS.md`) as raw bytes, extracts every backtick-quoted
  citation, and fails on any cited path that does not exist on this branch
  unless its line carries the law's own marker vocabulary. Symmetrically, a
  path that DOES exist but whose line claims the absent-by-design marker is
  a stale marker — also a failure: a marker path "is never an existing
  gate".

  The classifier is fail-closed: every slash-bearing citation must land in
  an explicit class — a checked concrete path (repo-root relative,
  `lib/ash_surface/` shorthand, or `test/js/`-relative `../` import), a
  brace-expanded list of checked paths, an allowlisted external ref, or a
  recognized non-path shape (function arity refs, `node:` imports, bare
  extension mentions, Elixir struct patterns, whitespace commands). The
  allowlist admits only intentional external refs — things that genuinely
  live outside this tree:

    * `exp/vNN` — git branch provenance refs (PROJECTORS.md §6);
    * `{prefix}.…` / `zoela_surface…` — projector-emitted artifact names,
      written to scratch target dirs, not repo files;
    * glob/template shapes (`*`, `<name>`) — cited as shapes, not files;
    * `label/group/order/widget/format` — an IR field list, not a path.

  The corpus assertions keep the anchor non-vacuous: if the docs stop
  citing paths, or the classifier silently degrades to skipping everything,
  the suite fails.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @docs [
    Path.join(@repo_root, "TESTING.md"),
    Path.join(@repo_root, "docs/PROJECTORS.md")
  ]

  @extensions ~w(.ex .exs .md .mjs .sh .ttl .json .toml .js .yaml .yml)

  # Intentional external refs: {id, regex, reason}. A ref matching any entry
  # is exempt from existence checks; the reason is surfaced in failure text.
  @allowlist [
    {:branch_ref, ~r/^exp\/v\d+$/,
     "git branch provenance ref (PROJECTORS.md §6) — lives in git history, not this tree"},
    {:emitted_artifact, ~r/^\{prefix\}/,
     "projector-emitted artifact family — written to a scratch :target_dir, not a repo file"},
    {:emitted_artifact, ~r/^zoela_surface\./,
     "Expo projector emitted artifact name — written to a scratch target dir, not a repo file"},
    {:glob_or_template, ~r/[\*<>]/,
     "glob/template shape — cited as a pattern, not a concrete file"},
    {:retired_ref, ~r|^lib/ash_surface/formatter\.ex$|,
     "retired module (chicago-formatter-retire-033) — TESTING.md cites the deletion with [RETIRED] provenance; the living guard is formatter_registration_canary_test.exs"},
    {:ir_field_list, ~r/^label\/group\/order\/widget\/format$/,
     "IR.Presentation field list, not a filesystem path"}
  ]

  @tag :path_truth
  test "every concretely cited path exists on this branch (or is honestly [INTEGRATION]-marked)" do
    {checked, stale_markers, missing} = audit()

    assert missing == [],
           "path-truth law violated: #{length(missing)} cited path(s) do not exist on this " <>
             "branch and their lines do not carry the [INTEGRATION] marker:\n\n" <>
             Enum.map_join(missing, "\n", fn {doc, line_no, token} ->
               "  #{Path.basename(doc)}:#{line_no} cites missing `#{token}`"
             end) <>
             "\n\nFix the doc, mark the line with the v-wave [INTEGRATION] vocabulary, or " <>
             "admit the ref with a reasoned @allowlist entry in " <>
             "test/ash_surface/path_truth_test.exs"

    assert stale_markers == [],
           "path-truth law violated (stale markers): #{length(stale_markers)} cited path(s) " <>
             "EXIST on this branch but their lines claim the absent-by-design marker — a " <>
             "marker path is never an existing gate:\n\n" <>
             Enum.map_join(stale_markers, "\n", fn {doc, line_no, token} ->
               "  #{Path.basename(doc)}:#{line_no} marks existing `#{token}` as [INTEGRATION]"
             end)

    assert checked >= 100,
           "anchor went vacuous: only #{checked} concrete citations checked across " <>
             "#{Enum.map_join(@docs, ", ", &Path.relative_to(&1, @repo_root))} — the corpus " <>
             "assertions require a real body of paths"
  end

  @tag :path_truth
  test "classifier coverage: every citation shape in the corpus is exercised" do
    tallies = class_tallies()

    # Golden floors: if the docs stop exercising a citation shape, the
    # classifier for that shape can silently rot — this fails first.
    for {kind, floor} <- [
          {:concrete, 100},
          {:brace_expanded, 3},
          {:lib_shorthand, 1},
          {:basename_shorthand, 1},
          {:js_relative, 1},
          {:line_ref, 1},
          {:arity_ref, 10},
          {:branch_ref, 10},
          {:emitted_artifact, 2},
          {:glob_or_template, 3},
          {:struct_pattern, 5}
        ] do
      got = tallies[kind] || 0

      assert got >= floor,
             "corpus stopped exercising citation shape #{inspect(kind)}: #{got} < #{floor} — " <>
               "either the docs lost their citations (path-truth corpus shrinking) or the " <>
               "classifier no longer recognizes the shape" <>
               (kind
                |> allowlist_reason()
                |> (case do
                      nil -> ""
                      reason -> " (#{kind} exempts: #{reason})"
                    end))
    end
  end

  @tag :path_truth
  test "the law-bearing docs exist and state the path-truth law" do
    for doc <- @docs do
      assert File.exists?(doc), "law-bearing doc missing: #{doc}"
    end

    testing_md = File.read!(Path.join(@repo_root, "TESTING.md"))

    assert testing_md =~ "Path-truth law",
           "TESTING.md no longer states the path-truth law — the anchor enforces a law that " <>
             "must remain written"
  end

  # ── audit pipeline ──────────────────────────────────────────────────────

  # Returns {checked_count, stale_marker_citations, missing_citations}.
  defp audit do
    @docs
    |> Enum.flat_map(&doc_lines/1)
    |> Enum.flat_map(fn {doc, line_no, line} ->
      Enum.map(citations(line), fn token -> {doc, line_no, line, token} end)
    end)
    |> Enum.reduce({0, [], []}, fn
      {doc, line_no, line, token}, {checked, stale, missing} ->
        case expand(token) do
          {:check, resolutions} ->
            missing_paths = Enum.reject(resolutions, fn {abs, _via, _v} -> File.exists?(abs) end)

            cond do
              missing_paths == [] and String.contains?(line, "[INTEGRATION]") ->
                {checked + 1, stale ++ Enum.map(resolutions, &{doc, line_no, elem(&1, 2)}),
                 missing}

              missing_paths == [] ->
                {checked + 1, stale, missing}

              String.contains?(line, "[INTEGRATION]") ->
                # Absent by design: the law's own escape hatch. Not a gate here.
                {checked, stale, missing}

              true ->
                {checked, stale, missing ++ Enum.map(missing_paths, &{doc, line_no, elem(&1, 2)})}
            end

          {:skip, _kind} ->
            {checked, stale, missing}
        end
    end)
  end

  defp class_tallies do
    all_tokens =
      @docs
      |> Enum.flat_map(&doc_lines/1)
      |> Enum.flat_map(fn {_doc, _no, line} -> citations(line) end)

    tallies =
      Enum.reduce(all_tokens, %{}, fn token, acc ->
        acc =
          case classify_shape(token) do
            {:check, resolutions} when length(resolutions) > 1 ->
              Map.update(acc, :brace_expanded, 1, &(&1 + 1))

            {:check, [{_abs, via, _v} | _]} ->
              Map.update(acc, via, 1, &(&1 + 1))

            {:skip, kind} ->
              Map.update(acc, kind, 1, &(&1 + 1))
          end

        if raw_token_is_line_ref?(token) do
          Map.update(acc, :line_ref, 1, &(&1 + 1))
        else
          acc
        end
      end)

    concrete =
      Enum.count(all_tokens, fn token ->
        match?({:check, _}, expand(token))
      end)

    Map.put(tallies, :concrete, concrete)
  end

  defp allowlist_reason(kind) do
    case Enum.find(@allowlist, fn {k, _re, _reason} -> k == kind end) do
      {_k, _re, reason} -> reason
      nil -> nil
    end
  end

  defp doc_lines(doc) do
    doc
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map(fn {line, no} -> {doc, no, line} end)
  end

  defp citations(line), do: Regex.scan(~r/`([^`\n]+)`/, line) |> Enum.map(&List.last/1)

  # ── classification ──────────────────────────────────────────────────────

  # {:check, [{abs_path, via, cited}]} | {:skip, kind}
  defp expand(raw_token) do
    token = strip_line_ref(raw_token)
    allowlisted = Enum.find(@allowlist, fn {_kind, re, _reason} -> Regex.match?(re, token) end)

    cond do
      token == "" or token =~ ~r/\s/ ->
        {:skip, :whitespace_command}

      String.starts_with?(token, "node:") ->
        {:skip, :node_import}

      Regex.match?(~r/^[A-Za-z0-9._?!]+\/\d+$/, token) ->
        {:skip, :arity_ref}

      Regex.match?(~r/^\.[a-z]+$/, token) ->
        {:skip, :extension_mention}

      Regex.match?(~r/^%[A-Za-z0-9._]+\{[^{}]*\}$/, token) ->
        # Elixir struct pattern (e.g. `%AshSurface.IR{}`) — code prose, not a path.
        {:skip, :struct_pattern}

      allowlisted != nil ->
        {:skip, elem(allowlisted, 0)}

      String.contains?(token, "{") ->
        {:check, token |> brace_expand() |> Enum.map(&resolve/1)}

      path_like?(token) ->
        {:check, [resolve(token)]}

      true ->
        # No slash and no extension: not path-shaped prose (e.g. `ExUnit.start()`).
        {:skip, :not_path_shaped}
    end
  end

  defp classify_shape(token) do
    expand(token)
  end

  defp raw_token_is_line_ref?(token), do: Regex.match?(~r/:\d+(?:[–—-]\d+)?$/u, token)

  # `lib/.../file.ex:161` and `...live_view.ex:28–31` are file cites with a
  # line/range suffix; the file is the subject, the line number is prose.
  defp strip_line_ref(token), do: Regex.replace(~r/:\d+(?:[–—-]\d+)?$/u, token, "")

  # Single-level brace expansion: `lib/ash_surface/intent/{candidate,dispatch}.ex`
  # cites both concrete files. (Tokens *starting* with `{` are emitted-artifact
  # families and are allowlisted before this point.) An irregular brace token
  # falls through unchanged and fails the existence check loudly — never a
  # silent skip.
  defp brace_expand(token) do
    case Regex.run(~r/^([^{}]+)\{([^{}]+)\}([^{}]*)$/, token) do
      [_, pre, group, post] ->
        group
        |> String.split(",")
        |> Enum.map(&(pre <> String.trim(&1) <> post))

      _ ->
        [token]
    end
  end

  defp path_like?(token) do
    String.contains?(token, "/") or extension?(token)
  end

  defp extension?(token) do
    not String.starts_with?(token, ".") and Path.extname(token) in @extensions
  end

  # Resolution order (each shape documented in the docs themselves):
  #   1. repo-root-relative            (`test/support/fixtures.ex`)
  #   2. `lib/ash_surface/`-shorthand  (PROJECTORS.md §6 correction list)
  #   3. unique basename under lib/ash_surface/** (`live_view.ex`)
  #   4. `../`-relative from test/js/  (the JS suites' runtime import path)
  # A bare basename matching MORE than one file is ambiguous by definition —
  # it resolves to nothing and fails the existence check, forcing the doc to
  # write the full path.
  defp resolve(token) do
    {abs, via} =
      cond do
        String.starts_with?(token, "../") ->
          {Path.expand(Path.join([@repo_root, "test/js", token])), :js_relative}

        File.exists?(Path.join(@repo_root, token)) ->
          {Path.join(@repo_root, token), :repo_root}

        File.exists?(Path.expand(Path.join([@repo_root, "lib/ash_surface", token]))) ->
          {Path.expand(Path.join([@repo_root, "lib/ash_surface", token])), :lib_shorthand}

        true ->
          case Path.wildcard("lib/ash_surface/**/" <> token) do
            [only] -> {Path.expand(Path.join(@repo_root, only)), :basename_shorthand}
            _ambiguous_or_missing -> {token, :unresolved}
          end
      end

    {abs, via, token}
  end
end
