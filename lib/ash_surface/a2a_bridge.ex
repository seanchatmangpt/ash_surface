defmodule AshSurface.A2ABridge do
  @moduledoc """
  Minimal, additive bridge from ash_surface's MX/agent surface state to the
  A2A agent-card surface of the pinned `ash_a2a` Hex dependency (~> 26.9,
  locked 26.9.31).

  ## Real surface, not a re-implementation

  The pinned ash_a2a does NOT ship the newer `AshA2A.Protocol.Agent` /
  `AshA2A.Protocol.AgentCard` modules (those live only on the newer git
  surface the xaas lane references). What 26.9.31 does ship — and what this
  bridge targets — is the real, runtime-capable derived surface:

    * `AshA2A.Info.capability_index_result/1` — the compiled capability index
      (`[AshA2A.Skill{}]`), `{:error, :not_compiled}` for a resource/domain
      without the `AshA2A` extension.
    * `AshA2A.Info.agent_card/2` → `AshA2A.CapabilityIndex.build_agent_card/1`
      → a real `%A2A.AgentCard{}` built ONLY from the resource's real compiled
      index — never from hand-written capability claims.

  ash_surface invents none of the capability semantics here, exactly as
  `AshSurface.Compiler.Capability` establishes: the bridge projects the
  resource's derived truth plus ash_surface's own identity (name/version from
  `AshSurface.schema_version/0`) onto the wire card. It exposes a *fragment*
  of the A2A surface — it mounts no plug, starts no agent GenServer, and
  grants no authority: `grant?` stays false downstream (`AshA2A.Semantic.
  AgentCard`'s law: a declaration is not a grant), and every
  `:change`/`:external_do` dispatch still runs through `AshA2A.CommandBus`'s
  fail-closed admission.

  Zero changes to any existing export: this is a new, leaf module.
  """

  @typedoc "Agent-card fragment opts (all optional)."
  @type opts :: [
          name: String.t(),
          description: String.t(),
          url: String.t(),
          version: String.t()
        ]

  @doc """
  Projects one resource's MX/agent surface state (its compiled `AshA2A`
  capability index) into a real `%A2A.AgentCard{}` fragment.

  Returns the same card `AshA2A.Info.agent_card/2` builds — derived from the
  resource's public Ash actions, sorted by canonical capability id — stamped
  with ash_surface's identity defaults (`name: "ash_surface"`,
  `version: AshSurface.schema_version/0`), overridable via opts.

  `{:error, :not_compiled}` for a resource/domain without the `AshA2A`
  extension (honest absence, never a fabricated capability).
  """
  @spec agent_card_fragment(module(), opts()) ::
          {:ok, A2A.AgentCard.t()} | {:error, :not_compiled}
  def agent_card_fragment(resource_or_domain, opts \\ []) when is_atom(resource_or_domain) do
    case AshA2A.Info.capability_index_result(resource_or_domain) do
      {:ok, _index} ->
        card =
          AshA2A.Info.agent_card(resource_or_domain,
            name: Keyword.get(opts, :name, "ash_surface"),
            description:
              Keyword.get(
                opts,
                :description,
                "ash_surface MX/agent surface projection " <>
                  "(ash_surface v" <> AshSurface.schema_version() <> ")"
              ),
            url: Keyword.get(opts, :url, "http://localhost:4000"),
            version: Keyword.get(opts, :version, AshSurface.schema_version())
          )

        {:ok, card}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  The resource's derived A2A skills (`[AshA2A.Skill{}]`) — the same index
  `agent_card_fragment/2` projects.

  `{:error, :not_compiled}` when the resource/domain has no `AshA2A`
  extension.
  """
  @spec skills(module()) :: {:ok, [AshA2A.Skill.t()]} | {:error, :not_compiled}
  def skills(resource_or_domain) when is_atom(resource_or_domain) do
    AshA2A.Info.capability_index_result(resource_or_domain)
  end
end
