defmodule AshSurface.ParityTests.SkipsAdversarialTest do
  @moduledoc """
  TEST-PORT gate semantics on real temp files: a ported/adapted test needs zero skips of any
  form, including a globally excluded tag. Tags/excludes come from the shared
  ExcludeSpec/TestIndex kernel (no second reader).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Parity.ExcludeSpec
  alias AshSurface.ParityTests.Skips

  defp root!(helper, mix \\ nil) do
    dir = Path.join(System.tmp_dir!(), "cah-#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(Path.join(dir, "test"))
    File.write!(Path.join(dir, "test/test_helper.exs"), helper)
    if mix, do: File.write!(Path.join(dir, "mix.exs"), mix)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp scan!(dir, body) do
    path = Path.join(dir, "test/x_test.exs")
    File.write!(path, body)
    {:ok, r} = Skips.scan(path, ExcludeSpec.read(dir))
    r
  end

  defp mod(inner), do: "defmodule M do\n  use ExUnit.Case\n#{inner}\nend\n"
  defp t(tag), do: mod("  @tag #{tag}\n  test \"a\" do\n    assert true\n  end")

  test "Application.get_env exclude is unresolvable, never a pass" do
    d = root!("ExUnit.start(exclude: Application.get_env(:x, :ex, [:slow]))\n")
    assert %{skips: [s | _]} = scan!(d, t(":other"))
    assert s =~ "UNRESOLVABLE-EXCLUDE"
  end

  test "sigil, keyword, and variable excludes resolve" do
    d = root!("ex = ~w(slow)a\nExUnit.start(exclude: ex)\n")
    assert %{skips: [_]} = scan!(d, t(":slow"))
    d = root!("ExUnit.start(exclude: [slow: true])\n")
    assert %{skips: [_]} = scan!(d, t(":slow"))
    assert %{skips: []} = scan!(d, t("slow: false"))
  end

  test "commented exclude does not count" do
    d = root!("# ExUnit.start(exclude: [:slow])\nExUnit.start()\n")
    assert %{skips: []} = scan!(d, t(":slow"))
  end

  test "include overrides exclude" do
    d = root!("ExUnit.start(exclude: [:slow], include: [:slow])\n")
    assert %{skips: []} = scan!(d, t(":slow"))
  end

  test "nested module tags do not leak" do
    d = root!("ExUnit.start(exclude: [:nested])\n")

    body =
      mod(
        "  test \"outer\" do\n    assert true\n  end\n  defmodule Inner do\n    use ExUnit.Case\n    @moduletag :nested\n    test \"in\" do\n      assert true\n    end\n  end"
      )

    assert %{skips: [s]} = scan!(d, body)
    assert s =~ "\"in\""
  end

  test "@tag before describe binds to first test only" do
    d = root!("ExUnit.start(exclude: [:slow])\n")

    body =
      mod(
        "  @tag :slow\n  describe \"d\" do\n    test \"first\" do\n      assert true\n    end\n    test \"second\" do\n      assert true\n    end\n  end"
      )

    assert %{skips: [s]} = scan!(d, body)
    assert s =~ "first"
  end

  test "for-generated tests count as runnable; a tag still skips them" do
    body = fn tag ->
      mod(
        "  for n <- 1..2 do\n    #{tag}\n    test \"g\#{n}\" do\n      assert true\n    end\n  end"
      )
    end

    d = root!("ExUnit.start(exclude: [:slow])\n")
    assert %{skips: [], tests: 1} = scan!(d, body.(""))
    assert %{skips: [s]} = scan!(d, body.("@tag :slow"))
    assert s =~ "excluded"
    assert %{skips: [_]} = scan!(d, body.("@tag skip: \"x\""))
  end

  test "macro-generated tests: same rule" do
    d = root!("ExUnit.start(exclude: [:slow])\n")

    body = fn tag ->
      mod(
        "  defmacro mk(t) do\n    quote do\n      test unquote(t) do\n        assert true\n      end\n    end\n  end\n  #{tag}\n  mk(\"m\")"
      )
    end

    assert %{skips: []} = scan!(d, body.(""))
    assert %{skips: [_]} = scan!(d, body.("@tag :slow"))
  end

  test "mix.exs alias --exclude / --only flags" do
    mixexs =
      "defmodule X.MixProject do\n  def project, do: [aliases: [test: \"test --exclude slow\"]]\nend\n"

    d = root!("ExUnit.start()\n", mixexs)
    assert %{skips: [_]} = scan!(d, t(":slow"))

    only =
      "defmodule X.MixProject do\n  def project, do: [aliases: [t: [\"test\", \"--only\", \"fast\"]]]\nend\n"

    d = root!("ExUnit.start()\n", only)
    assert %{skips: [_]} = scan!(d, t(":slow"))
    assert %{skips: []} = scan!(d, t(":fast"))
  end

  test "legacy list form still excludes" do
    d = root!("ExUnit.start()\n")
    path = Path.join(d, "test/y_test.exs")
    File.write!(path, t(":slow"))
    assert {:ok, %{skips: [_]}} = Skips.scan(path, [:slow])
  end
end
