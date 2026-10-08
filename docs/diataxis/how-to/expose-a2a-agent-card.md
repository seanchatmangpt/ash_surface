# How to expose an ash_surface resource as an A2A agent card

Project an Ash resource's compiled `AshA2A` capability index onto the A2A
wire as a real `%A2A.AgentCard{}` fragment, using
`AshSurface.A2ABridge` (`lib/ash_surface/a2a_bridge.ex`).

`AshSurface.A2ABridge` is a leaf module: it mounts no plug, starts no agent
GenServer, and grants no authority — `grant?` stays false downstream, and any
`:change`/`:external_do` dispatch still runs through `AshA2A.CommandBus`'s
fail-closed admission (`lib/ash_surface/a2a_bridge.ex:24-29`).

## Prerequisites

- `ash_surface` with the pinned `ash_a2a` Hex dependency (~> 26.9, locked
  26.9.31) (`lib/ash_surface/a2a_bridge.ex:4-5`). Note: 26.9.31 does NOT ship
  `AshA2A.Protocol.Agent`/`AgentCard`; the bridge targets the real, compiled
  surface that 26.9.31 does ship (`lib/ash_surface/a2a_bridge.ex:9-12`).
- A resource or domain with the `AshA2A` extension. Zero configuration is
  needed: with no `a2a` block, every public action is projected by the
  compiled capability index (`test/ash_surface/a2a_bridge_test.exs:34-36`).

## 1. Get the resource's derived skills

```elixir
{:ok, skills} = AshSurface.A2ABridge.skills(MyApp.Milestones.Milestone)
```

Returns `[AshA2A.Skill{}]` — the same compiled index
`AshA2A.Info.capability_index_result/1` produces, one skill per public
action (`lib/ash_surface/a2a_bridge.ex:80-91`; asserted at
`test/ash_surface/a2a_bridge_test.exs:82-86`). Returns
`{:error, :not_compiled}` for a resource without the `AshA2A` extension —
honest absence, never a fabricated capability
(`lib/ash_surface/a2a_bridge.ex:51-52`).

## 2. Project the agent-card fragment

```elixir
{:ok, %A2A.AgentCard{} = card} =
  AshSurface.A2ABridge.agent_card_fragment(MyApp.Milestones.Milestone)
```

The card is built only from the resource's real compiled index — never from
hand-written capability claims (`lib/ash_surface/a2a_bridge.ex:16-19`) — and
stamped with ash_surface's identity defaults: `name: "ash_surface"`,
`version: AshSurface.schema_version/0`, `url: "http://localhost:4000"`, and a
description containing the schema version
(`lib/ash_surface/a2a_bridge.ex:60-71`; asserted at
`test/ash_surface/a2a_bridge_test.exs:39-47`).

Skill ids on the wire are canonical (no `Elixir.` prefix), one per public
action (`test/ash_surface/a2a_bridge_test.exs:49-60`).

## 3. Override identity fields with opts

All opts are optional: `:name`, `:description`, `:url`, `:version`
(`lib/ash_surface/a2a_bridge.ex:34-40`).

```elixir
{:ok, card} =
  AshSurface.A2ABridge.agent_card_fragment(MyApp.Milestones.Milestone,
    name: "mx-agent",
    url: "https://surface.example.com",
    version: "9.9.9"
  )
```

Overriding is verified at `test/ash_surface/a2a_bridge_test.exs:62-73`.

## Fail-closed behavior

Both functions return `{:error, :not_compiled}` for a resource or domain
without the `AshA2A` extension (`lib/ash_surface/a2a_bridge.ex:75-77`,
`:88-90`; verified at `test/ash_surface/a2a_bridge_test.exs:75-78`, `:88-91`).

The full test file is Chicago-style against the real pinned ash_a2a — real
resources, real extension, no mocks (`test/ash_surface/a2a_bridge_test.exs:4-6`).

## See Also

- `../reference/api.md` — the ash_surface public API contract.
- External sibling: `ash_a2a` protocol reference and architecture —
  `~/ash_a2a/docs/reference/` and `~/ash_a2a/docs/explanation/architecture.md`
  (the protocol surface this bridge projects onto; capability index and
  `agent_card` live there, not here).
