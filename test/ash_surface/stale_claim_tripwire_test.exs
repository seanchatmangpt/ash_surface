defmodule AshSurface.StaleClaimTripwireTest do
  @moduledoc """
  Tripwire (chicago-moduledoc-sweep-040): lib/ must carry no stale
  transition/existence claims — comments that say a thing "does not exist
  yet", "until X lands", "on no branch", "in this branch", "test-env-only",
  or "not yet admitted" rot the moment the named transition happens.

  The subject under test is the REAL `lib/` tree on disk, read byte-for-byte
  at test time — no doubles. Every scan hit must either be corrected at
  source or proven-current by an `@allowlist` entry carrying its evidence.
  The allowlist shrinks monotonically: an entry whose pattern no longer
  matches its file fails the tripwire (stale allowlist = stale ledger).
  """

  use ExUnit.Case, async: true

  @lib_root Path.join(File.cwd!(), "lib")

  # Stale-claim patterns (mappers 05/14 residuals + sweep-040 variants):
  # each is a regex applied line-wise to every .ex file under lib/.
  @stale_patterns [
    {:does_not_exist_yet, ~r/does not exist yet/i},
    {:exists_yet, ~r/\bexists yet\b/i},
    {:not_yet_admitted, ~r/not yet (admitted|implemented|supported)/i},
    {:until_lands, ~r/until [a-z][a-z ]{0,40}\blands\b/i},
    {:on_no_branch, ~r/on no branch/i},
    {:in_this_branch, ~r/in this branch/i},
    {:test_env_only, ~r/test-env-only/i}
  ]

  # Proven-current mentions: relative path => {pattern, evidence}. An entry
  # exists ONLY while its file still matches the pattern AND the match is
  # proven-current by the recorded evidence.
  @allowlist %{
    "lib/ash_surface/projector/ir.ex" =>
      {:exists_yet,
       "gapfix-docs-truth-013 correction record: quotes the superseded claim verbatim to document its supersession; AshSurface.IR is admitted (lib/ash_surface/ir.ex)"}
  }

  # Canonical stale shapes: proves each pattern is live (a silently-vacuous
  # regex would green-light exactly the rot this tripwire guards).
  @pattern_self_probe [
    {:does_not_exist_yet, "the module does not exist yet"},
    {:exists_yet, "no upstream IR owner exists yet"},
    {:not_yet_admitted, "this shape is not yet admitted"},
    {:until_lands, "this comment is valid until the fix lands"},
    {:on_no_branch, "this code lives on no branch"},
    {:in_this_branch, "the dep is test-only in this branch"},
    {:test_env_only, "ash_x is a test-env-only dependency"}
  ]

  test "every pattern matches its canonical stale shape (tripwire is live)" do
    for {name, sample} <- @pattern_self_probe do
      {_file, regex} = Enum.find(@stale_patterns, &match?({^name, _}, &1))

      assert Regex.match?(regex, sample),
             "pattern #{name} fails to match its canonical stale shape"
    end
  end

  test "lib/ carries no stale claims outside the allowlist" do
    offenders = scan() |> Enum.reject(&allowlisted?/1)

    assert offenders == [],
           "stale-claim comments found in lib/ — correct at source or prove-current " <>
             "(add an @allowlist entry with evidence):\n" <>
             Enum.map_join(offenders, "\n", fn o ->
               "  #{o.file}:#{o.line} [#{o.pattern}] #{String.slice(o.text, 0, 90)}"
             end)
  end

  test "allowlist shrinks monotonically: every entry is still load-bearing" do
    for {file, {pattern, _evidence}} <- @allowlist do
      hits = scan_file(file)

      assert Enum.any?(hits, &(&1.pattern == pattern)),
             "allowlist entry #{file} [#{pattern}] no longer matches — " <>
               "remove it (the allowlist shrinks monotonically, never grows to fit drift)"
    end
  end

  # -- scan machinery ------------------------------------------------------

  defp scan do
    Path.wildcard(Path.join(@lib_root, "**/*.ex"))
    |> Enum.flat_map(fn abs_path ->
      rel = Path.relative_to(abs_path, File.cwd!())
      scan_text(rel, File.read!(abs_path))
    end)
  end

  defp scan_file(rel_path) do
    abs_path = Path.join(File.cwd!(), rel_path)

    if File.exists?(abs_path) do
      scan_text(rel_path, File.read!(abs_path))
    else
      []
    end
  end

  defp scan_text(rel_path, content) do
    content
    |> String.split(["\r\n", "\n"])
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, lineno} ->
      for {name, regex} <- @stale_patterns,
          Regex.match?(regex, line) do
        %{file: rel_path, line: lineno, pattern: name, text: String.trim(line)}
      end
    end)
  end

  defp allowlisted?(%{file: file, pattern: pattern}) do
    case Map.fetch(@allowlist, file) do
      {:ok, {^pattern, _evidence}} -> true
      _ -> false
    end
  end
end
