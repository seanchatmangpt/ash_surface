defmodule AshSurface.Parity.GateHardeningTest do
  @moduledoc """
  F1 hardening courts. Each class the R11 review found in the smalt ancestor
  (`sdk_coverage.py`) gets a shim the gate must REFUSE; a gate that accepts the shim
  fails as VACUOUS GATE. Every court also keeps a green baseline so a red baseline
  cannot masquerade as a refusal.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Parity.{CourtMap, Register, Report}

  @hdr7 "| id | surface | divergence | better_because | court | receipt | close condition |\n|--|--|--|--|--|--|--|\n"
  @good_receipt "# R\n\nStanding: PASS\n\nPASS test/thing_test.exs: 3 tests, 0 failures\n"

  defp root! do
    root = Path.join(System.tmp_dir!(), "parity-harden-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(root, "test"))
    File.mkdir_p!(Path.join(root, "docs/zod-port/receipts"))
    File.mkdir_p!(Path.join(root, "parity"))
    on_exit(fn -> File.rm_rf!(root) end)
    File.write!(Path.join(root, "README.md"), "readme\n")

    File.write!(
      Path.join(root, "test/thing_test.exs"),
      "defmodule T do\n  test \"does the thing\" do\n    assert true\n  end\nend\n"
    )

    File.write!(Path.join(root, "docs/zod-port/receipts/ok.md"), @good_receipt)
    root
  end

  defp fixture!(root, ids, entries, kd_text) do
    caps = for id <- ids, do: %{"id" => id, "section" => "a", "source" => "x"}

    File.write!(
      Path.join(root, "parity/capabilities.json"),
      Jason.encode!(%{"advisory" => %{}, "capabilities" => caps})
    )

    File.write!(Path.join(root, "parity/court_map.json"), Jason.encode!(%{"entries" => entries}))
    File.write!(Path.join(root, "docs/KNOWN_DIVERGENCES.md"), "# KD\n\n" <> kd_text)
    root
  end

  defp div_map(id \\ "a.one"), do: %{id => %{"status" => "divergence", "kd" => "KD-01"}}

  defp kd_row(id \\ "KD-01", receipt \\ "docs/zod-port/receipts/ok.md"),
    do: "| #{id} | s | d | better | test/thing_test.exs | #{receipt} | c |\n"

  defp pass_map(entry), do: %{"a.one" => %{"status" => "pass", "tests" => [entry]}}

  defp refuse!(r, label) do
    if r.exit == 0, do: flunk("VACUOUS GATE: #{label} accepted (exit 0): #{inspect(r.counts)}")
    r
  end

  describe "1. register parser is header-driven" do
    test "7-column, reordered, escaped-pipe and namespaced-id rows all parse" do
      reordered =
        "| receipt | id | court | close condition | better_because | divergence | surface |\n" <>
          "|-|-|-|-|-|-|-|\n" <>
          "| r.md | KD-KIN-03 | c.exs | cc | better \\| really | dv | sf |\n" <>
          "| r2.md | KD-SQ-12 | c2.exs | cc2 | b2 | dv2 | sf2 |\n"

      assert [a, b] = Register.parse(reordered)
      assert %{id: "KD-KIN-03", receipt: "r.md", court: "c.exs", better: "better | really"} = a
      assert %{id: "KD-SQ-12", surface: "sf2", close: "cc2"} = b

      seven = @hdr7 <> "| KD-SIGV4-01 | s | d | b | c.exs | r.md | cl |\n"

      assert [%{id: "KD-SIGV4-01", better: "b", court: "c.exs", receipt: "r.md", close: "cl"}] =
               Register.parse(seven)
    end

    test "gate closes a divergence from a reordered register; shim blanking receipt is refused" do
      root = root!()

      reordered =
        "| receipt | id | court | surface | divergence | close condition | better_because |\n|-|-|-|-|-|-|-|\n" <>
          "| docs/zod-port/receipts/ok.md | KD-01 | test/thing_test.exs | s | d | c | better |\n"

      fixture!(root, ["a.one"], div_map(), reordered)
      assert %{exit: 0, counts: %{divergence: 1}} = Report.evaluate(root: root)

      File.write!(
        Path.join(root, "docs/KNOWN_DIVERGENCES.md"),
        "# KD\n\n" <> String.replace(reordered, "docs/zod-port/receipts/ok.md", "")
      )

      r = refuse!(Report.evaluate(root: root), "reordered row with blank receipt")
      assert r.missing == ["a.one"] or r.errors != []
    end

    test "KD rows with no header are refused" do
      root = root!()
      fixture!(root, ["a.one"], div_map(), kd_row())
      r = refuse!(Report.evaluate(root: root), "register without header")
      assert Enum.any?(r.errors, &(&1 =~ "header"))
    end
  end

  describe "2/3. receipt evidence law" do
    setup do
      root = root!()
      fixture!(root, ["a.one"], div_map(), @hdr7 <> kd_row())
      {:ok, root: root, rec: Path.join(root, "docs/zod-port/receipts/ok.md")}
    end

    test "baseline closes", %{root: root} do
      assert %{exit: 0, counts: %{divergence: 1}} = Report.evaluate(root: root)
    end

    test "Standing PASS with zero PASS evidence lines does not close", %{root: root, rec: rec} do
      File.write!(rec, "# R\n\nStanding: PASS\n\ntest/thing_test.exs ran\n")
      r = refuse!(Report.evaluate(root: root), "ALIVE/PASS standing, no PASS lines")
      assert r.missing == ["a.one"]
      assert Report.render(r) =~ "zero PASS evidence"
    end

    test "receipt not naming the court file does not close", %{root: root, rec: rec} do
      File.write!(rec, "# R\n\nStanding: PASS\n\nPASS some other file\n")
      r = refuse!(Report.evaluate(root: root), "receipt without court reference")
      assert Report.render(r) =~ "does not name court file"
    end

    test "a FAIL / SKIP / BLOCKED token in the receipt cannot close the row", %{
      root: root,
      rec: rec
    } do
      for tok <- ~w(FAIL SKIP BLOCKED) do
        File.write!(rec, @good_receipt <> "\n#{tok} test/other_test.exs\n")
        r = refuse!(Report.evaluate(root: root), "receipt with #{tok}")
        assert r.missing == ["a.one"]
        assert Report.render(r) =~ "FAIL/SKIP/BLOCKED"
      end
    end
  end

  describe "4. test tokens must be code, not comments/strings; skipped tests do not count" do
    setup do
      {:ok, root: root!()}
    end

    defp with_body(root, body, entry) do
      File.write!(Path.join(root, "test/thing_test.exs"), body)
      fixture!(root, ["a.one"], pass_map(entry), @hdr7)
      Report.evaluate(root: root)
    end

    test "baseline: contains token in real code counts", %{root: root} do
      e = %{"file" => "test/thing_test.exs", "contains" => "widget_fn"}

      assert %{exit: 0} =
               with_body(
                 root,
                 "defmodule T do\n  test \"x thing\" do\n    assert widget_fn()\n  end\nend\n",
                 e
               )
    end

    test "comment-only and string-only contains tokens are refused", %{root: root} do
      e = %{"file" => "test/thing_test.exs", "contains" => "widget_fn"}

      r =
        refuse!(
          with_body(
            root,
            "defmodule T do\n  # widget_fn here\n  test \"x thing\" do\n  end\nend\n",
            e
          ),
          "comment-only token"
        )

      assert r.counts.broken + r.counts.missing == 1

      r2 =
        refuse!(
          with_body(
            root,
            "defmodule T do\n  @n \"widget_fn\"\n  test \"x thing\" do\n  end\nend\n",
            e
          ),
          "string-only token"
        )

      assert Report.render(r2) =~ "no test assertion or title contains"
    end

    test "a test name that appears only in a comment is refused", %{root: root} do
      e = %{"file" => "test/thing_test.exs", "test" => "does the thing"}
      body = "defmodule T do\n  # test \"does the thing\"\n  test \"other\" do\n  end\nend\n"
      refuse!(with_body(root, body, e), "title in comment only")
    end

    test "skip tags (@tag :skip, @tag skip:, @moduletag, describe-level, inline) do not pass", %{
      root: root
    } do
      e = %{"file" => "test/thing_test.exs", "test" => "does the thing"}

      green = "defmodule T do\n  test \"does the thing\" do\n    assert true\n  end\nend\n"
      assert %{exit: 0} = with_body(root, green, e)

      shims = [
        "defmodule T do\n  @tag :skip\n  test \"does the thing\" do\n    assert true\n  end\nend\n",
        "defmodule T do\n  @tag skip: \"later\"\n  test \"does the thing\" do\n    assert true\n  end\nend\n",
        "defmodule T do\n  @moduletag :skip\n  test \"does the thing\" do\n    assert true\n  end\nend\n",
        "defmodule T do\n  @tag :skip\n  describe \"grp\" do\n    test \"does the thing\" do\n    end\n  end\nend\n",
        "defmodule T do\n  test \"does the thing\", skip: true do\n  end\nend\n"
      ]

      for body <- shims do
        r = refuse!(with_body(root, body, e), "skipped court: #{inspect(body)}")
        assert r.skipped == ["a.one"]
        assert Report.render(r) =~ "SKIPPED a.one"
        assert Report.render(r) =~ "SKIPPED-TEST coverage cells: 1"
      end
    end

    test "--no-strict-skips still counts the skip but does not fail on it", %{root: root} do
      e = %{"file" => "test/thing_test.exs", "test" => "does the thing"}

      File.write!(
        Path.join(root, "test/thing_test.exs"),
        "defmodule T do\n  @tag :skip\n  test \"does the thing\" do\n    assert true\n  end\nend\n"
      )

      fixture!(root, ["a.one"], pass_map(e), @hdr7)
      r = Report.evaluate(root: root, strict_skips: false)
      assert r.exit == 0
      assert r.skipped == ["a.one"]
    end
  end

  describe "5. generic tokens are vacuous" do
    setup do
      {:ok, root: root!()}
    end

    test "token shorter than 4 characters is refused, id reported", %{root: root} do
      File.write!(
        Path.join(root, "test/thing_test.exs"),
        "defmodule T do\n  test \"x\" do\n    assert max()\n  end\nend\n"
      )

      fixture!(
        root,
        ["a.one"],
        pass_map(%{"file" => "test/thing_test.exs", "contains" => "max"}),
        @hdr7
      )

      r = refuse!(Report.evaluate(root: root), "3-char token")
      assert r.generic == ["a.one"]
      assert Report.render(r) =~ "GENERIC a.one"
    end

    test "{leaf} token matching more than 25 test files is refused", %{root: root} do
      for i <- 1..26,
          do:
            File.write!(
              Path.join(root, "test/f#{i}_test.exs"),
              "defmodule F#{i} do\n  test \"t\" do\n    assert everywhere()\n  end\nend\n"
            )

      e = %{"file" => "test/f1_test.exs", "contains" => "everywhere"}
      fixture!(root, ["a.one"], pass_map(e), @hdr7)
      r = refuse!(Report.evaluate(root: root), "token in 26 files")
      assert r.generic == ["a.one"]

      File.rm!(Path.join(root, "test/f26_test.exs"))
      File.rm!(Path.join(root, "test/f25_test.exs"))
      assert %{exit: 0} = Report.evaluate(root: root)
      assert CourtMap.fences() == %{min_token: 4, max_files: 25}
    end
  end

  describe "6/7. aggregate behavior and summary" do
    test "empty inventory, unreadable register and malformed map all exit 1" do
      root = root!()

      fixture!(
        root,
        ["a.one"],
        pass_map(%{"file" => "test/thing_test.exs", "test" => "does the thing"}),
        @hdr7
      )

      assert %{exit: 0} = Report.evaluate(root: root)

      fixture!(root, [], %{}, @hdr7)
      assert %{exit: 1} = refuse!(Report.evaluate(root: root), "empty inventory")

      fixture!(root, ["a.one"], %{}, @hdr7)
      File.rm!(Path.join(root, "docs/KNOWN_DIVERGENCES.md"))
      assert %{exit: 1, fatal: _} = refuse!(Report.evaluate(root: root), "unreadable register")

      fixture!(root, ["a.one"], %{}, @hdr7)
      File.write!(Path.join(root, "parity/court_map.json"), "{not json")
      assert %{exit: 1, fatal: _} = refuse!(Report.evaluate(root: root), "malformed map")
    end

    test "summary line has the stable CI format" do
      root = root!()

      fixture!(
        root,
        ["a.one", "a.two"],
        pass_map(%{"file" => "test/thing_test.exs", "test" => "does the thing"}),
        @hdr7
      )

      r = Report.evaluate(root: root)

      assert Report.summary(r) ==
               "parity: total=2 pass=1 divergence=0 non_goal=0 broken=0 missing=1"

      assert Report.summary(Report.evaluate(root: Path.join(root, "nope"))) =~
               ~r/^parity: total=\d+ pass=\d+ divergence=\d+ non_goal=\d+ broken=[1-9]\d* missing=\d+$/
    end
  end

  describe "skeptic-audit holes" do
    setup do
      {:ok, root: root!()}
    end

    defp run(root, body, entry, file \\ "test/thing_test.exs") do
      File.mkdir_p!(Path.dirname(Path.join(root, file)))
      File.write!(Path.join(root, file), body)
      fixture!(root, ["a.one"], pass_map(Map.put(entry, "file", file)), @hdr7)
      Report.evaluate(root: root)
    end

    @title %{"test" => "does the thing"}

    test "multi-line and list-form skip tags do not pass", %{root: root} do
      shims = [
        "defmodule T do\n  @tag skip:\n         \"long reason\"\n  test \"does the thing\" do\n    assert true\n  end\nend\n",
        "defmodule T do\n  @moduletag [:skip]\n  test \"does the thing\" do\n    assert true\n  end\nend\n",
        "defmodule T do\n  @tag [skip: \"x\"]\n  test \"does the thing\" do\n    assert true\n  end\nend\n",
        "defmodule T do\n  describe \"g\" do\n    @describetag :skip\n    test \"does the thing\" do\n      assert true\n    end\n  end\nend\n"
      ]

      for b <- shims do
        r = refuse!(run(root, b, @title), "skip form #{inspect(b)}")
        assert r.skipped == ["a.one"], inspect(b)
      end
    end

    test "a describe with no test inside is not a court", %{root: root} do
      b = "defmodule T do\n  describe \"does the thing\" do\n    @x 1\n  end\nend\n"
      refuse!(run(root, b, @title), "describe-only match")
    end

    test "a test with no assertion is vacuous", %{root: root} do
      b = "defmodule T do\n  test \"does the thing\" do\n    IO.puts(\"hi\")\n  end\nend\n"
      r = refuse!(run(root, b, @title), "assert-free test")
      assert Report.render(r) =~ "VACUOUS test"
    end

    test "a test behind a Code.ensure_loaded? guard is refused", %{root: root} do
      b =
        "defmodule T do\n  test \"does the thing\" do\n    if Code.ensure_loaded?(Foo) do\n      assert Foo.x()\n    end\n  end\nend\n"

      r = refuse!(run(root, b, @title), "compiled-out guard")
      assert Report.render(r) =~ "GUARDED"
    end

    test "a lib file is not a court file", %{root: root} do
      b = "defmodule L do\n  def k, do: \"widget_fn\"\nend\n"
      r = refuse!(run(root, b, %{"contains" => "widget_fn"}, "lib/l.ex"), "lib pointer")
      assert Report.render(r) =~ "not a court file"
    end

    test "a token found only in a fixture list, not an assertion, is refused", %{root: root} do
      b =
        "defmodule T do\n  @keys [:widget_key]\n  test \"t\" do\n    assert length(@keys) == 1\n  end\nend\n"

      refuse!(run(root, b, %{"contains" => "widget_key"}), "token in data list")
    end

    test ".mjs court unreachable from npm or mix is refused; reachable via package.json passes",
         %{root: root} do
      js =
        "describe('g', () => {\n  test('does the thing', () => {\n    expect(1).toBe(1)\n  })\n})\n"

      f = "test/js/x.test.mjs"
      r = refuse!(run(root, js, @title, f), "unreachable mjs")
      assert Report.render(r) =~ "JS court unreachable"

      File.write!(
        Path.join(root, "package.json"),
        ~s({"scripts":{"test":"node --test test/js/*.test.mjs"}})
      )

      assert %{exit: 0} = Report.evaluate(root: root)

      js_skip = String.replace(js, "test('does", "test.skip('does")
      assert %{skipped: ["a.one"]} = refuse!(run(root, js_skip, @title, f), "skipped mjs")

      js_import = "import { widgetFn } from './w.mjs'\ntest('t', () => { expect(1).toBe(1) })\n"
      refuse!(run(root, js_import, %{"contains" => "widgetFn"}, f), "token only on import line")
    end

    test "one any_of alternative is not an alternative", %{root: root} do
      File.write!(
        Path.join(root, "test/thing_test.exs"),
        "defmodule T do\n  test \"does the thing\" do\n    assert true\n  end\nend\n"
      )

      e = %{
        "status" => "pass",
        "any_of" => [%{"file" => "test/thing_test.exs", "test" => "does the thing"}]
      }

      fixture!(root, ["a.one"], %{"a.one" => e}, @hdr7)
      refuse!(Report.evaluate(root: root), "any_of with one reference")
    end

    test "one test line closing more rows than the cap closes none", %{root: root} do
      File.write!(
        Path.join(root, "test/thing_test.exs"),
        "defmodule T do\n  test \"does the thing\" do\n    assert true\n  end\nend\n"
      )

      ids = ~w(a.one a.two a.three a.four)

      e = %{
        "status" => "pass",
        "tests" => [%{"file" => "test/thing_test.exs", "test" => "does the thing"}]
      }

      fixture!(root, ids, Map.new(ids, &{&1, e}), @hdr7)
      r = refuse!(Report.evaluate(root: root), "4 rows on one test")
      assert r.counts.broken == 4
      assert Report.render(r) =~ "SHARED-TEST"

      fixture!(root, ids, Map.new(ids, &{&1, Map.put(e, "shared", true)}), @hdr7)
      assert %{exit: 0} = Report.evaluate(root: root)
      assert Report.max_rows_per_ref() == 3
    end
  end
end
