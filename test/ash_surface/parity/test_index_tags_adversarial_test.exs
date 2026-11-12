defmodule AshSurface.Parity.TestIndexTagsAdversarialTest do
  @moduledoc """
  Lane CAF courts: tag/exclude handling of the parity gate against real temp files.
  Each case writes a real fixture tree (court file, test_helper.exs, mix.exs) and runs the
  real gate (`Report.evaluate/1`); tag-attachment semantics are checked against a real
  ExUnit run in a subprocess, never a model of ExUnit.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Parity.{ExcludeSpec, Report, TestIndex}

  @quote_text "no generated `.ts`, no `.d.ts`, no `tsc` build step"

  defp root! do
    root = Path.join(System.tmp_dir!(), "parity-caf-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(root, "test"))
    File.mkdir_p!(Path.join(root, "docs/zod-port/receipts"))
    File.mkdir_p!(Path.join(root, "parity"))
    on_exit(fn -> File.rm_rf!(root) end)
    File.write!(Path.join(root, "README.md"), "There is no TS. #{@quote_text}. End.\n")

    File.write!(
      Path.join(root, "docs/KNOWN_DIVERGENCES.md"),
      "# KD\n\n| id | surface | divergence | better_because | court | receipt | close condition |\n|--|--|--|--|--|--|--|\n"
    )

    File.write!(
      Path.join(root, "parity/capabilities.json"),
      Jason.encode!(%{
        "advisory" => %{},
        "capabilities" => [%{"id" => "a.one", "section" => "a", "source" => "x"}]
      })
    )

    root
  end

  # one court named "the court" over `court_body` (full file text); returns the gate result
  defp gate(root, court_body, opts \\ []) do
    File.write!(Path.join(root, "test/thing_test.exs"), court_body)
    if h = opts[:helper], do: File.write!(Path.join(root, "test/test_helper.exs"), h)
    if m = opts[:mix], do: File.write!(Path.join(root, "mix.exs"), m)

    File.write!(
      Path.join(root, "parity/court_map.json"),
      Jason.encode!(%{
        "entries" => %{
          "a.one" => %{
            "status" => "pass",
            "tests" => [%{"file" => "test/thing_test.exs", "test" => "the court"}]
          }
        }
      })
    )

    Report.evaluate(root: root)
  end

  defp court(tag_lines, mod_lines \\ "") do
    "defmodule T do\n#{mod_lines}\n#{tag_lines}\n  test \"the court\" do\n    assert 1 == 1\n  end\nend\n"
  end

  defp excluded?(r), do: Enum.any?(r.errors, &String.contains?(&1, "EXCLUDED"))
  defp unresolvable?(r), do: Enum.any?(r.errors, &String.contains?(&1, "UNRESOLVABLE-EXCLUDE"))
  defp green?(r), do: r.exit == 0 and r.counts.pass == 1

  describe "(a) test_helper.exs is read as AST" do
    test "a commented-out exclude is ignored" do
      root = root!()
      r = gate(root, court("  @tag :ghost"), helper: "# exclude: [:ghost]\nExUnit.start()\n")
      assert green?(r), inspect(r.errors)
      assert ExcludeSpec.read(root).exclude == []
    end

    test "~w(slow)a sigil excludes" do
      root = root!()
      r = gate(root, court("  @tag :slow"), helper: "ExUnit.start(exclude: ~w(slow)a)\n")
      assert excluded?(r)
      refute green?(r)
    end

    test "a variable bound to a literal resolves; an unbound one does not" do
      root = root!()
      r = gate(root, court("  @tag :slow"), helper: "ex = [:slow]\nExUnit.start(exclude: ex)\n")
      assert excluded?(r)
      r = gate(root, court("  @tag :slow"), helper: "ExUnit.start(exclude: ex)\n")
      assert unresolvable?(r)
    end

    test "Application.get_env and module-attribute excludes are UNRESOLVABLE, never a pass" do
      root = root!()

      r =
        gate(root, court(""),
          helper: "ExUnit.start(exclude: Application.get_env(:x, :ex, [:slow]))\n"
        )

      assert unresolvable?(r)
      refute r.exit == 0

      r =
        gate(root, court(""),
          helper: "defmodule H do\n  @ex [:slow]\n  def go, do: ExUnit.start(exclude: @ex)\nend\n"
        )

      assert unresolvable?(r)
      refute r.exit == 0
    end
  end

  describe "(b) include overrides exclude; value-matching exclusions" do
    test "include: overrides exclude for the same tag" do
      root = root!()

      r =
        gate(root, court("  @tag :slow"),
          helper: "ExUnit.configure(exclude: [:slow], include: [:slow])\n"
        )

      assert green?(r), inspect(r.errors)
    end

    test "exclude: [slow: false] matches tag VALUES, not names" do
      root = root!()
      h = "ExUnit.start(exclude: [slow: false])\n"
      assert green?(gate(root, court("  @tag :slow"), helper: h))
      assert excluded?(gate(root, court("  @tag slow: false"), helper: h))
    end

    test "exclude: [slow: true] does not hit @tag slow: \"x\" and does hit @tag :slow" do
      root = root!()
      h = "ExUnit.start(exclude: [slow: true])\n"
      assert green?(gate(root, court("  @tag slow: \"x\""), helper: h))
      assert excluded?(gate(root, court("  @tag :slow"), helper: h))
    end

    test "exclude: [slow: \"x\"] hits the matching string value only" do
      root = root!()
      h = "ExUnit.start(exclude: [slow: \"x\"])\n"
      assert excluded?(gate(root, court("  @tag slow: \"x\""), helper: h))
      assert green?(gate(root, court("  @tag slow: \"y\""), helper: h))
    end
  end

  describe "(c) mix.exs aliases carry --only/--exclude/--include" do
    defp mix_with(alias_body),
      do:
        "defmodule M.MixProject do\n  use Mix.Project\n  def project, do: [app: :m, aliases: aliases()]\n  defp aliases, do: [#{alias_body}]\nend\n"

    test "string alias: --exclude slow" do
      root = root!()
      m = mix_with(~s(test: ["test --exclude slow"]))
      assert excluded?(gate(root, court("  @tag :slow"), mix: m))
      assert green?(gate(root, court("  @tag :fast"), mix: m))
      assert ExcludeSpec.read(root).exclude == [{"slow", true}]
    end

    test "list alias with separate tokens and --include overriding" do
      root = root!()
      m = mix_with(~s(test: ["test", "--exclude", "slow", "--include", "slow"]))
      assert green?(gate(root, court("  @tag :slow"), mix: m))
      m = mix_with(~s(test: ["test", "--exclude", "slow:x"]))
      assert excluded?(gate(root, court("  @tag slow: \"x\""), mix: m))
      assert green?(gate(root, court("  @tag slow: \"y\""), mix: m))
    end

    test "--only integration excludes every court without the tag" do
      root = root!()
      m = mix_with(~s(ci: ["test --only integration"]))
      assert excluded?(gate(root, court(""), mix: m))
      assert green?(gate(root, court("  @tag :integration"), mix: m))
    end
  end

  describe "(d) module and describe scoping" do
    test "nested defmodule: moduletag does not leak in either direction" do
      src = """
      defmodule Outer do
        @moduletag :outer
        defmodule Inner do
          @moduletag :inner
          test "inner t" do
            assert true
          end
        end
        test "outer t" do
          assert true
        end
      end
      """

      {:ok, idx} = TestIndex.analyze("x_test.exs", src)
      by = Map.new(idx.tests, &{&1.title, &1.tags})
      assert by["inner t"] == ["inner"]
      assert by["outer t"] == ["outer"]
    end

    test "nested module skip does not skip the outer module (and vice versa)" do
      src = """
      defmodule Outer do
        defmodule Inner do
          @moduletag :skip
          test "inner t" do
            assert true
          end
        end
        test "outer t" do
          assert true
        end
      end
      """

      {:ok, idx} = TestIndex.analyze("x_test.exs", src)
      by = Map.new(idx.tests, &{&1.title, &1.skipped})
      assert by == %{"inner t" => true, "outer t" => false}
      refute idx.module_skip
    end

    test "@tag before describe binds to the first test only, matching a real ExUnit run" do
      src = """
      defmodule Real do
        use ExUnit.Case
        @tag :pre
        describe "d" do
          test "t1", ctx do
            IO.puts("RES t1 " <> inspect(Map.get(ctx, :pre)))
          end
          test "t2", ctx do
            IO.puts("RES t2 " <> inspect(Map.get(ctx, :pre)))
          end
        end
        test "after", ctx do
          IO.puts("RES after " <> inspect(Map.get(ctx, :pre)))
        end
      end
      """

      dir = Path.join(System.tmp_dir!(), "caf-real-#{AshSurface.TestTmp.suffix()}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      script = Path.join(dir, "real_test.exs")
      File.write!(script, "ExUnit.start(autorun: false)\n" <> src <> "\nExUnit.run()\n")
      {out, 0} = System.cmd(System.find_executable("elixir"), [script], stderr_to_stdout: true)
      assert out =~ "RES t1 true"
      assert out =~ "RES t2 nil"
      assert out =~ "RES after nil"

      {:ok, idx} = TestIndex.analyze("x_test.exs", src)
      by = Map.new(idx.tests, &{&1.title, "pre" in &1.tags})
      assert by == %{"t1" => true, "t2" => false, "after" => false}
    end

    test "@tag :slow before describe: only the first describe test is excluded" do
      root = root!()

      src =
        "defmodule T do\n  @tag :slow\n  describe \"d\" do\n    test \"first\" do\n      assert true\n    end\n    test \"the court\" do\n      assert true\n    end\n  end\nend\n"

      assert green?(gate(root, src, helper: "ExUnit.start(exclude: [:slow])\n"))
    end
  end

  describe "(e) generated tests are reported, not mangled" do
    @generated """
    defmodule G do
      defmacro mk(name) do
        quote do
          test unquote(name) do
            assert true
          end
        end
      end

      for n <- 1..2 do
        test "gen \#{n}" do
          assert n > 0
        end
      end

      mk("macro one")

      test "static one" do
        assert true
      end
    end
    """

    test "index: dynamic entries typed, no mangled titles" do
      {:ok, idx} = TestIndex.analyze("g_test.exs", @generated)
      assert Enum.map(idx.tests, & &1.title) == ["static one"]
      assert length(idx.dynamic) == 2
      assert Enum.all?(idx.dynamic, &(&1.reason == "unindexable-dynamic-test"))
      refute Enum.any?(idx.tests, &String.contains?(&1.title, "\0"))
    end

    test "gate: a court that relies on a generated test is a typed hard problem" do
      root = root!()
      r = gate(root, String.replace(@generated, "static one", "other"))
      refute r.exit == 0
      assert Enum.any?(r.errors, &String.contains?(&1, "UNINDEXABLE-DYNAMIC-TEST"))
    end

    test "gate: a court on a static test in a file with generated tests still passes" do
      root = root!()
      r = gate(root, String.replace(@generated, "static one", "the court"))
      assert green?(r), inspect(r.errors)
    end
  end
end
