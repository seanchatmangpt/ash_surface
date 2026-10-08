# SPDX-FileCopyrightText: 2026 ash_surface contributors
# SPDX-License-Identifier: MIT

defmodule AshSurface.AgentCardArtifact do
  @moduledoc """
  Deterministic JSON serialization of an `%A2A.AgentCard{}` (the pinned
  ash_a2a ~26.9 card shape) to `priv/generated/agent_card.json`.

  The card comes from the real runtime path --
  `AshSurface.A2ABridge.agent_card_fragment/2` over a resource's compiled
  capability index, never hand-written capability claims. Serialization is a
  pure function of the card struct (explicit wire-style camelCase keys;
  Jason pretty-printing), so regenerating on the same subject is byte-stable.

  Regenerate with:

      mix run scripts/agent_card_regen.exs

  The persisted artifact is a fragment: it declares no authority -- the
  declaration-is-not-a-grant law holds on the wire too.
  """

  @default_path "priv/generated/agent_card.json"

  @doc "The default artifact path, relative to the repo root."
  @spec default_path() :: String.t()
  def default_path, do: @default_path

  @doc """
  Serializes a card into a JSON-ready camelCase map. Deterministic: explicit
  key set, nil and empty-map fields omitted.
  """
  @spec serialize(A2A.AgentCard.t()) :: map()
  def serialize(%A2A.AgentCard{} = card) do
    base = %{
      "name" => card.name,
      "description" => card.description,
      "url" => card.url,
      "version" => card.version,
      "protocolVersion" => card.protocol_version,
      "capabilities" => atom_key_map(card.capabilities),
      "defaultInputModes" => card.default_input_modes,
      "defaultOutputModes" => card.default_output_modes,
      "skills" => Enum.map(card.skills, &skill_map/1),
      "provider" => maybe_encode(card.provider),
      "documentationUrl" => card.documentation_url,
      "iconUrl" => card.icon_url,
      "supportedInterfaces" =>
        Enum.map(card.supported_interfaces, fn iface ->
          %{
            "url" => iface.url,
            "protocolBinding" => iface.protocol_binding,
            "protocolVersion" => iface.protocol_version
          }
        end),
      "securitySchemes" =>
        Map.new(card.security_schemes, fn {k, v} -> {k, atom_key_map(v)} end)
    }

    base
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == %{} end)
    |> Map.new()
  end

  @doc """
  Serializes and writes the card to `path` (default `priv/generated/agent_card.json`).
  """
  @spec persist(A2A.AgentCard.t(), String.t()) :: :ok
  def persist(card, path \\ @default_path) do
    path = Path.absname(path)
    File.mkdir_p!(Path.dirname(path))
    json = card |> serialize() |> Jason.encode!(pretty: true)
    File.write!(path, json <> "\n")
    :ok
  end

  @spec skill_map(A2A.AgentCard.skill()) :: map()
  defp skill_map(skill) do
    %{
      "id" => skill.id,
      "name" => skill.name,
      "description" => skill.description,
      "tags" => skill.tags
    }
  end

  # Wire-style camelCase for the well-known capability/security keys.
  defp atom_key_map(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {camel_case(k), v}
      pair -> pair
    end)
  end

  defp camel_case(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map(fn
      {part, 0} -> part
      {part, _i} -> String.capitalize(part)
    end)
    |> Enum.join()
  end

  defp maybe_encode(nil), do: nil
  defp maybe_encode(%{} = provider), do: atom_key_map(provider)
  defp maybe_encode(other), do: other
end
