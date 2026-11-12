defmodule AshSurface.ParityTests.SkipsTest do
  @moduledoc """
  The skip detector must see every skip form (AST based) and must not flag prose
  mentioning the word skip.
  """
  use ExUnit.Case, async: true

  alias AshSurface.ParityTests.{Inventory, Skips}

  defp scan!(body, name \\ "x_test.exs", excluded \\ []) do
    path = Path.join(System.tmp_dir!(), "skips-#{AshSurface.TestTmp.suffix()}-#{name}")
    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    {:ok, r} = Skips.scan(path, excluded)
    r
  end

  @wrap "defmodule M do\n  use ExUnit.Case\n  %s\nend\n"
  defp wrap(inner), do: String.replace(@wrap, "%s", inner)

  test "every skip form is detected" do
    forms = [
      ~s|@tag skip: "x"\n  test "a" do\n  end|,
      ~s|@tag skip:\n    "multi " <>\n      "line"\n  test "a" do\n  end|,
      ~s|@tag :skip\n  test "a" do\n  end|,
      ~s|@tag timeout: 10, skip: "k"\n  test "a" do\n  end|,
      ~s|@tag [:integration, skip: "k"]\n  test "a" do\n  end|,
      ~s|@moduletag :skip\n  test "a" do\n  end|,
      ~s|@moduletag skip: "m"\n  test "a" do\n  end|,
      ~s|describe "d" do\n    @describetag :skip\n    test "a" do\n    end\n  end|,
      ~s|test "pending"|,
      ~s|for n <- [1] do\n    @tag skip: "n\#{n}"\n    test "g\#{n}" do\n    end\n  end|
    ]

    for f <- forms do
      assert %{skips: [_ | _]} = scan!(wrap(f)), "undetected skip form: #{f}"
    end
  end

  test "non-skips are not flagged" do
    forms = [
      ~s|@tag skip: false\n  test "a" do\n  end|,
      ~s|@tag :integration\n  test "skip the word in a title" do\n  end|,
      ~s|# skip: commented\n  test "a" do\n    assert "skip" == "skip"\n  end|
    ]

    for f <- forms do
      assert %{skips: [], tests: 1} = scan!(wrap(f)), "false positive: #{f}"
    end
  end

  test "tags excluded in the test file or test_helper count as skips" do
    assert %{skips: [_]} =
             scan!(wrap(~s|@tag :slow\n  test "a" do\n  end|), "x_test.exs", [:slow])

    body =
      "ExUnit.configure(exclude: [:flaky])\ndefmodule M do\n  use ExUnit.Case\n  @tag :flaky\n  test \"a\" do\n  end\nend\n"

    assert %{skips: [_]} = scan!(body)

    helper = Path.join(System.tmp_dir!(), "helper-#{AshSurface.TestTmp.suffix()}.exs")
    File.write!(helper, "ExUnit.start(exclude: [:wip, integration: true])\n")
    on_exit(fn -> File.rm(helper) end)
    assert Enum.sort(Skips.excluded_tags(helper)) == [:integration, :wip]
  end

  test "counts tests and describes" do
    body =
      wrap(~s|describe "d" do\n    test "a" do\n    end\n    test "b", ctx do\n    end\n  end|)

    assert %{tests: 2, describes: 1, skips: []} = scan!(body)
  end

  test "node test files: .skip(, todo, options and counts" do
    assert %{skips: [_ | _]} =
             scan!("import test from 'node:test';\ntest.skip('x', () => {});\n", "a.test.mjs")

    assert %{skips: [_ | _]} = scan!("test('x', { skip: true }, () => {});\n", "a.test.mjs")
    assert %{skips: [_ | _]} = scan!("describe.skip('x', () => {});\n", "a.test.mjs")

    assert %{skips: [], tests: 1, describes: 1} =
             scan!("describe('d', () => {\n  test('x', () => {});\n});\n", "a.test.mjs")
  end

  test "an unparseable file is an error, never a clean pass" do
    path = Path.join(System.tmp_dir!(), "bad-#{AshSurface.TestTmp.suffix()}_test.exs")
    File.write!(path, "defmodule do do do")
    on_exit(fn -> File.rm(path) end)
    assert {:error, "unparseable" <> _} = Skips.scan(path)
  end

  test "inventory titles come from the AST and the TS line scan" do
    {:ok, ex} =
      Inventory.analyze(
        "test/a_test.exs",
        ~s|defmodule A do\n  describe "d1" do\n    test "t1" do\n    end\n    test "t\#{1}" do\n    end\n  end\n  property "p" do\n  end\nend\n|
      )

    assert ex.describes == ["d1"]
    assert ex.test_count == 3
    assert ex.tests == ["t1", ~s|"t\#{1}"|, "p"]

    {:ok, ts} =
      Inventory.analyze(
        "test/ts/a.ts",
        "// Test 1: basic get\nexport function testX() {}\nrunTest(\"testY\", () => 1);\n// @ts-expect-error nope\nx\n"
      )

    assert ts.tests == ["basic get", "testX", "testY"]
    assert ts.expect_errors == 1
  end
end
