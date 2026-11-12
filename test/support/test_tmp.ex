defmodule AshSurface.TestTmp do
  @moduledoc """
  Temp-path helpers unique across OS processes (concurrent `mix test` VMs in one
  checkout) as well as within a VM: OS pid + unique_integer + monotonic time.
  """

  @doc "Unique, filesystem-safe suffix: `<pid>_<unique_integer>_<monotonic>_<os_time>`."
  def suffix do
    mono = abs(System.monotonic_time(:nanosecond))
    "#{System.pid()}_#{System.unique_integer([:positive])}_#{mono}_#{System.os_time(:nanosecond)}"
  end

  @doc """
  Creates a fresh unique dir under `System.tmp_dir!/0` (never reuses a pre-existing dir:
  `:eexist` retries with a new suffix) and removes it on test exit when called from the
  test process (otherwise `sweep/0` reclaims it after the suite).
  """
  def unique_dir(prefix, attempts \\ 5) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{suffix()}")

    case File.mkdir_p(Path.dirname(dir)) == :ok and File.mkdir(dir) do
      :ok ->
        try do
          ExUnit.Callbacks.on_exit(fn -> File.rm_rf(dir) end)
        rescue
          _ -> :ok
        end

        dir

      {:error, :eexist} when attempts > 0 ->
        unique_dir(prefix, attempts - 1)

      other ->
        raise "TestTmp.unique_dir failed for #{dir}: #{inspect(other)}"
    end
  end

  @doc "Makes a fixed path per-OS-process (`<path>-<pid>`); for module attributes."
  def scoped(path), do: "#{path}-#{System.pid()}"

  @doc """
  After-suite sweep: removes this OS process's leftovers -- `scoped/1` dirs under
  `_build/test` (`*-<pid>`) and tmp_dir entries carrying `suffix/0`'s `<pid>_` marker.
  """
  def sweep do
    pid = System.pid()
    build_test = Path.join(File.cwd!(), "_build/test")

    for root <- [System.tmp_dir!(), build_test],
        File.dir?(root),
        entry <- File.ls!(root),
        String.ends_with?(entry, "-" <> pid) or
          String.contains?(entry, "_#{pid}_") or String.contains?(entry, "-#{pid}_") do
      File.rm_rf(Path.join(root, entry))
    end

    :ok
  end
end
