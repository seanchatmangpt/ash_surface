defmodule AshSurface.Parity.GateTest do
  @moduledoc "Gate laws over a real on-disk fixture root (no doubles)."
  use ExUnit.Case, async: true

  alias AshSurface.Parity.{CourtMap, Register, Report}

  @quote "no generated `.ts`, no `.d.ts`, no `tsc` build step"

  @doc false
  def fixture_root! do
    root = Path.join(System.tmp_dir!(), "parity-gate-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(root, "test"))
    File.mkdir_p!(Path.join(root, "docs/zod-port/receipts"))
    File.mkdir_p!(Path.join(root, "parity"))
    File.mkdir_p!(Path.join(root, "docs"))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf!(root) end)

    File.write!(Path.join(root, "README.md"), "There is no TS. #{@quote}. End.\n")

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

  @doc false
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

  @pass %{
    "status" => "pass",
    "tests" => [%{"file" => "test/thing_test.exs", "test" => "does the thing"}]
  }

  test "green fixture: pass + witnessed divergence + README non_goal exit 0" do
    root = fixture_root!()

    write_fixture!(
      root,
      ~w(a.pass a.div a.ng),
      %{
        "a.pass" => @pass,
        "a.div" => %{"status" => "divergence", "kd" => "KD-01"},
        "a.ng" => %{"status" => "non_goal", "reason" => "ts", "readme" => @quote}
      },
      [
        "| KD-01 | s | d | better because X | test/thing_test.exs | docs/zod-port/receipts/ok.md | c |"
      ]
    )

    r = Report.evaluate(root: root)
    assert r.errors == []
    assert r.counts == %{pass: 1, divergence: 1, non_goal: 1, broken: 0, missing: 0}
    assert r.exit == 0
  end

  test "operator law: an unwitnessed divergence is MISSING, never a close" do
    for {row, why} <- [
          {"| KD-01 | s | d |  | test/thing_test.exs | docs/zod-port/receipts/ok.md | c |",
           "better_because empty"},
          {"| KD-01 | s | d | b | test/nope_test.exs | docs/zod-port/receipts/ok.md | c |",
           "not an existing repo file"},
          {"| KD-01 | s | d | b | test/thing_test.exs | docs/zod-port/receipts/weak.md | c |",
           "not ALIVE|PASS"}
        ] do
      root = fixture_root!()

      write_fixture!(
        root,
        ~w(a.div),
        %{"a.div" => %{"status" => "divergence", "kd" => "KD-01"}},
        [row]
      )

      r = Report.evaluate(root: root)
      assert r.missing == ["a.div"], row
      assert r.exit == 1
      assert Enum.join(hd(r.rows).problems) =~ why
    end
  end

  test "operator law: a non_goal without a verbatim README quote is MISSING" do
    for entry <- [
          %{"status" => "non_goal", "reason" => "valibot"},
          %{
            "status" => "non_goal",
            "reason" => "valibot",
            "readme" => "text that is not in the README"
          }
        ] do
      root = fixture_root!()
      write_fixture!(root, ~w(a.ng), %{"a.ng" => entry})
      r = Report.evaluate(root: root)
      assert r.missing == ["a.ng"]
      assert r.exit == 1
    end
  end

  test "unmapped debt entries are MISSING with their reason" do
    root = fixture_root!()
    write_fixture!(root, ~w(a.x), %{"a.x" => %{"status" => "unmapped", "reason" => "w3 debt"}})
    r = Report.evaluate(root: root)
    assert r.missing == ["a.x"]
    assert Report.render(r) =~ "MISSING a.x  (unmapped debt: w3 debt)"
  end

  test "{leaf} wildcard rules pass only for ids the court file actually names" do
    root = fixture_root!()

    rule = %{
      "status" => "pass",
      "tests" => [%{"file" => "test/thing_test.exs", "contains" => "{leaf}"}]
    }

    write_fixture!(root, ~w(k.alpha k.beta), %{"k.*" => rule})
    r = Report.evaluate(root: root)
    assert r.missing == ["k.beta"]
    assert r.counts.pass == 1
  end

  test "any_of passes on one clean reference and flags stale pointers as broken" do
    root = fixture_root!()
    ok = %{"file" => "test/thing_test.exs", "contains" => "alpha"}
    ok2 = %{"file" => "test/thing_test.exs", "test" => "does the thing"}
    gone = %{"file" => "test/gone_test.exs", "contains" => "alpha"}
    write_fixture!(root, ~w(a.x), %{"a.x" => %{"status" => "pass", "any_of" => [ok, ok2]}})
    assert Report.evaluate(root: root).exit == 0
    write_fixture!(root, ~w(a.x), %{"a.x" => %{"status" => "pass", "any_of" => [ok, gone]}})
    r = Report.evaluate(root: root)
    assert r.exit == 1
    assert r.counts.broken == 1
  end

  test "stale map entries and unreadable inputs fail the gate" do
    root = fixture_root!()
    write_fixture!(root, ~w(a.x), %{"a.x" => @pass, "zzz.old" => @pass, "yyy.*" => @pass})
    r = Report.evaluate(root: root)
    assert r.exit == 1
    assert Enum.any?(r.errors, &(&1 =~ "zzz.old"))
    assert Enum.any?(r.errors, &(&1 =~ "yyy.*"))

    File.rm!(Path.join(root, "parity/court_map.json"))
    fatal = Report.evaluate(root: root)
    assert fatal.exit == 1
    assert fatal.fatal =~ "court_map.json"
  end

  test "exact entries beat prefix rules; longest prefix wins" do
    entries = %{"a.*" => :short, "a.b.*" => :long, "a.b.c" => :exact}
    assert {"a.b.c", :exact} = CourtMap.resolve(entries, "a.b.c")
    assert {"a.b.*", :long} = CourtMap.resolve(entries, "a.b.d")
    assert {"a.*", :short} = CourtMap.resolve(entries, "a.z")
    assert CourtMap.resolve(entries, "q.z") == nil
  end

  test "register parse + receipt lint" do
    root = fixture_root!()

    text = """
    | id | surface | divergence | better_because | court | receipt | close condition |
    |--|--|--|--|--|--|--|
    | KD-01 | s | d | b | test/thing_test.exs | docs/zod-port/receipts/ok.md | c |
    | KD-02 | s | d | b | test/thing_test.exs | docs/zod-port/receipts/missing.md | c |
    | KD-03 | s | d | b | test/thing_test.exs | README.md | c |
    | KD-01 | s | d | b | test/thing_test.exs | docs/zod-port/receipts/ok.md | c |
    """

    rows = Register.parse(text)
    assert Enum.map(rows, & &1.id) == ["KD-01", "KD-02", "KD-03", "KD-01"]
    problems = Register.lint(rows, root)
    assert Enum.any?(problems, &(&1 =~ "duplicate"))
    assert Enum.any?(problems, &(&1 =~ "KD-02" and &1 =~ "does not exist"))
    assert Enum.any?(problems, &(&1 =~ "KD-03" and &1 =~ "no Standing"))
    refute Enum.any?(problems, &(&1 =~ "KD-01: receipt"))
  end

  test "a receipt Standing outside the closed vocabulary is refused" do
    root = fixture_root!()

    File.write!(
      Path.join(root, "docs/zod-port/receipts/odd.md"),
      "# R\n\nStanding: mostly works\n"
    )

    File.write!(Path.join(root, "docs/zod-port/receipts/odd2.md"), "# R\n\nStanding: DONE\n")
    assert {:error, _} = Register.receipt_standing(root, "docs/zod-port/receipts/odd.md")
    assert {:error, why} = Register.receipt_standing(root, "docs/zod-port/receipts/odd2.md")
    assert why =~ "outside closed vocabulary"
    assert {:ok, "PASS"} = Register.receipt_standing(root, "docs/zod-port/receipts/ok.md")
    assert {:error, _} = Register.receipt_standing(root, "../escape.md")
  end

  test "the committed register on the live tree parses, lints clean and every receipt it cites exists" do
    repo = Path.expand("../../..", __DIR__)
    text = File.read!(Path.join(repo, "docs/KNOWN_DIVERGENCES.md"))
    assert Register.lint(Register.parse(text), repo) == []
  end
end
