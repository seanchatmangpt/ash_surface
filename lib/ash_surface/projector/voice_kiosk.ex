defmodule AshSurface.Projector.VoiceKiosk do
  @moduledoc """
  Deliberately minimal fifth projector: a voice kiosk speaking the same IR.

  `project_ir/2` reads the verified surface contract and yields per-action
  voice prompts (`presentation.label`), slot grammar hints (schema inputs),
  and capability gating — `authority_required` actions are phrased as
  confirmations and are never auto-executions. The smallness is the proof:
  any new surface speaks the IR in ~60 lines.
  """

  @behaviour AshSurface.Projector

  @grammar %{
    "string" => "free text",
    "integer" => "a whole number",
    "float" => "a number",
    "decimal" => "a number",
    "boolean" => "yes or no",
    "uuid" => "an identifier",
    "utc_datetime" => "a date and time",
    "datetime" => "a date and time"
  }

  @impl true
  def project(%AshSurface.Surface{} = surface, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "voice_kiosk")
    ir = project_ir(surface, opts)
    artifacts = %{"#{prefix}.voice.json" => Jason.encode!(ir, pretty: true)}

    if target_dir = Keyword.get(opts, :target_dir) do
      File.mkdir_p!(target_dir)
      Enum.each(artifacts, fn {file, code} -> File.write!(Path.join(target_dir, file), code) end)
    end

    {:ok, artifacts, %{prefix: prefix, intent_count: length(ir["intents"])}}
  end

  @doc "Projects the surface IR into sorted voice intents: prompts, slots, gating."
  @spec project_ir(AshSurface.Surface.t(), keyword()) :: map()
  def project_ir(%AshSurface.Surface{} = surface, _opts \\ []) do
    resources = get_in(surface.contract, ["manifest", "resources"])

    intents =
      for action <- get_in(surface.contract, ["surface", "actions"]) || [] do
        label = get_in(action, ["profile", "presentation", "label"]) || humanize(action["action"])
        gated? = action["doAuthority"] == true or authority_required?(action)

        %{
          "actionId" => action["id"],
          "prompt" => if(gated?, do: "Please confirm: #{label}", else: label),
          "slots" => slots(resources, action["resource"]),
          "mode" => if(gated?, do: "CONFIRM", else: "ANSWER"),
          "autoExecute" => action["authorityBoundary"] == "OBSERVE" and not gated?
        }
      end
      |> Enum.sort_by(& &1["actionId"])

    %{"kind" => "voice_kiosk", "surfaceDigest" => surface.digest, "intents" => intents}
  end

  defp authority_required?(action) do
    "authority_required" in List.wrap(get_in(action, ["profile", "capabilities"]))
  end

  defp slots(resources, resource) do
    resources
    |> resource_fields(resource)
    |> Enum.map(fn {name, defn} ->
      %{
        "name" => name,
        "grammar" => Map.get(@grammar, get_in(defn, ["type", "kind"]), "any value"),
        "required" => defn["allow_nil?"] != true
      }
    end)
  end

  defp resource_fields(resources, name) do
    resources
    |> values()
    |> Enum.find_value(fn
      %{"name" => ^name, "fields" => fields} -> fields
      %{"module" => ^name, "fields" => fields} -> fields
      _ -> nil
    end)
    |> case do
      %{} = fields -> fields
      _ -> %{}
    end
  end

  defp values(map) when is_map(map), do: Map.values(map)
  defp values(list) when is_list(list), do: list
  defp values(_), do: []

  defp humanize(name), do: name |> to_string() |> String.replace("_", " ")
end
