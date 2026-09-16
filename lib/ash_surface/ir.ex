defmodule AshSurface.IR do
  @moduledoc """
  The delegated-fact sections of the AshSurface intermediate representation.

  `semanticId`, `authorityBoundary`, `doAuthority`, and `receiptRequired` are
  delegated facts. AshSurface never derives them locally: each is read from the
  manifest's `custom.ash_surface` metadata when a delegating authority stored
  it there, and is `nil` otherwise.

  Canonical IR section shape (per manifest entrypoint action):

      custom.ash_surface = %{
        "id" => action_id,
        "profile" => %{
          "semanticId" => term() | absent,
          "authorityBoundary" => term() | absent,
          "doAuthority" => term() | absent,
          "receiptRequired" => term() | absent,
          ...free projection metadata
        }
      }

  Accessors tolerate atom and string keys so both the in-memory decorated
  manifest and a serialized round-trip feed the same read path.
  """

  @delegated_facts ~w(semanticId authorityBoundary doAuthority receiptRequired)

  @doc "The canonical delegated-fact section keys."
  @spec delegated_facts() :: [String.t(), ...]
  def delegated_facts, do: @delegated_facts

  @doc """
  Reads a delegated fact for a manifest entrypoint from its `custom.ash_surface`
  IR section.

  Returns the delegated value when the manifest metadata carries it, `nil`
  otherwise. No default is inferred and no value is re-derived.
  """
  @spec delegated(Ash.Info.Manifest.Entrypoint.t(), String.t()) :: term() | nil
  def delegated(%Ash.Info.Manifest.Entrypoint{action: action}, fact)
      when fact in @delegated_facts do
    action
    |> surface_section()
    |> profile_section()
    |> Kernel.||(%{})
    |> Map.get(fact)
  end

  defp surface_section(%{custom: custom}) do
    case custom do
      %{ash_surface: section} -> section
      %{"ash_surface" => section} -> section
      _ -> %{}
    end
  end

  defp profile_section(%{profile: profile}) when is_map(profile), do: profile
  defp profile_section(%{"profile" => profile}) when is_map(profile), do: profile
  defp profile_section(_), do: nil
end
