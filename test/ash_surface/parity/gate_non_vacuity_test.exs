defmodule AshSurface.Parity.GateNonVacuityFixture do
  @moduledoc false
  @readme_quote "no generated `.ts`, no `.d.ts`, no `tsc` build step"

  def fixture_root! do
    root = Path.join(System.tmp_dir!(), "parity-gate-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(root, "test"))
    File.mkdir_p!(Path.join(root, "docs/zod-port/receipts"))
    File.mkdir_p!(Path.join(root, "parity"))
    File.mkdir_p!(Path.join(root, "docs"))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(root) end)

    File.write!(Path.join(root, "README.md"), "There is no TS. #{@readme_quote}. End.\n")

    File.write!(
      Path.join(root, "test/thing_test.exs"),
      "defmodule T do\n  test \"does the thing\" do\n    assert alpha() == 1\n  end\n  def alpha, do: 1\nend\n"
    )

    File.write!(
      Path.join(root, "docs/zod-port/receipts/ok.md"),
      "# R\n\nStanding: PASS\n\nPASS test/thing_test.exs: 1 test, 0 failures\n"
    )

    File.write!(Path.join(root, "docs/zod-port/receipts/weak.md"), "# R\n\nStanding: PARTIAL\n")
    root
  end

  def write_fixture!(root, inventory_ids, entries, kd_rows \\ []) do
    caps =
      for id <- inventory_ids,
          do: %{"id" => id, "section" => hd(String.split(id, ".")), "source" => "x"}

    File.write!(
      Path.join(root, "parity/capabilities.json"),
      Jason.encode!(%{"advisory" => %{}, "capabilities" => caps})
    )

    File.write!(Path.join(root, "parity/court_map.json"), Jason.encode!(%{"entries" => entries}))

    header =
      "| id | surface | divergence | better_because | court | receipt | close condition |\n|--|--|--|--|--|--|--|\n"

    File.write!(
      Path.join(root, "docs/KNOWN_DIVERGENCES.md"),
      "# KD\n\n" <> header <> Enum.join(kd_rows, "\n") <> "\n"
    )

    root
  end
end

defmodule AshSurface.Parity.GateNonVacuityTest do
  @moduledoc """
  Shim court for the parity gate (smalt `scripts/shim_court/lib.sh` method):

      BASELINE (sha256) -> BEFORE (old outcome) -> SHIM -> AFTER (new outcome) -> RESTORE (sha256)

  Every shim mutates a temp COPY of the register inputs; the restore is verified
  byte-exact. A gate that accepts a shim is a VACUOUS GATE and raises. The
  corrupt-restore self-check proves restore detection itself is not vacuous.
  """
  use ExUnit.Case, async: true

  import AshSurface.Parity.GateNonVacuityFixture, only: [fixture_root!: 0, write_fixture!: 3]

  alias AshSurface.Parity.Report

  @repo Path.expand("../../..", __DIR__)
  @pass %{
    "status" => "pass",
    "tests" => [%{"file" => "test/thing_test.exs", "test" => "does the thing"}]
  }

  defp sha(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

  # Mutate `file` in place, run `after_fun`, then restore from the original bytes.
  # Returns {:ok, after_result} | {:error, :restore_mismatch}. `corrupt_restore: true`
  # restores wrong bytes to prove the sha256 check detects it.
  defp with_shim(file, mutate, after_fun, opts \\ []) do
    original = File.read!(file)
    baseline = sha(file)
    File.write!(file, mutate.(original))
    shimmed = after_fun.()
    File.write!(file, if(opts[:corrupt_restore], do: original <> " ", else: original))
    if sha(file) == baseline, do: {:ok, shimmed}, else: {:error, :restore_mismatch}
  end

  defp assert_not_vacuous(%{exit: 0} = r, label),
    do: flunk("VACUOUS GATE: #{label} accepted by the gate (exit 0): #{inspect(r.counts)}")

  defp assert_not_vacuous(r, _), do: r

  setup do
    root = fixture_root!()

    write_fixture!(root, ~w(a.one a.two a.three), %{
      "a.one" => @pass,
      "a.two" => @pass,
      "a.three" => @pass
    })

    {:ok,
     root: root,
     map: Path.join(root, "parity/court_map.json"),
     inv: Path.join(root, "parity/capabilities.json")}
  end

  test "baseline fixture is green (a shim court on a red baseline would prove nothing)", %{
    root: root
  } do
    assert %{exit: 0, missing: [], errors: []} = Report.evaluate(root: root)
  end

  test "(a) deleting one pass mapping -> exit 1 naming the id; restore byte-exact", %{
    root: root,
    map: map
  } do
    delete = fn text ->
      text
      |> Jason.decode!()
      |> update_in(["entries"], &Map.delete(&1, "a.two"))
      |> Jason.encode!()
    end

    {:ok, r} = with_shim(map, delete, fn -> Report.evaluate(root: root) end)
    r = assert_not_vacuous(r, "deleted mapping")
    assert r.exit == 1
    assert r.missing == ["a.two"]
    assert Report.render(r) =~ "MISSING a.two"
    assert %{exit: 0} = Report.evaluate(root: root)
  end

  test "(b) pointing a mapping at a nonexistent test file -> exit 1 naming the id", %{
    root: root,
    map: map
  } do
    redirect = fn text ->
      String.replace(text, "test/thing_test.exs", "test/does_not_exist_test.exs", global: false)
    end

    {:ok, r} = with_shim(map, redirect, fn -> Report.evaluate(root: root) end)
    r = assert_not_vacuous(r, "mapping to a missing test file")
    assert r.counts.broken == 1
    assert Enum.any?(r.errors, &(&1 =~ "does_not_exist_test.exs: test file does not exist"))
    assert %{exit: 0} = Report.evaluate(root: root)
  end

  test "(b') pointing a mapping at an existing file lacking the named test -> exit 1", %{
    root: root,
    map: map
  } do
    rename = fn text ->
      String.replace(text, "does the thing", "a test that is not there", global: false)
    end

    {:ok, r} = with_shim(map, rename, fn -> Report.evaluate(root: root) end)
    r = assert_not_vacuous(r, "mapping to an absent test title")
    assert r.counts.broken == 1
    assert %{exit: 0} = Report.evaluate(root: root)
  end

  test "(c) a fake inventory id -> exit 1 as MISSING", %{root: root, inv: inv} do
    add = fn text ->
      text
      |> Jason.decode!()
      |> update_in(
        ["capabilities"],
        &(&1 ++ [%{"id" => "fake.capability.zzz", "section" => "fake", "source" => "x"}])
      )
      |> Jason.encode!()
    end

    {:ok, r} = with_shim(inv, add, fn -> Report.evaluate(root: root) end)
    r = assert_not_vacuous(r, "fake inventory id")
    assert r.missing == ["fake.capability.zzz"]
    assert Report.to_json(r) =~ "fake.capability.zzz"
    assert %{exit: 0} = Report.evaluate(root: root)
  end

  test "(d) corrupt-restore self-check: a broken restore is detected, a good one is not", %{
    map: map
  } do
    ident = & &1

    assert {:error, :restore_mismatch} =
             with_shim(map, ident, fn -> :noop end, corrupt_restore: true)

    File.write!(map, File.read!(map) |> String.trim_trailing())
    assert {:ok, :noop} = with_shim(map, ident, fn -> :noop end)
  end

  test "(e) shims on a COPY of the live register: deletion moves the id out of pass", %{
    root: root
  } do
    live_map = Path.join(@repo, "parity/court_map.json")
    live_inv = Path.join(@repo, "parity/capabilities.json")
    copy_dir = Path.join(root, "live-copy")
    File.mkdir_p!(copy_dir)
    map_copy = Path.join(copy_dir, "court_map.json")
    File.cp!(live_map, map_copy)

    opts = [root: @repo, inventory_path: live_inv, map_path: map_copy]
    before = Report.evaluate(opts)
    assert before.counts.pass > 0

    victim = before.rows |> Enum.find(&(&1.status == :pass)) |> Map.fetch!(:id)
    live_before = sha(live_map)

    drop = fn text ->
      text
      |> Jason.decode!()
      |> update_in(["entries"], &Map.delete(&1, victim))
      |> Jason.encode!()
    end

    {:ok, shimmed} = with_shim(map_copy, drop, fn -> Report.evaluate(opts) end)

    assert victim in shimmed.missing
    assert shimmed.counts.pass == before.counts.pass - 1
    assert shimmed.exit == 1
    assert Report.evaluate(opts).counts == before.counts
    assert sha(live_map) == live_before, "shim must act on the copy, never the live register"
  end

  test "(f) divergence-law shim: an unwitnessed KD row cannot close a capability", %{root: root} do
    File.write!(
      Path.join(root, "parity/court_map.json"),
      Jason.encode!(%{"entries" => %{"a.one" => %{"status" => "divergence", "kd" => "KD-01"}}})
    )

    File.write!(
      Path.join(root, "parity/capabilities.json"),
      Jason.encode!(%{"capabilities" => [%{"id" => "a.one", "section" => "a", "source" => "x"}]})
    )

    kd = Path.join(root, "docs/KNOWN_DIVERGENCES.md")
    row = "| KD-01 | s | d | better | test/thing_test.exs | docs/zod-port/receipts/ok.md | c |\n"

    header =
      "| id | surface | divergence | better_because | court | receipt | close condition |\n|--|--|--|--|--|--|--|\n"

    File.write!(kd, header <> row)
    assert %{exit: 0, counts: %{divergence: 1}} = Report.evaluate(root: root)

    {:ok, r} =
      with_shim(
        kd,
        &String.replace(&1, "docs/zod-port/receipts/ok.md", "docs/zod-port/receipts/weak.md"),
        fn ->
          Report.evaluate(root: root)
        end
      )

    r = assert_not_vacuous(r, "divergence with PARTIAL receipt")
    assert r.missing == ["a.one"]
  end

  test "(g) test_helper exclude shim: a court under a globally excluded tag is non-passing",
       %{root: root} do
    entries = %{
      "a.one" => %{
        "status" => "pass",
        "tests" => [%{"file" => "test/thing_test.exs", "test" => "does the thing"}]
      }
    }

    AshSurface.Parity.GateNonVacuityFixture.write_fixture!(root, ["a.one"], entries)

    File.write!(
      Path.join(root, "test/thing_test.exs"),
      "defmodule T do\n  @tag :slow\n  test \"does the thing\" do\n    assert 1 == 1\n  end\nend\n"
    )

    helper = Path.join(root, "test/test_helper.exs")
    File.write!(helper, "ExUnit.start()\n")
    assert %{exit: 0, counts: %{pass: 1}} = Report.evaluate(root: root)

    {:ok, r} =
      with_shim(helper, fn _ -> "ExUnit.start(exclude: [:slow])\n" end, fn ->
        Report.evaluate(root: root)
      end)

    r = assert_not_vacuous(r, "excluded-tag court")
    assert r.counts.broken == 1
    assert Enum.any?(r.errors, &String.contains?(&1, "EXCLUDED"))
  end

  test "(g2) AST tags: tag buried in a multi-line list/keyword is excluded, unrelated tag is not",
       %{root: root} do
    entries = %{
      "a.one" => %{
        "status" => "pass",
        "tests" => [%{"file" => "test/thing_test.exs", "test" => "does the thing"}]
      }
    }

    AshSurface.Parity.GateNonVacuityFixture.write_fixture!(root, ["a.one"], entries)
    helper = Path.join(root, "test/test_helper.exs")
    File.write!(helper, "ExUnit.start(exclude: [:slow])\n")
    file = Path.join(root, "test/thing_test.exs")

    tagged =
      "defmodule T do\n  @tag [\n    timeout: 5,\n    cases: [1, 2],\n    slow: true\n  ]\n\n" <>
        "  # note\n  test \"does the thing\" do\n    assert 1 == 1\n  end\nend\n"

    File.write!(file, tagged)
    r = Report.evaluate(root: root)
    assert Enum.any?(r.errors, &String.contains?(&1, "EXCLUDED"))

    File.write!(file, String.replace(tagged, "slow: true", "slow: false"))
    assert %{exit: 0, counts: %{pass: 1}} = Report.evaluate(root: root)

    File.write!(
      file,
      "defmodule T do\n  describe \"d\" do\n    @describetag slow: true\n\n    test \"does the thing\" do\n      assert 1 == 1\n    end\n  end\nend\n"
    )

    r = Report.evaluate(root: root)
    assert Enum.any?(r.errors, &String.contains?(&1, "EXCLUDED"))
  end
end
