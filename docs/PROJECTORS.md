# PROJECTORS — the ash_surface projector registry

`ash_surface` renders nothing itself. Every consumer surface is a **projector**:
a pure function from admitted truth (a verified `AshSurface.Surface` or the
canonical `AshSurface.IR`) to ordinary artifacts. This document is the registry
of the projector contracts and the shipped projectors, grounded in the exact
interfaces admitted on sibling branches (provenance table in §6). Law that every
projector accepts by existing:

> IN: a verified surface or IR — already normalized, digest-stable.
> OUT: ordinary executable artifacts + a write manifest.
> NEVER re-discover Ash semantics from Spark internals.
> NEVER dispatch: a projector that actuates is a contract violation.

## 1. The two behaviour contracts

### 1.1 Legacy — `AshSurface.Projector` (on base, this branch)

Declared in `lib/ash_surface.ex`:

```elixir
defmodule AshSurface.Projector do
  @callback project(AshSurface.Surface.t(), keyword()) ::
              {:ok, term(), map()} | {:error, term()}
end
```

`%AshSurface.Surface{}` carries exactly `manifest | contract | digest | action_ids`
(all enforce keys). Dispatch is `AshSurface.project/3`: a module that does not
export `project/2` is refused with `{:error, {:unsupported_projector, projector}}`.

### 1.2 IR-era — `project_ir/2` (admitted on `exp/v16`, `lib/ash_surface/projector/ir.ex`)

```elixir
@callback project_ir(irs :: ir() | [ir()], opts :: keyword()) ::
            {:ok, term(), map()} | {:error, term()}
```

- `irs` is a single IR node or a list; implementations **refuse unknown node
  kinds with typed errors** instead of silently pruning them.
- Dispatch is `AshSurface.Projector.IR.project/3`: accepts a
  `ManifestProjector` adapter (§4) or any module exporting `project_ir/2`;
  anything else is `{:error, {:unknown_projector_kind, term}}`.
- `to_surface/1` admits **exactly one** complete `kind: "ash_surface.surface"`
  node; zero, duplicate, foreign, or incomplete nodes are refused with typed
  errors (`{:missing_surface_ir, n}`, `{:duplicate_surface_irs, n}`,
  `{:invalid_surface_facts, keys}`, `{:invalid_ir, node}}`,
  `{:foreign_ir, nodes}`). A mixed collection — one surface node beside
  foreign nodes — is refused as a whole; the foreign remainder is never
  silently pruned on success.
- Canonical node shape: `%{kind: "ash_surface.surface", ash: %{manifest,
  contract, digest, action_ids}}` — the four facts of a verified surface,
  re-extracted (never re-derived; Ash ships no manifest deserializer and none
  is invented).

**Adoption reality (corrected gapfix-docs-truth-013).** The `project_ir/2`
callback is declared here, but in-tree the behaviour is adopted only by a
test fixture (`test/ash_surface/projector/ir_projector_test.exs`). The shipped
projectors — `AshSurface.Projectors.JS`, `AshSurface.Projectors.ARIA`,
`AshSurface.Projectors.LiveView`, `AshSurface.Projector.VoiceKiosk` — export
`project_ir/2` without declaring the behaviour; dispatch is duck-typed on
`function_exported?(projector, :project_ir, 2)`
(`lib/ash_surface/projector/ir.ex:161`), and
`lib/ash_surface/projectors/live_view.ex:28–31` records the honest reason (the
v16 behaviour folds kind-tagged node maps; these projectors fold
`%AshSurface.IR{}` structs — a different, documented subject contract). The
legacy `AshSurface.Projector` behaviour (§1.1) *is* declared by
`Projector.VoiceKiosk` and `Projector.Expo`. Earlier revisions of this
document implied the behaviour was the shipped adoption path; that was not
true at this tree.

## 2. The IR the projectors speak — five sections

`%AshSurface.IR{}` (`lib/ash_surface/ir.ex`, landed `exp/v01`, five-section
form on `exp/v18`) is a dumb carrier: **the IR determines NOTHING about
existence, meaning, or DO-authority — it carries admitted facts.**

| Section | Struct | Fields | Edge owner (truth source) |
|---|---|---|---|
| `:ash` | `IR.Ash` | `resource`, `action`, `action_type`, `inputs`, `outputs`, `policies` | Ash manifest (re-states, never re-decides) |
| `:semantic` | `IR.Semantic` | `subject_iri`, `capability_iri`, `predicates`, `shape_id`, `ontology` | meaning edge (r2rml) |
| `:capability` | `IR.Capability` | `capability_id`, `consequence_class`, `authority_required`, `receipt_required` | capability edge (a2a) |
| `:presentation` | `IR.Presentation` | `label`, `group`, `order`, `widget`, `format` | rendering edge (admin-pattern); the ONLY metadata ash_surface owns |
| `:schema` | `IR.Schema` | `input`, `output`, `zod`, `aria` | schema edge (shared-discovery) |

Plus envelope fields `version` and `digest`
(`canonical_term -> term_to_binary -> SHA-256 -> lower hex`).

The flat entry reader target projectors render through is
`AshSurface.Projector.IREntry` (`lib/ash_surface/projector/ir_entry.ex`;
corrected gapfix-docs-truth-013 — an earlier revision named
`AshSurface.Projector.IR`/`lib/ash_surface/projector/ir.ex` here, but the
reader was renamed at v50 final integration, commit `4aacae5`, because the v16
behaviour module owns the `Projector.IR` name):
`entries/1` normalizes one IR or a list into id-sorted entries with
`id` (naming fact `resource.action`, last module segment), `action_type`,
`authority_boundary`, `receipt_required`, `capability_iri`, `label`, `zod`.
Two laws hold there:

> **Delegated facts are read, never derived.** `authorityBoundary` is read
> verbatim from the admitted Ash policy map (atom or string keys) and is `nil`
> when no delegating source stored it. No action type, default, or coupling
> infers a boundary. `do_boundary?/1` classifies an admitted fact; it never
> grants authority.

> **Ordering is law.** Every returned list is sorted by the derived action id
> so target artifacts are byte-deterministic.

## 3. Registry of shipped projectors

Four projection lanes leave the IR (`pi_LiveView`, `pi_JS`, `pi_ARIA`,
`pi_voice`) plus the landed Expo reference projector:

| Lane | Module | Canonical path | Admitted on | Contract | Emits |
|---|---|---|---|---|---|
| `pi_JS` | `AshSurface.Projectors.JS` | `lib/ash_surface/projectors/js.ex` | `exp/v18` (`7d8e705`) | `project_ir/2` over `AshSurface.IR` | one `{prefix}.mjs` (default `ash_surface_client`) |
| `pi_ARIA` | `AshSurface.Compiler.Aria` | `lib/ash_surface/compiler/aria.ex` | `exp/v08` (`88dc562`), deepened `exp/v34` (`725503e`) | `build/2` pure section builder (data only) | per-input ARIA contracts mounted at `IR.Schema.aria` |
| `pi_LiveView` (structure) | `AshSurface.Compiler.Presentation` | `lib/ash_surface/compiler/presentation.ex` | `exp/v06`, carried `exp/v50` | `build/2` presentation reader | `label/group/order/widget/format` at `IR.Presentation` |
| `pi_voice` | `AshSurface.Projector.VoiceKiosk` | `lib/ash_surface/projector/voice_kiosk.ex` | `exp/v20` (`41a5a48`), carried `exp/v50` | legacy `project/2` + `project_ir/2` | `{prefix}.voice.json` sorted voice intents |
| reference (landed) | `AshSurface.Projector.Expo` | `lib/ash_surface/projector/expo.ex` | base `282f3ca` | legacy `project/2` | `{prefix}.schemas/.actions/.events/.receipts/.human/.demo/.mjs/.tanstack.mjs` |
| `pi_LiveView` (projection) | `AshSurface.Projectors.LiveView` | `lib/ash_surface/projectors/live_view.ex` | landed at v50 final integration (feat `2b93c85`) | `project_ir/2` over `%AshSurface.IR{}` structs (duck-dispatch; see §1.2 adoption note) | ash_admin-style structure map: navigation/table/forms/relationships + intent-only action controls |
| `pi_ARIA` (projection) | `AshSurface.Projectors.ARIA` | `lib/ash_surface/projectors/aria.ex` | landed at v50 final integration (feat `8827f41`, `exp/v19` line) | `project_ir/2` over `%AshSurface.IR{}` structs (duck-dispatch) | ARIA contract map (+ optional `.json` emission) from delegated `IR.Schema.aria`/`IR.Presentation` facts |

Notes per lane:

- **js (JSDoc + Zod).** `project_ir(ir, opts)` (single IR or list) renders ONE
  TypeScript-free `.mjs`: JSDoc-typed resource namespaces of frozen action
  descriptors; Zod boundary schemas embedded verbatim from `IR.Schema.zod`;
  `ACTIONS`/`SCHEMAS`/`NAMESPACES` registries plus `getAction/1` and
  `dispatchIntent/2`. DO-boundary actions carry dispatch-INTENT descriptors
  only — `dispatchIntent/2` mints frozen data, Zod-validates input, refuses
  unknown actions (`REFUSED_UNKNOWN_ACTION`) and non-DO boundaries
  (`REFUSED_NOT_DO_BOUNDARY`); there is no invoke/dispatch execution path
  anywhere in the artifact. Byte-deterministic: entries id-sorted, namespaces
  resource-sorted, descriptor field order fixed. Opts: `:prefix`,
  `:target_dir`. Returns `{:ok, %{filename => code}, meta}` with
  `meta[:prefix | :action_count | :namespace_count]`.
- **aria.** Accessibility semantics as data: per input, a conservative
  `"role"` from the resolved input type (unmapped types get `nil`, never a
  fabricated role), `"required"` propagated from `allow_nil?` only,
  `"label"` taken from the presentation section when passed (never guessed),
  `"describedby"` derived from `action_id` + input name when a description
  exists. v34 deepened the contract: complete widget type->role table (closed;
  unknown types refused), `aria-required` by presence never negation, tab
  order sequential/unique/gapless over group boundaries (interactive nodes
  only), live regions for OBSERVE surfaces ONLY (DO consequences never
  announce passively; politeness is law, not configuration), id stability
  across re-projections. Rendering belongs to consumers (AshSDUI / live_vue /
  Expo), never to this module. The registered consumer of these contracts on
  this tree is the `AshSurface.Projectors.ARIA` projector (registry row
  above), which reads the delegated facts and emits the contract map —
  registered by gapfix-docs-truth-013 alongside the LiveView module.
- **live_view structure.** [Corrected gapfix-docs-truth-013: an earlier
  revision said "no projector module is shipped" — falsified by the v50
  landing.] The projection module `AshSurface.Projectors.LiveView` folds
  `%AshSurface.IR{}` structs into deterministic navigation/table/form/
  relationship structure maps with intent-only action controls; it honestly
  does not declare the `Projector.IR` behaviour (struct subject, not
  kind-tagged node maps — `live_view.ex:28–31`). The structure facet's source
  *data* is still the presentation section: `build/2` reads ash_admin-style
  overrides from the action's `custom.ash_surface` envelope under
  `"presentation"` (atom or string envelope keys tolerated for in-memory vs
  round-tripped manifests). Defaults when absent: humanized action name,
  `group`/`format` `nil`, `order` 0, `widget "default"`. The widget vocabulary
  is closed and admitted (`default text textarea toggle select number date`);
  anything else is a typed `unknown_widget_presentation` rejection.
  Server-rendered LiveView itself is consumer territory (AshPhoenix
  authoritative).
- **voice_kiosk.** The deliberately minimal fifth projector — see §5.

## 4. The legacy manifest-projector adapter — `from_manifest_projector/1`

Admitted on `exp/v16` (`01545e3`), `lib/ash_surface/projector/ir.ex`. It
carries every existing `AshSurface.Projector` module into the IR era
**unchanged**:

```elixir
@spec from_manifest_projector(term()) ::
        {:ok, ManifestProjector.t()} | {:error, {:unknown_projector_kind, term()}}
```

- Wraps any module exporting legacy `project/2` into
  `%AshSurface.Projector.IR.ManifestProjector{projector: module}`.
- Anything else — wrong module, module without the behaviour, non-module — is
  refused with typed `{:unknown_projector_kind, term}`; a projector that
  exists but implements no legacy behaviour is an unknown kind, **not a silent
  no-op**.
- `ManifestProjector.project_ir/3` re-extracts the verified surface from the
  IR `ash` facts (`to_surface/1`) and delegates to the wrapped projector's
  `project/2` with opts untouched — artifacts, meta, and errors pass through.
  The wrapped projector observes the identical surface it received before the
  IR era (proven state-based in `test/ash_surface/projector/ir_projector_test.exs`
  on `exp/v16`: echoed surface, passthrough errors, unchanged opts, typed
  refusals at both adaptation and dispatch).

## 5. The new-surface recipe (~60 lines, voice_kiosk inlined)

`AshSurface.Projector.VoiceKiosk` (`exp/v20`, `41a5a48`) is the proof that any
new surface speaks the IR in ~60 lines. Steps, then the module verbatim:

1. Pick the contract: legacy `project/2` (surface) or `project_ir/2` (IR).
2. Read only admitted truth: identity (`id`/`resource`/`action`) is re-used,
   never re-minted; delegated facts (`authorityBoundary`, `doAuthority`,
   `receiptRequired`, `semanticId`) are read-or-`nil` — emitting a default is
   fabrication; `profile.transportFacts` carries the delegated selection
   dimension classes (`cost`/`latency`/`privacy`, each `low|medium|high`, per
   transport — `nil`/absent = not delegated, weighed as declared by
   `AshSurface.Transport` and its JS twin, never defaulted); presentation
   reads `label/group/order/widget/format` only.
3. Render artifacts with one pure function per artifact; sort by action id
   (byte-determinism); write only when `:target_dir` is given; always return
   `{:ok, artifacts, manifest}`.
4. Gate authority, never grant it: `authority_required`/DO actions are phrased
   as confirmations and are never auto-executions.
5. Survive the gates (§7).

```elixir
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
    "string" => "free text",        "integer" => "a whole number",
    "float" => "a number",          "decimal" => "a number",
    "boolean" => "yes or no",       "uuid" => "an identifier",
    "utc_datetime" => "a date and time", "datetime" => "a date and time"
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

  defp authority_required?(action),
    do: "authority_required" in List.wrap(get_in(action, ["profile", "capabilities"]))

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
```

## 6. Provenance — where each piece lives at this writing

This document lives on `exp/v22` (base `282f3ca`). The projector wave is
admitted on per-section sibling branches and converges at integration; on this
branch only `lib/ash_surface.ex` (legacy behaviour + `AshSurface.project/3`)
and `lib/ash_surface/projector/expo.ex` are present.

[Corrected gapfix-docs-truth-013: the "only … on this branch" list described
the pre-integration tree and is false on the integrated tree, which carries
every canonical path in the table below — `projector/ir.ex`,
`projector/ir_entry.ex`, `projectors/js.ex`, `projectors/aria.ex`,
`projectors/live_view.ex`, `projector/voice_kiosk.ex`,
`compiler/presentation.ex`, `compiler/aria.ex`, `ir/codec.ex`. The exp/v22-era
sentence is kept above as the writing-time record; the table below (with the
correction markers) is the registry of record.]

| Element | Branch (commit) | Canonical path (post-integration) |
|---|---|---|
| Legacy `AshSurface.Projector` behaviour + dispatch | base `282f3ca` | `lib/ash_surface.ex` |
| `project_ir/2` behaviour + `from_manifest_projector/1` + `project/3` | `exp/v16` (`01545e3`) | `lib/ash_surface/projector/ir.ex` |
| Five-section `AshSurface.IR` | `exp/v01` -> `exp/v18` | `lib/ash_surface/ir.ex` |
| Flat-entry reader (`entries/1`, `describe/1`, `do_boundary?/1`) | `exp/v18` (`7d8e705`), renamed `Projector.IREntry` at v50 final integration (`4aacae5`) | `lib/ash_surface/projector/ir_entry.ex` |
| LiveView projector (`AshSurface.Projectors.LiveView`) | v50 final integration (feat `2b93c85`) | `lib/ash_surface/projectors/live_view.ex` |
| ARIA projector (`AshSurface.Projectors.ARIA`) | v50 final integration (feat `8827f41`, `exp/v19` line) | `lib/ash_surface/projectors/aria.ex` |
| js projector (JSDoc + Zod, `project_ir/2`) | `exp/v18` (`7d8e705`) | `lib/ash_surface/projectors/js.ex` |
| Presentation section (live_view structure facet) | `exp/v06` -> `exp/v50` | `lib/ash_surface/compiler/presentation.ex` |
| ARIA section (data) + v34 depth | `exp/v08` (`88dc562`), `exp/v34` (`725503e`) | `lib/ash_surface/compiler/aria.ex` |
| Voice kiosk projector | `exp/v20` (`41a5a48`), `exp/v50` | `lib/ash_surface/projector/voice_kiosk.ex` |
| IR codec (serialization + content addressing) | `exp/v09` | `lib/ash_surface/ir/codec.ex` |
| Expo reference projector | base `282f3ca` (`eaee5c6`) | `lib/ash_surface/projector/expo.ex` |

Sibling test truth: `exp/v16` `test/ash_surface/projector/ir_projector_test.exs`
(adapter passthrough, typed refusals), `exp/v18`
`test/ash_surface/projectors/js_projector_test.exs` + `test/js/ir_projection.test.mjs`
(byte determinism, intent-only law), `exp/v34`
`test/ash_surface/aria_projector_test.exs` (ARIA depth, six axes).

## 7. Gates

`mix test` (Elixir truth, includes tmp/ projector re-projection), `npm test`
(JS consumer truth), `node --check` on every emitted `.mjs`,
`mix format --check-formatted`, `mix compile --warnings-as-errors`. No element
of this document is ALIVE evidence; aliveness is per-element execution against
the exact admitted subject, in session.
