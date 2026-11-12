defmodule AshSurface.ShimCourtSelfcheckTest do
  @moduledoc """
  Real-file, no-mock proof that the shim-court restore-detection is non-vacuous and that no
  shim is ever left in the live tree (scripts/shim_court/lib.sh).
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../scripts/shim_court/lib.sh", __DIR__)
  @root Path.expand("../..", __DIR__)

  test "lib.sh self-check detects a corrupted restore on a real temp copy" do
    {out, code} =
      System.cmd("bash", ["-c", "source #{@lib}; shim_court_self_check"], stderr_to_stdout: true)

    assert code == 0, out
    assert out =~ "sha256 restore-detection verified"
  end

  test "a skip is loud: exit 3 with [SKIP] and a reason" do
    {out, code} =
      System.cmd("bash", ["-c", "source #{@lib}; shim_court_skip 'reason-x'"],
        stderr_to_stdout: true
      )

    assert code == 3
    assert out =~ "[SKIP]"
    assert out =~ "reason-x"
  end

  test "with_shim fails closed when the shim does not flip the AFTER witness" do
    dir = Path.join(System.tmp_dir!(), "shimct_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    f = Path.join(dir, "subject.txt")
    File.write!(f, "original\n")

    script = """
    source #{@lib}
    apply_shim() { printf 'changed SHIM-COURT\\n' >> "$SHIM_FILE"; }
    with_shim #{f} 'true' 'false'
    """

    {out, code} = System.cmd("bash", ["-c", script], stderr_to_stdout: true)
    assert code == 1
    assert out =~ "[FAIL:AFTER]"
    assert File.read!(f) == "original\n"
    File.rm_rf!(dir)
  end

  test "no SHIM-COURT marker survives in lib/ or priv/ of the live tree" do
    for dir <- ["lib", "priv"],
        path <- Path.wildcard(Path.join([@root, dir, "**", "*"])),
        File.regular?(path) do
      refute File.read!(path) =~ "SHIM-COURT", "shim left in #{path}"
    end
  end
end
