defmodule AshSurface.HandwrittenLedgerTest do
  @moduledoc """
  帳-law tripwire: the HANDWRITTEN ledger and the ontology's UNSUPPORTED rows
  must stay in exact bijection (ticket gapfix-ledger-011).

  The ledger admits hand-written product-surface debt; the 帳 law requires an
  `UNSUPPORTED(generator, element)` row in the owning ontology per open ledger
  row. Before this tripwire the ledger named a nonexistent owner pack
  (`ash-extension-core`, deleted from the marketplace) and the ontology carried
  ZERO UNSUPPORTED rows — the ledger could not shrink because nothing tied it
  to the ontology. This suite pins the repaired state:

    * every ledger row names the real successor owner
      (`ash-extension-pack (ggen-marketplace)`, marketplace commits 5dc0f283f
      deprecation + 9e9c23875 removal of core-pack) — the dead pack name never
      returns;
    * every ledger row carries a commit-verified ISO date;
    * ontology.ttl carries exactly one `surf:UnsupportedRow` per open ledger
      row, matching on (path, element), with the same owner and date;
    * the pairs are non-vacuous (count > 0).

  A ledger row is admitted ONLY together with its UNSUPPORTED row; a row is
  paid down by removing BOTH. Editing one side alone fails this suite.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @ledger_path Path.join(@repo_root, "HANDWRITTEN.md")
  @ontology_path Path.join(@repo_root, "ontology.ttl")
  @successor_owner "ash-extension-pack (ggen-marketplace)"
  @dead_owner "ash-extension-core"
  @tripwire "test/ash_surface/handwritten_ledger_test.exs"
  @date_format ~r/^\d{4}-\d{2}-\d{2}$/

  # chicago-runtime-ledger-037: the shipped JS runtime is hand-maintained pack
  # source; its admitted row must name the JS runtime template family as the
  # owner capability and carry the byte-provenance note pointing at the golden
  # whole-file SHA-256 law (runtime_source_test.exs), which already pins the
  # artifact bytes.
  @runtime_path "priv/static/ash_surface_runtime.mjs"
  @runtime_capability_prefix "JS runtime template family emission in ash-extension-pack"
  @runtime_provenance_law "test/ash_surface/runtime_source_test.exs"

  test "ledger and ontology UNSUPPORTED rows are in exact bijection" do
    ledger = ledger_rows()
    unsupported = unsupported_rows()

    assert ledger != [], "HANDWRITTEN.md parsed to zero rows — the ledger vanished"

    assert length(ledger) == length(unsupported),
           "帳 law violated: #{length(ledger)} open ledger rows but " <>
             "#{length(unsupported)} UNSUPPORTED ontology rows"

    ledger_keys = MapSet.new(ledger, &{&1.path, &1.capability})
    ontology_keys = MapSet.new(unsupported, &{&1.path, &1.element})

    assert MapSet.equal?(ledger_keys, ontology_keys),
           "帳 law violated: (path, element) sets differ. " <>
             "ledger-only: #{inspect(MapSet.difference(ledger_keys, ontology_keys))} " <>
             "ontology-only: #{inspect(MapSet.difference(ontology_keys, ledger_keys))}"

    by_key = Map.new(unsupported, &{{&1.path, &1.element}, &1})

    for row <- ledger do
      pair = Map.fetch!(by_key, {row.path, row.capability})

      assert pair.generator == row.owner,
             "owner mismatch for #{row.path}: ledger says #{row.owner}, ontology says #{pair.generator}"

      assert pair.date == row.date,
             "date mismatch for #{row.path}: ledger says #{row.date}, ontology says #{pair.date}"
    end
  end

  test "every ledger row names the real successor owner, never the deleted pack" do
    for row <- ledger_rows() do
      assert row.owner == @successor_owner,
             "row #{row.path} names owner #{inspect(row.owner)}; intended owner must be the real on-disk successor"

      refute row.path =~ @dead_owner,
             "row path re-references the deleted pack: #{row.path}"

      refute row.capability =~ @dead_owner,
             "row capability re-references the deleted pack: #{row.capability}"
    end
  end

  test "every ledger row carries a commit-verified ISO date" do
    for row <- ledger_rows() do
      assert row.date =~ @date_format,
             "row #{row.path} date #{inspect(row.date)} is not an ISO calendar date; dates must be birth-commit-verified (gapfix-ledger-011)"
    end
  end

  test "every UNSUPPORTED ontology row carries the tripwire anchor" do
    for pair <- unsupported_rows() do
      assert pair.enforced_by == @tripwire,
             "UNSUPPORTED row for #{pair.path} must name its enforcement anchor"
    end
  end

  test "the shipped JS runtime carries its admitted ledger row with byte-provenance" do
    row =
      ledger_rows()
      |> Enum.filter(&(&1.path == @runtime_path))
      |> Enum.find(&String.starts_with?(&1.capability, @runtime_capability_prefix))

    assert row,
           "帳 law violated: #{@runtime_path} is hand-maintained pack source with no " <>
             "HANDWRITTEN row naming the JS runtime template family owner capability " <>
             "(chicago-runtime-ledger-037)"

    assert row.element =~ "SHA-256" and row.element =~ @runtime_provenance_law,
           "runtime ledger row must carry the byte-provenance note pointing at the " <>
             "golden whole-file SHA-256 law (#{@runtime_provenance_law})"
  end

  test "the shipped JS runtime's UNSUPPORTED pair is admitted with the same family naming" do
    pair =
      unsupported_rows()
      |> Enum.filter(&(&1.path == @runtime_path))
      |> Enum.find(&String.starts_with?(&1.element, @runtime_capability_prefix))

    assert pair,
           "帳 law violated: no UNSUPPORTED ontology row for #{@runtime_path} naming the " <>
             "JS runtime template family; ledger row and UNSUPPORTED pair are admitted " <>
             "together or not at all (chicago-runtime-ledger-037)"
  end

  defp ledger_rows do
    @ledger_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(&(not String.contains?(&1, " | ")))
    |> Enum.reject(&(String.starts_with?(&1, "#") or String.starts_with?(&1, "Format:")))
    |> Enum.map(fn line ->
      case String.split(line, " | ") do
        [path, element, capability, owner, date] ->
          %{
            path: String.trim(path),
            element: String.trim(element),
            capability: String.trim(capability),
            owner: String.trim(owner),
            date: String.trim(date)
          }

        fields ->
          flunk(
            "HANDWRITTEN.md row does not have exactly 5 pipe-separated fields (#{length(fields)}): #{line}"
          )
      end
    end)
  end

  defp unsupported_rows do
    blocks =
      @ontology_path
      |> File.read!()
      |> String.split(~r/(?=surf:UnsupportedLedgerRow\d+ a surf:UnsupportedRow)/)
      |> Enum.filter(&String.starts_with?(&1, "surf:UnsupportedLedgerRow"))

    Enum.map(blocks, fn block ->
      %{
        path: fetch!(block, "surf:ledgerPath"),
        generator: fetch!(block, "surf:unsupportedGenerator"),
        element: fetch!(block, "surf:unsupportedElement"),
        date: fetch!(block, "surf:ledgerDate"),
        enforced_by: fetch!(block, "surf:enforcedBy")
      }
    end)
  end

  defp fetch!(block, predicate) do
    case Regex.run(~r/#{predicate} "([^"]*)"/, block) do
      [_, value] ->
        value

      _ ->
        flunk("ontology UNSUPPORTED block is missing predicate #{predicate}: #{inspect(block)}")
    end
  end
end
