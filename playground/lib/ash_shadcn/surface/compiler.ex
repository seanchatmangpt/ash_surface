defmodule AshShadcn.Surface.Compiler do
  @moduledoc """
  Compiles the ACTUAL admin domains (`otp_app: :playground`) through AshSurface:

      Ash.Info.Manifest.generate -> AshSurface.Compiler.compile -> Projectors.JS.project_ir

  Result is memoised in `:persistent_term` (compile is pure). Failures are returned as typed
  maps, never raised: a whole-set projection failure falls back to per-action projection and the
  offending actions are reported under `:failures` while the survivors still project.
  """
  @otp_app :playground
  @artifact "ash_surface_client.mjs"

  @type snapshot :: %{entries: [map()], artifact: String.t(), failures: [map()], meta: map()}

  @spec snapshot() :: {:ok, snapshot()} | {:error, map()}
  def snapshot do
    case :persistent_term.get({__MODULE__, :snapshot}, nil) do
      nil ->
        with {:ok, snap} <- build() do
          :persistent_term.put({__MODULE__, :snapshot}, snap)
          {:ok, snap}
        end

      snap ->
        {:ok, snap}
    end
  end

  @doc "Drop the memoised snapshot (tests / after recompiling domains)."
  def reset, do: :persistent_term.erase({__MODULE__, :snapshot})

  def entries_for(resource_name) do
    with {:ok, snap} <- snapshot() do
      {:ok,
       %{
         resource: resource_name,
         entries: Enum.filter(snap.entries, &(&1.resource == resource_name)),
         failures: Enum.filter(snap.failures, &(&1.resource == resource_name))
       }}
    end
  end

  defp build do
    with {:ok, manifest} <- step(:manifest, fn -> Ash.Info.Manifest.generate(otp_app: @otp_app) end),
         {:ok, irs} <- step(:compile, fn -> AshSurface.Compiler.compile(manifest) end),
         irs = List.wrap(irs),
         {:ok, irs, failures, artifact, meta} <- project(irs) do
      {:ok, %{entries: Enum.map(irs, &entry(&1, artifact)), artifact: artifact, failures: failures, meta: meta}}
    end
  end

  defp project(irs) do
    case step(:project, fn -> AshSurface.Projectors.JS.project_ir(irs) end) do
      {:ok, artifacts, meta} ->
        {:ok, irs, [], Map.fetch!(artifacts, @artifact), meta}

      {:error, _} ->
        {ok, bad} =
          Enum.reduce(irs, {[], []}, fn ir, {ok, bad} ->
            case step(:project, fn -> AshSurface.Projectors.JS.project_ir([ir]) end) do
              {:ok, _, _} -> {[ir | ok], bad}
              {:error, err} -> {ok, [failure(ir, err) | bad]}
            end
          end)

        ok = Enum.reverse(ok)

        case step(:project, fn -> AshSurface.Projectors.JS.project_ir(ok) end) do
          {:ok, artifacts, meta} -> {:ok, ok, Enum.reverse(bad), Map.fetch!(artifacts, @artifact), meta}
          {:error, _} = e -> e
        end
    end
  end

  # Normalises `{:ok, ...}` / `{:error, term}` / raises into typed errors.
  defp step(stage, fun) do
    case fun.() do
      {:ok, _} = ok -> ok
      {:ok, _, _} = ok -> ok
      {:error, reason} -> {:error, %{error: "surface_compile_failed", stage: stage, message: inspect(reason)}}
      other -> {:error, %{error: "surface_compile_failed", stage: stage, message: "unexpected: " <> inspect(other)}}
    end
  rescue
    e -> {:error, %{error: "surface_compile_failed", stage: stage, message: Exception.message(e)}}
  catch
    kind, reason -> {:error, %{error: "surface_compile_failed", stage: stage, message: inspect({kind, reason})}}
  end

  defp failure(ir, %{message: message}),
    do: %{resource: inspect(ir.ash.resource), action: to_string(ir.ash.action), actionId: action_id(ir), message: message}

  defp action_id(ir), do: "#{ir.ash.resource |> Module.split() |> List.last()}.#{ir.ash.action}"

  defp entry(ir, artifact) do
    id = action_id(ir)
    sym = String.replace(id, ".", "_")

    %{
      id: id,
      resource: inspect(ir.ash.resource),
      action: to_string(ir.ash.action),
      type: to_string(ir.ash.action_type),
      digest: ir.digest,
      contract: AshSurface.IR.Codec.to_map(ir),
      zod: %{
        input: extract(artifact, "#{sym}_schema"),
        response: extract(artifact, "#{sym}_response_schema")
      }
    }
  end

  # Source of `export const NAME = ...;` (statement ends at `;` followed by a blank line).
  defp extract(artifact, name) do
    case Regex.run(~r/^export const #{Regex.escape(name)} = [\s\S]*?;\n(?:\n|\z)/m, artifact) do
      [src] -> String.trim_trailing(src)
      nil -> nil
    end
  end
end
