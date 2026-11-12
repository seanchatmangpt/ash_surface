defmodule AshSurface.ParityTests.GateNonVacuityFixture do
  @moduledoc false
  @quote_line "no generated `.ts`, no `.d.ts`,\nno `tsc` build step"

  def quote_text, do: "no generated `.ts`, no `.d.ts`, no `tsc` build step"

  def fixture_root! do
    root = Path.join(System.tmp_dir!(), "parity-tests-gate-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(root, "test/ash_surface/ported/rpc"))
    File.mkdir_p!(Path.join(root, "parity"))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(root) end)

    # The README wraps the quote across a line: verbatim means whitespace-collapsed.
    File.write!(Path.join(root, "README.md"), "# R\n\nThere is #{@quote_line}. End.\n")

    File.write!(
      Path.join(root, "test/ash_surface/ported/rpc/a_test.exs"),
      "defmodule A do\n  use ExUnit.Case\n  test \"one\" do\n  end\n\n  test \"two\" do\n  end\nend\n"
    )

    File.write!(
      Path.join(root, "test/ash_surface/ported/rpc/zod_adapted_test.exs"),
      "defmodule Z do\n  use ExUnit.Case\n  # runs node with real zod\n  test \"zod\" do\n    System.cmd(\"node\", [])\n  end\nend\n"
    )

    File.write!(
      Path.join(root, "test/ash_surface/ported/rpc/gap_test.exs"),
      "defmodule G do\n  use ExUnit.Case\n  @tag skip: \"[SKIP] gap-x: no counterpart\"\n  test \"g\" do\n    flunk(\"unreachable\")\n  end\nend\n"
    )

    rows = [
      row("test/ash_typescript/rpc/a_test.exs", "ported",
        tests: ["test/ash_surface/ported/rpc/a_test.exs"]
      ),
      row("test/ash_typescript/rpc/z_test.exs", "adapted",
        tests: ["test/ash_surface/ported/rpc/zod_adapted_test.exs"],
        changes: "TS text asserts converted to zod under node"
      ),
      row("test/ash_typescript/rpc/g_test.exs", "skipped_gap",
        tests: ["test/ash_surface/ported/rpc/gap_test.exs"],
        gap: "no counterpart capability",
        skip_tag: "[SKIP] gap-x"
      ),
      row("test/ts/shouldPass/n.ts", "non_goal", quote: quote_text())
    ]

    files =
      for r <- rows,
          do: %{
            "file" => r["file"],
            "kind" => if(String.ends_with?(r["file"], ".ts"), do: "ts", else: "exs"),
            "describes" => [],
            "tests" => ["t"],
            "test_count" => 1,
            "expect_errors" => 0
          }

    write_inventory!(root, files)
    write_ledger!(root, rows)
    root
  end

  def row(file, disp, opts \\ []) do
    %{
      "file" => file,
      "disposition" => disp,
      "ash_surface_tests" => Keyword.get(opts, :tests, []),
      "changes" => Keyword.get(opts, :changes, ""),
      "gap" => Keyword.get(opts, :gap, ""),
      "skip_tag" => Keyword.get(opts, :skip_tag, ""),
      "readme_quote" => Keyword.get(opts, :quote, ""),
      "capabilities" => [],
      "owner_lane" => "T0",
      "note" => ""
    }
  end

  def write_inventory!(root, files) do
    File.write!(
      Path.join(root, "parity/test_inventory.json"),
      Jason.encode!(%{"reference_head" => nil, "files" => files})
    )
  end

  def write_ledger!(root, rows),
    do: File.write!(Path.join(root, "parity/test_ledger.json"), Jason.encode!(%{"rows" => rows}))
end

defmodule AshSurface.ParityTests.GateNonVacuityTest do
  @moduledoc """
  Shim court for the test-port gate (smalt `scripts/shim_court/lib.sh` method):

      BASELINE (sha256) -> BEFORE (green) -> SHIM -> AFTER (exit 1) -> RESTORE (sha256)

  Every shim mutates a temp COPY of the ledger/inventory/test inputs and the restore is
  verified byte-exact. A gate that accepts a shim is a VACUOUS GATE and raises. The
  corrupt-restore self-check proves restore detection is not vacuous.
  """
  use ExUnit.Case, async: true

  import AshSurface.ParityTests.GateNonVacuityFixture

  alias AshSurface.ParityTests.{Inventory, Report}

  defp sha(path), do: :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)

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

  defp edit_ledger(root, fun) do
    fn text ->
      rows = text |> Jason.decode!() |> Map.fetch!("rows")
      Jason.encode!(%{"rows" => fun.(rows)})
    end
    |> then(&{Path.join(root, "parity/test_ledger.json"), &1})
  end

  defp problems(r, file), do: r.cells |> Enum.find(&(&1.file == file)) |> Map.fetch!(:problems)

  setup do
    {:ok, root: fixture_root!()}
  end

  test "baseline fixture is green (a shim court on a red baseline proves nothing)", %{root: root} do
    r = Report.evaluate(root: root)
    assert r.exit == 0, inspect(r.cells, pretty: true)

    assert r.counts == %{
             files: 4,
             ported: 1,
             adapted: 1,
             skipped_gap: 1,
             non_goal: 1,
             unaccounted: 0,
             broken: 0
           }

    assert r.shallow == 0

    assert Report.summary(r) ==
             "parity-tests: files=4 ported=1 adapted=1 skipped_gap=1 non_goal=1 unaccounted=0 broken=0 shallow=0"
  end

  test "(a) deleting a ledger row -> unaccounted, exit 1; restore byte-exact", %{root: root} do
    {file, mutate} =
      edit_ledger(root, fn rows ->
        Enum.reject(rows, &(&1["file"] == "test/ash_typescript/rpc/a_test.exs"))
      end)

    assert {:ok, r} =
             with_shim(file, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("deleted ledger row")
             end)

    assert r.exit == 1
    assert r.counts.unaccounted == 1
    assert problems(r, "test/ash_typescript/rpc/a_test.exs") == ["no ledger row"]
    assert %{exit: 0} = Report.evaluate(root: root)
  end

  test "(b) a ported row pointing at a missing file -> broken, exit 1", %{root: root} do
    {file, mutate} =
      edit_ledger(root, fn rows ->
        Enum.map(rows, fn
          %{"disposition" => "ported"} = r ->
            %{r | "ash_surface_tests" => ["test/ash_surface/ported/rpc/nope_test.exs"]}

          r ->
            r
        end)
      end)

    assert {:ok, r} =
             with_shim(file, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("missing test file")
             end)

    assert r.counts.broken == 1
    assert hd(problems(r, "test/ash_typescript/rpc/a_test.exs")) =~ "does not exist"
  end

  test "(c) a skip behind a multi-line @tag skip continuation -> broken, exit 1", %{root: root} do
    path = Path.join(root, "test/ash_surface/ported/rpc/a_test.exs")

    mutate = fn text ->
      String.replace(
        text,
        "  test \"two\" do",
        "  @tag skip:\n         \"hidden \" <>\n           \"behind a continuation\"\n  test \"two\" do"
      )
    end

    assert {:ok, r} =
             with_shim(path, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("multi-line skip")
             end)

    assert hd(problems(r, "test/ash_typescript/rpc/a_test.exs")) =~ "contains a skip"
  end

  test "(d) a skipped_gap whose file lacks the tag text -> broken, exit 1", %{root: root} do
    path = Path.join(root, "test/ash_surface/ported/rpc/gap_test.exs")

    assert {:ok, r} =
             with_shim(
               path,
               &String.replace(&1, "[SKIP] gap-x", "[SKIP] other"),
               fn -> Report.evaluate(root: root) |> assert_not_vacuous("tag text absent") end
             )

    assert hd(problems(r, "test/ash_typescript/rpc/g_test.exs")) =~ "not found in file"
  end

  test "(d2) a skipped_gap whose skip was removed (tag text only) -> broken", %{root: root} do
    path = Path.join(root, "test/ash_surface/ported/rpc/gap_test.exs")

    mutate = fn text ->
      text
      |> String.replace("  @tag skip: \"[SKIP] gap-x: no counterpart\"\n", "  # [SKIP] gap-x\n")
    end

    assert {:ok, r} =
             with_shim(path, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("tag text without skip")
             end)

    assert hd(problems(r, "test/ash_typescript/rpc/g_test.exs")) =~ "contains no skip"
  end

  test "(d3) a skipped_gap without a gap description -> broken", %{root: root} do
    {file, mutate} =
      edit_ledger(root, fn rows ->
        Enum.map(rows, fn
          %{"disposition" => "skipped_gap"} = r -> %{r | "gap" => " "}
          r -> r
        end)
      end)

    assert {:ok, r} =
             with_shim(file, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("empty gap")
             end)

    assert "skipped_gap row has empty gap description" in problems(
             r,
             "test/ash_typescript/rpc/g_test.exs"
           )
  end

  test "(e) a non_goal with a fake README quote -> broken, exit 1", %{root: root} do
    {file, mutate} =
      edit_ledger(root, fn rows ->
        Enum.map(rows, fn
          %{"disposition" => "non_goal"} = r ->
            %{r | "readme_quote" => "this sentence is not in the README"}

          r ->
            r
        end)
      end)

    assert {:ok, r} =
             with_shim(file, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("fake quote")
             end)

    assert hd(problems(r, "test/ts/shouldPass/n.ts")) =~ "not a verbatim substring"
  end

  test "(f) an orphan ledger row -> broken, exit 1", %{root: root} do
    {file, mutate} =
      edit_ledger(root, fn rows ->
        [row("test/ash_typescript/ghost_test.exs", "non_goal") | rows]
      end)

    assert {:ok, r} =
             with_shim(file, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("orphan row")
             end)

    assert r.counts.broken == 1
    assert Enum.any?(r.cells, &(&1.dir == "(orphan)"))
  end

  test "(g) a ts reference marked ported, an adapted row without changes -> broken", %{root: root} do
    {file, mutate} =
      edit_ledger(root, fn rows ->
        Enum.map(rows, fn
          %{"disposition" => "adapted"} = r ->
            %{r | "changes" => ""}

          %{"disposition" => "non_goal"} = r ->
            %{
              r
              | "disposition" => "ported",
                "ash_surface_tests" => ["test/ash_surface/ported/rpc/a_test.exs"]
            }

          r ->
            r
        end)
      end)

    assert {:ok, r} =
             with_shim(file, mutate, fn ->
               Report.evaluate(root: root) |> assert_not_vacuous("ts ported / empty changes")
             end)

    assert r.counts.broken == 2
    assert "adapted row has empty changes" in problems(r, "test/ash_typescript/rpc/z_test.exs")
    assert hd(problems(r, "test/ts/shouldPass/n.ts")) =~ "cannot be ported verbatim"
  end

  test "(h) an adapted test with no node/zod/renderer reference is SHALLOW, not exit-affecting",
       %{root: root} do
    path = Path.join(root, "test/ash_surface/ported/rpc/zod_adapted_test.exs")

    assert {:ok, r} =
             with_shim(
               path,
               fn _ ->
                 "defmodule Z do\n  use ExUnit.Case\n  test \"plain\" do\n    assert 1 == 1\n  end\nend\n"
               end,
               fn -> Report.evaluate(root: root) end
             )

    assert r.exit == 0
    assert r.shallow == 1
    assert Report.summary(r) =~ "shallow=1"
  end

  test "(i) an unreadable ledger or inventory -> exit 1 (fatal)", %{root: root} do
    ledger = Path.join(root, "parity/test_ledger.json")

    assert {:ok, r} =
             with_shim(ledger, fn _ -> "{not json" end, fn -> Report.evaluate(root: root) end)

    assert r.exit == 1 and r.fatal =~ "unreadable"

    inv = Path.join(root, "parity/test_inventory.json")
    assert {:ok, r2} = with_shim(inv, fn _ -> "" end, fn -> Report.evaluate(root: root) end)
    assert r2.exit == 1
  end

  test "(j) a fake inventory file fails the byte-compare against the reference tree" do
    ref = Path.join(System.tmp_dir!(), "parity-tests-ref-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(ref, "test/ts"))
    on_exit(fn -> File.rm_rf!(ref) end)

    File.write!(
      Path.join(ref, "test/sample_test.exs"),
      "defmodule S do\n  use ExUnit.Case\n  describe \"d\" do\n    test \"t1\" do\n    end\n  end\nend\n"
    )

    File.write!(
      Path.join(ref, "test/ts/x.ts"),
      "// Test 1: first\nexport function testTwo() {}\n"
    )

    {:ok, inv} = Inventory.derive(ref)
    committed = Path.join(ref, "inventory.json")
    File.write!(committed, Inventory.to_json(inv))
    assert {:ok, 2, nil} = Inventory.check(ref, committed)

    assert {:ok, {:error, msg}} =
             with_shim(
               committed,
               &String.replace(&1, "\"test_count\":1", "\"test_count\":99"),
               fn -> Inventory.check(ref, committed) end
             )

    assert msg =~ "inventory drift"

    # a new reference test file the committed inventory does not know also drifts
    File.write!(
      Path.join(ref, "test/new_test.exs"),
      "defmodule N do\n  test \"n\" do\n  end\nend\n"
    )

    assert {:error, drift} = Inventory.check(ref, committed)
    assert drift =~ "inventory drift"
    assert {:ok, 3, nil} = Inventory.check(ref, write_fresh!(ref))
  end

  defp write_fresh!(ref) do
    path = Path.join(ref, "fresh.json")
    {:ok, inv} = Inventory.derive(ref)
    File.write!(path, Inventory.to_json(inv))
    path
  end

  test "corrupt-restore self-check: a wrong restore is detected, not trusted", %{root: root} do
    ledger = Path.join(root, "parity/test_ledger.json")

    assert {:error, :restore_mismatch} =
             with_shim(ledger, & &1, fn -> :ok end, corrupt_restore: true)
  end

  test "a shim the gate accepts raises VACUOUS GATE", %{root: root} do
    # An inert mutation (no semantic change) must be accepted by the gate, and the
    # assertion helper must turn that acceptance into a loud failure.
    ledger = Path.join(root, "parity/test_ledger.json")

    assert {:ok, r} = with_shim(ledger, &(&1 <> "\n"), fn -> Report.evaluate(root: root) end)
    assert r.exit == 0

    assert_raise ExUnit.AssertionError, ~r/VACUOUS GATE/, fn ->
      assert_not_vacuous(r, "inert shim")
    end
  end
end
