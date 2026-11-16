defmodule AshShadcn.Ide.Source do
  @moduledoc """
  Read-only view of the real source files behind the browsable domains. Only files that are
  (a) listed in the tree, (b) under the playground `lib/` dir after symlink resolution, can be read.
  """
  @root Path.expand("../..", __DIR__)

  def root, do: @root

  @doc "Tree of domains -> source files (nested, JSON-able)."
  def tree(root \\ @root, domains \\ AshShadcn.domains()) do
    for domain <- domains do
      files =
        [domain | Ash.Domain.Info.resources(domain)]
        |> Enum.flat_map(fn mod ->
          case rel_path(mod, root) do
            {:ok, rel} -> [%{name: Path.basename(rel), path: rel, type: "file", module: inspect(mod)}]
            :error -> []
          end
        end)
        |> Enum.uniq_by(& &1.path)

      %{name: inspect(domain), type: "folder", children: files}
    end
  end

  def paths(root \\ @root, domains \\ AshShadcn.domains()) do
    root |> tree(domains) |> Enum.flat_map(& &1.children) |> Enum.map(& &1.path)
  end

  @doc "Read `path` iff allow-listed and its real location stays under `root`."
  def read(path, opts \\ []) do
    root = Keyword.get(opts, :root, @root)
    allowed = Keyword.get_lazy(opts, :allowed, fn -> paths(root) end)

    with true <- is_binary(path) and not String.contains?(path, <<0>>) or {:error, :forbidden},
         true <- path in allowed or {:error, :forbidden},
         full = Path.expand(path, root),
         true <- inside?(full, root) or {:error, :forbidden},
         {:ok, real} <- realpath(full),
         {:ok, real_root} <- realpath(root),
         true <- inside?(real, real_root) or {:error, :forbidden},
         {:ok, text} <- File.read(real) do
      {:ok, text}
    else
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, _} -> {:error, :not_found}
      _ -> {:error, :forbidden}
    end
  end

  defp rel_path(mod, root) do
    with src when is_list(src) <- mod.module_info(:compile)[:source],
         full = Path.expand(to_string(src)),
         true <- inside?(full, root) do
      {:ok, Path.relative_to(full, root)}
    else
      _ -> :error
    end
  end

  defp inside?(path, root), do: path == root or String.starts_with?(path, root <> "/")

  # Resolve every symlink component (bounded depth).
  defp realpath(path), do: resolve(Path.split(Path.expand(path)), "", 0)

  defp resolve(_, _, depth) when depth > 40, do: {:error, :eloop}
  defp resolve([], acc, _), do: {:ok, acc}
  defp resolve(["/" | rest], _acc, d), do: resolve(rest, "/", d)

  defp resolve([seg | rest], acc, d) do
    cur = Path.join(acc, seg)

    case File.read_link(cur) do
      {:ok, target} ->
        target = Path.expand(target, Path.dirname(cur))
        resolve(Path.split(target) ++ rest, "", d + 1)

      {:error, _} ->
        resolve(rest, cur, d)
    end
  end
end
