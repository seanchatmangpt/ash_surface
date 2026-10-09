# ash_surface reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### Ash

| `action` | str_key | action: String.t() | atom() | nil |  |  |  |  |

| `action_type` | str_key | action_type: String.t() | atom() | nil |  |  |  |  |

| `inputs` | str_key | inputs: [map()] | map() | nil |  |  |  |  |

| `outputs` | str_key | outputs: [map()] | map() | nil |  |  |  |  |

| `policies` | str_key | policies: [map()] | nil |  |  |  |  |

| `resource` | str_key | resource: module() | String.t() | nil |  |  |  |  |

| `Ash` | struct | defstruct resource, action, action_type, inputs, outputs, policies |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ resource: module() | String.t() | nil, action: String.t() | atom() | nil, action_type: String.t() | atom() | nil, inputs: [map()] | map() | nil, outputs: [map()] | map() | nil, policies: [map()] | nil } |  |  |  |  |


### AshSurface

| `action_id` | function | action_id/1 |  |  |  |  |

| `contract_digest` | function | contract_digest/1 |  |  |  |  |

| `delegated` | function | delegated/2 |  |  |  |  |

| `from_app` | function | from_app/2 |  |  |  |  |

| `from_manifest` | function | from_manifest/2 |  |  |  |  |

| `project` | function | project/3 |  |  |  |  |

| `runtime_path` | function | runtime_path/0 |  |  |  |  |

| `runtime_source` | function | runtime_source/0 |  |  |  |  |

| `schema_version` | function | schema_version/0 |  |  |  |  |

| `verify_surface_digest` | function | verify_surface_digest/1 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `action` | str_key | action: %{action | custom: custom} |  |  |  |  |

| `action_ids` | str_key | action_ids: [String.t()] |  |  |  |  |

| `action_ids` | str_key | action_ids: action_ids |  |  |  |  |

| `action_profile_must_be_a_map` | str_key | {:error, {:action_profile_must_be_a_map, id, action_profile}} |  |  |  |  |

| `actions` | str_key | Map.get("actions") |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `ashManifestSchemaVersion` | str_key | "ashManifestSchemaVersion" => _ |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `contract` | str_key | contract: map() |  |  |  |  |

| `contract` | str_key | contract: contract |  |  |  |  |

| `custom` | str_key | custom: custom |  |  |  |  |

| `custom` | str_key | custom: root_custom |  |  |  |  |

| `digest` | str_key | digest: String.t() |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `digest` | str_key | digest: claimed |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `entrypoints` | str_key | entrypoints: entrypoints |  |  |  |  |

| `evidenceRequired` | str_key | "evidenceRequired" => _ |  |  |  |  |

| `evidenceRequired` | str_key | Map.get("evidenceRequired") |  |  |  |  |

| `evidence_required_must_be_boolean` | str_key | {:error, {:evidence_required_must_be_boolean, id, evidence}} |  |  |  |  |

| `generatorIdentity` | str_key | "generatorIdentity" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `manifest` | str_key | manifest: Ash.Info.Manifest.t() |  |  |  |  |

| `manifest` | str_key | manifest: decorated |  |  |  |  |

| `manifest` | str_key | "manifest" => _ |  |  |  |  |

| `manifestDigest` | str_key | "manifestDigest" => _ |  |  |  |  |

| `marketplaceIdentity` | str_key | "marketplaceIdentity" => _ |  |  |  |  |

| `otp_app` | str_key | otp_app: otp_app |  |  |  |  |

| `possibleRefusals` | str_key | "possibleRefusals" => _ |  |  |  |  |

| `possibleRefusals` | str_key | Map.get("possibleRefusals") |  |  |  |  |

| `possible_refusal_not_a_refusal_code` | str_key | {:error, {:possible_refusal_not_a_refusal_code, id, bad}} |  |  |  |  |

| `possible_refusals_must_be_strings` | str_key | {:error, {:possible_refusals_must_be_strings, id, refusals}} |  |  |  |  |

| `profile` | str_key | Keyword.get("profile") |  |  |  |  |

| `profile` | str_key | "profile" => _ |  |  |  |  |

| `profile_actions_must_be_a_map` | str_key | {:error, :profile_actions_must_be_a_map} |  |  |  |  |

| `profile_key_not_serializable` | str_key | {:error, {:profile_key_not_serializable, key}} |  |  |  |  |

| `profile_must_be_a_map` | str_key | {:error, :profile_must_be_a_map} |  |  |  |  |

| `profile_value_not_serializable` | str_key | {:error, {:profile_value_not_serializable, value}} |  |  |  |  |

| `receiptRequired` | str_key | "receiptRequired" => _ |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `resource` | str_key | "resource" => _ |  |  |  |  |

| `schemaVersion` | str_key | "schemaVersion" => _ |  |  |  |  |

| `semanticId` | str_key | "semanticId" => _ |  |  |  |  |

| `surface` | str_key | "surface" => _ |  |  |  |  |

| `surfaceSchemaVersion` | str_key | "surfaceSchemaVersion" => _ |  |  |  |  |

| `surface_digest_mismatch` | str_key | {:error, {:surface_digest_mismatch, term(), String.t()}} |  |  |  |  |

| `surface_digest_mismatch` | str_key | {:error, {:surface_digest_mismatch, claimed, actual}} |  |  |  |  |

| `unknown_action_profile` | str_key | {:error, {:unknown_action_profile, unknown}} |  |  |  |  |

| `unsupported_projector` | str_key | {:error, {:unsupported_projector, projector}} |  |  |  |  |


### AshSurface.A2ABridge

| `agent_card_fragment` | function | agent_card_fragment/2 |  |  |  |  |

| `skills` | function | skills/1 |  |  |  |  |

| `description` | str_key | description: String.t() |  |  |  |  |

| `description` | str_key | description: Keyword.get( opts, :description, "ash_surface MX/agent surface projection " <> "(ash_surface v" <> AshSurface.schema_version() <> "). " <> "Authority: this card is descriptive only and grants no " <> "authority; consequential DO is reachable only through a " <> "receipted admission boundary." ) |  |  |  |  |

| `description` | str_key | Keyword.get("description") |  |  |  |  |

| `name` | str_key | name: String.t() |  |  |  |  |

| `name` | str_key | name: Keyword.get(opts, :name, "ash_surface") |  |  |  |  |

| `name` | str_key | Keyword.get("name") |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |

| `url` | str_key | url: String.t() |  |  |  |  |

| `url` | str_key | url: Keyword.get(opts, :url, "http: |  |  |  |  |

| `url` | str_key | Keyword.get("url") |  |  |  |  |

| `version` | str_key | version: String.t() |  |  |  |  |

| `version` | str_key | version: Keyword.get(opts, :version, AshSurface.schema_version()) |  |  |  |  |

| `version` | str_key | Keyword.get("version") |  |  |  |  |

| `opts` | type | @type opts :: [ name: String.t(), description: String.t(), url: String.t(), version: String.t() ] |  |  |  |  |


### AshSurface.AgentCardArtifact

| `default_path` | function | default_path/0 |  |  |  |  |

| `persist` | function | persist/2 |  |  |  |  |

| `serialize` | function | serialize/1 |  |  |  |  |

| `capabilities` | str_key | "capabilities" => _ |  |  |  |  |

| `defaultInputModes` | str_key | "defaultInputModes" => _ |  |  |  |  |

| `defaultOutputModes` | str_key | "defaultOutputModes" => _ |  |  |  |  |

| `description` | str_key | "description" => _ |  |  |  |  |

| `documentationUrl` | str_key | "documentationUrl" => _ |  |  |  |  |

| `iconUrl` | str_key | "iconUrl" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `pretty` | str_key | pretty: true |  |  |  |  |

| `protocolBinding` | str_key | "protocolBinding" => _ |  |  |  |  |

| `protocolVersion` | str_key | "protocolVersion" => _ |  |  |  |  |

| `provider` | str_key | "provider" => _ |  |  |  |  |

| `securitySchemes` | str_key | "securitySchemes" => _ |  |  |  |  |

| `skills` | str_key | "skills" => _ |  |  |  |  |

| `supportedInterfaces` | str_key | "supportedInterfaces" => _ |  |  |  |  |

| `tags` | str_key | "tags" => _ |  |  |  |  |

| `url` | str_key | "url" => _ |  |  |  |  |

| `version` | str_key | "version" => _ |  |  |  |  |


### AshSurface.CanonicalJSON

| `encode` | function | encode/1 |  |  |  |  |

| `sha256_hex` | function | sha256_hex/1 |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |


### AshSurface.CastleCapabilityIntake

| `actuation_authority?` | function | actuation_authority?/1 |  |  |  |  |

| `authority_ceiling` | function | authority_ceiling/0 |  |  |  |  |

| `canonical_truth?` | function | canonical_truth?/1 |  |  |  |  |

| `donors` | function | donors/0 |  |  |  |  |

| `fetch` | function | fetch/1 |  |  |  |  |

| `owner_capability` | function | owner_capability/0 |  |  |  |  |

| `projection_source` | function | projection_source/0 |  |  |  |  |

| `capability` | str_key | capability: :mobile_surface |  |  |  |  |

| `capability` | str_key | capability: :semantic_document_projection |  |  |  |  |

| `disposition` | str_key | disposition: :wrap |  |  |  |  |

| `disposition` | str_key | disposition: :candidate_wrap |  |  |  |  |

| `placement` | str_key | placement: :mobile_surface |  |  |  |  |

| `placement` | str_key | placement: :powerless_document_projection |  |  |  |  |

| `repository` | str_key | repository: "seanchatmangpt/ash_expo" |  |  |  |  |

| `repository` | str_key | repository: "seanchatmangpt/mmdio" |  |  |  |  |

| `sha` | str_key | sha: "024852b92330c76e12d0ab26531ef1e511c71041" |  |  |  |  |

| `sha` | str_key | sha: "afc1f6e890a6d1c17b84d5931b21d3c74a851ebc" |  |  |  |  |

| `unknown_castle_surface_donor` | str_key | {:error, :unknown_castle_surface_donor} |  |  |  |  |


### AshSurface.CommandCenter

| `create` | function | create/2 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `__struct__` | str_key | __struct__: ^module |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `capabilities` | str_key | capabilities: [map()] |  |  |  |  |

| `capabilities` | str_key | Keyword.get("capabilities") |  |  |  |  |

| `capabilities` | str_key | capabilities: Enum.sort_by(capabilities, &canonical_key/1) |  |  |  |  |

| `capabilities` | str_key | capabilities: capabilities |  |  |  |  |

| `capabilities` | str_key | "capabilities" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [String.t()] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: String.t() |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `obligations` | str_key | obligations: [Obligation.t()] |  |  |  |  |

| `obligations` | str_key | Keyword.get("obligations") |  |  |  |  |

| `obligations` | str_key | obligations: obligations |> Enum.map(&Obligation.to_map/1) |> Enum.sort_by(& &1["obligationId"]) |  |  |  |  |

| `obligations` | str_key | obligations: obligations |  |  |  |  |

| `obligations` | str_key | "obligations" => _ |  |  |  |  |

| `observations` | str_key | observations: [Observation.t()] |  |  |  |  |

| `observations` | str_key | Keyword.get("observations") |  |  |  |  |

| `observations` | str_key | observations: observations |> Enum.map(&Observation.to_map/1) |> Enum.sort_by(& &1["observationId"]) |  |  |  |  |

| `observations` | str_key | observations: observations |  |  |  |  |

| `observations` | str_key | "observations" => _ |  |  |  |  |

| `planningEpisodes` | str_key | "planningEpisodes" => _ |  |  |  |  |

| `planning_episodes` | str_key | planning_episodes: [PlanningEpisode.t()] |  |  |  |  |

| `planning_episodes` | str_key | Keyword.get("planning_episodes") |  |  |  |  |

| `planning_episodes` | str_key | planning_episodes: planning_episodes |> Enum.map(&PlanningEpisode.to_map/1) |> Enum.sort_by(& &1["episodeId"]) |  |  |  |  |

| `planning_episodes` | str_key | planning_episodes: planning_episodes |  |  |  |  |

| `projectionId` | str_key | "projectionId" => _ |  |  |  |  |

| `projection_id` | str_key | projection_id: String.t() |  |  |  |  |

| `projection_id` | str_key | projection_id: "cc_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [String.t()] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipt_refs) |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipt_refs |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | standing: :ALIVE | :PARTIAL_ALIVE | :REFUSED | :BLOCKED |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `AshSurface.CommandCenter` | struct | defstruct projection_id, exact_subject, state_digest, observations, obligations, planning_episodes, capabilities, receipt_refs, evidence_refs: [], standing: :PARTIAL_ALIVE, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ projection_id: String.t(), exact_subject: String.t(), state_digest: String.t(), observations: [Observation.t()], obligations: [Obligation.t()], planning_episodes: [PlanningEpisode.t()], capabilities: [map()], receipt_refs: [String.t()], evidence_refs: [String.t()], standing: :ALIVE | :PARTIAL_ALIVE | :REFUSED | :BLOCKED, authority_boundary: :OBSERVE } |  |  |  |  |


### AshSurface.CommitmentBoundary

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `actionRef` | str_key | "actionRef" => _ |  |  |  |  |

| `action_ref` | str_key | action_ref: action_ref |  |  |  |  |

| `authorityCeiling` | str_key | "authorityCeiling" => _ |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :CONSTRUCT |  |  |  |  |

| `boundaryId` | str_key | "boundaryId" => _ |  |  |  |  |

| `boundary_id` | str_key | boundary_id: "cb_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `confirmationRequired` | str_key | "confirmationRequired" => _ |  |  |  |  |

| `confirmationState` | str_key | "confirmationState" => _ |  |  |  |  |

| `confirmation_required` | str_key | confirmation_required: true |  |  |  |  |

| `confirmation_state` | str_key | Keyword.get("confirmation_state") |  |  |  |  |

| `confirmation_state` | str_key | confirmation_state: confirmation_state |  |  |  |  |

| `consequenceSummary` | str_key | "consequenceSummary" => _ |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: consequence_summary |  |  |  |  |

| `constructRef` | str_key | "constructRef" => _ |  |  |  |  |

| `construct_ref` | str_key | construct_ref: Keyword.get(opts, :construct_ref) |  |  |  |  |

| `construct_ref` | str_key | Keyword.get("construct_ref") |  |  |  |  |

| `construct_ref` | str_key | construct_ref: canonical.construct_ref |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `expiresAt` | str_key | "expiresAt" => _ |  |  |  |  |

| `expires_at` | str_key | expires_at: normalize_datetime(Keyword.get(opts, :expires_at)) |  |  |  |  |

| `expires_at` | str_key | Keyword.get("expires_at") |  |  |  |  |

| `expires_at` | str_key | expires_at: Keyword.get(opts, :expires_at) |  |  |  |  |

| `externalEffects` | str_key | "externalEffects" => _ |  |  |  |  |

| `external_effects` | str_key | external_effects: [] |  |  |  |  |

| `external_effects` | str_key | Keyword.get("external_effects") |  |  |  |  |

| `external_effects` | str_key | external_effects: Enum.sort(effects) |  |  |  |  |

| `external_effects` | str_key | external_effects: effects |  |  |  |  |

| `nextHandoff` | str_key | "nextHandoff" => _ |  |  |  |  |

| `next_handoff` | str_key | next_handoff: :BRCE |  |  |  |  |

| `reversibility` | str_key | Keyword.get("reversibility") |  |  |  |  |

| `reversibility` | str_key | reversibility: reversibility |  |  |  |  |

| `reversibility` | str_key | "reversibility" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `whyThisRef` | str_key | "whyThisRef" => _ |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: Keyword.get(opts, :why_this_ref) |  |  |  |  |

| `why_this_ref` | str_key | Keyword.get("why_this_ref") |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: canonical.why_this_ref |  |  |  |  |

| `AshSurface.CommitmentBoundary` | struct | defstruct boundary_id, subject_ref, action_ref, consequence_summary, reversibility, confirmation_state, construct_ref, why_this_ref, expires_at, state_digest, external_effects: [], evidence_refs: [], confirmation_required: true, next_handoff: :BRCE, authority_ceiling: :CONSTRUCT |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.Compiler

| `compile` | function | compile/1 |  |  |  |  |

| `compile` | function | compile/2 |  |  |  |  |

| `action` | str_key | action: action.name |  |  |  |  |

| `action_id` | str_key | action_id: id |  |  |  |  |

| `action_type` | str_key | action_type: action.type |  |  |  |  |

| `actions` | str_key | actions: count |  |  |  |  |

| `allow_nil` | str_key | allow_nil: !!&1.allow_nil? |  |  |  |  |

| `ash` | str_key | ash: AshSurface.Compiler.Section.Ash |  |  |  |  |

| `ash` | str_key | ash: built.ash |  |  |  |  |

| `capability` | str_key | capability: AshSurface.Compiler.Section.Capability |  |  |  |  |

| `capability` | str_key | capability: built.capability |  |  |  |  |

| `custom` | str_key | custom: Map.get(action, :custom) || %{} |  |  |  |  |

| `custom` | str_key | Map.get("custom") |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `discovery` | str_key | discovery: receipt |  |  |  |  |

| `entrypoints` | str_key | entrypoints: entrypoints |  |  |  |  |

| `has_default` | str_key | has_default: !!&1.has_default? |  |  |  |  |

| `has_default` | str_key | has_default: !is_nil(&1.default) |  |  |  |  |

| `id` | str_key | id: action_id(resource, action.name) |  |  |  |  |

| `inputs` | str_key | inputs: action.inputs |> Kernel.||([]) |> Enum.map( &%{ name: to_string(&1.name), type: manifest_type_kind(Map.get(&1, :type)), allow_nil: !!&1.allow_nil?, has_default: !!&1.has_default? } ) |> Enum.sort_by(& &1.name) |  |  |  |  |

| `inputs` | str_key | inputs: action.arguments |> Kernel.||([]) |> Enum.filter(& &1.public?) |> Enum.map( &%{ name: to_string(&1.name), type: short_name_kind(Map.get(&1, :type)), allow_nil: !!&1.allow_nil?, has_default: !is_nil(&1.default) } ) |> Enum.sort_by(& &1.name) |  |  |  |  |

| `invalid_section_module` | str_key | {:error, {:invalid_section_module, key, module}} |  |  |  |  |

| `kind` | str_key | kind: kind |  |  |  |  |

| `missing_section_keys` | str_key | {:error, {:missing_section_keys, missing}} |  |  |  |  |

| `name` | str_key | name: to_string(&1.name) |  |  |  |  |

| `no_sections` | str_key | {:error, :no_sections} |  |  |  |  |

| `outputs` | str_key | outputs: action.metadata |> Kernel.||([]) |> Enum.map(&to_string(&1.name)) |> Enum.sort() |  |  |  |  |

| `presentation` | str_key | presentation: AshSurface.Compiler.Section.Presentation |  |  |  |  |

| `presentation` | str_key | presentation: built.presentation |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `resource_name` | str_key | resource_name: module_name(resource) |  |  |  |  |

| `schema` | str_key | schema: AshSurface.Compiler.Section.Schema |  |  |  |  |

| `schema` | str_key | schema: built.schema |  |  |  |  |

| `section_failed` | str_key | {:error, {:section_failed, id, reason}} |  |  |  |  |

| `sections` | str_key | Keyword.get("sections") |  |  |  |  |

| `sections_must_bind_keys_to_modules` | str_key | {:error, {:sections_must_bind_keys_to_modules, sections}} |  |  |  |  |

| `sections_must_bind_keys_to_modules` | str_key | {:error, {:sections_must_bind_keys_to_modules, other}} |  |  |  |  |

| `semantic` | str_key | semantic: AshSurface.Compiler.Section.Semantic |  |  |  |  |

| `semantic` | str_key | semantic: built.semantic |  |  |  |  |

| `source` | str_key | source: source |  |  |  |  |

| `token` | str_key | token: :erlang.unique_integer([:positive, :monotonic]) |  |  |  |  |

| `type` | str_key | type: manifest_type_kind(Map.get(&1, :type)) |  |  |  |  |

| `type` | str_key | Map.get("type") |  |  |  |  |

| `type` | str_key | type: short_name_kind(Map.get(&1, :type)) |  |  |  |  |

| `unknown_section_keys` | str_key | {:error, {:unknown_section_keys, unknown}} |  |  |  |  |

| `unsupported_source` | str_key | {:error, {:unsupported_source, domain}} |  |  |  |  |

| `unsupported_source` | str_key | {:error, {:unsupported_source, source}} |  |  |  |  |

| `version` | str_key | version: @ir_version |  |  |  |  |


### AshSurface.Compiler.Aria

| `build` | function | build/2 |  |  |  |  |

| `describedby_id` | function | describedby_id/2 |  |  |  |  |

| `mount` | function | mount/2 |  |  |  |  |

| `name` | function | name/0 |  |  |  |  |

| `role_for_type` | function | role_for_type/1 |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: Map.get(input, :allow_nil?) |  |  |  |  |

| `allow_nil?` | str_key | Map.get("allow_nil?") |  |  |  |  |

| `aria` | str_key | aria: aria |  |  |  |  |

| `boolean` | str_key | boolean: "checkbox" |  |  |  |  |

| `ci_string` | str_key | ci_string: "textbox" |  |  |  |  |

| `describedby` | str_key | "describedby" => _ |  |  |  |  |

| `description` | str_key | description: Map.get(input, :description) |  |  |  |  |

| `description` | str_key | Map.get("description") |  |  |  |  |

| `enum` | str_key | enum: "switch" |  |  |  |  |

| `inputs` | str_key | Map.get("inputs") |  |  |  |  |

| `integer` | str_key | integer: "slider" |  |  |  |  |

| `invalid_presentation` | str_key | {:error, {:invalid_presentation, presentation}} |  |  |  |  |

| `invalid_presentation` | str_key | {:error, {:invalid_presentation, other}} |  |  |  |  |

| `kind` | str_key | kind: kind |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `label` | str_key | Map.get("label") |  |  |  |  |

| `missing_action_id` | str_key | {:error, :missing_action_id} |  |  |  |  |

| `name` | str_key | name: Map.get(input, :name) |  |  |  |  |

| `name` | str_key | Map.get("name") |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `role` | str_key | "role" => _ |  |  |  |  |

| `string` | str_key | string: "textbox" |  |  |  |  |

| `type` | str_key | type: Map.get(input, :type) |  |  |  |  |

| `type` | str_key | Map.get("type") |  |  |  |  |


### AshSurface.Compiler.AshTruth

| `admitted_keys` | function | admitted_keys/0 |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `section` | function | section/2 |  |  |  |  |

| `action` | str_key | action: act.name |  |  |  |  |

| `action` | str_key | action: node.action |  |  |  |  |

| `action_type` | str_key | action_type: act.type |  |  |  |  |

| `action_type` | str_key | action_type: node.action_type |  |  |  |  |

| `bypass` | str_key | bypass: policy.bypass? == true |  |  |  |  |

| `bypass` | str_key | bypass: policy.bypass |  |  |  |  |

| `check` | str_key | check: inspect(module) |  |  |  |  |

| `check` | str_key | check: inspect(check.check_module) |  |  |  |  |

| `checks` | str_key | checks: Enum.map(policy.policies, &check_fact/1) |  |  |  |  |

| `checks` | str_key | checks: policy.checks |  |  |  |  |

| `conditions` | str_key | conditions: Enum.map(policy.condition, &condition_fact/1) |  |  |  |  |

| `conditions` | str_key | conditions: policy.conditions |  |  |  |  |

| `default` | str_key | default: argument.default |  |  |  |  |

| `default` | str_key | default: input.default |  |  |  |  |

| `fabricated_fact` | str_key | {:error, {:fabricated_fact, kind, actual}} |  |  |  |  |

| `input` | str_key | input: [atom()] |  |  |  |  |

| `input` | str_key | input: @admitted_input_keys |  |  |  |  |

| `inputs` | str_key | inputs: inputs(act) |  |  |  |  |

| `inputs` | str_key | inputs: Enum.map(node.inputs, &input_fact/1) |  |  |  |  |

| `kind` | str_key | kind: check.type |  |  |  |  |

| `name` | str_key | name: argument.name |  |  |  |  |

| `name` | str_key | name: input.name |  |  |  |  |

| `not_an_ash_resource` | str_key | {:error, {:not_an_ash_resource, resource}} |  |  |  |  |

| `opts` | str_key | opts: authored_opts(opts) |  |  |  |  |

| `output` | str_key | output: [atom()] |  |  |  |  |

| `output` | str_key | output: @admitted_output_keys |  |  |  |  |

| `outputs` | str_key | outputs: outputs(act) |  |  |  |  |

| `outputs` | str_key | outputs: output_fact(node.outputs) |  |  |  |  |

| `policies` | str_key | policies: policies(resource) |  |  |  |  |

| `policies` | str_key | policies: Enum.map(node.policies, &policy_fact/1) |  |  |  |  |

| `policy` | str_key | policy: [atom()] |  |  |  |  |

| `policy` | str_key | policy: @admitted_policy_keys |  |  |  |  |

| `required` | str_key | required: not argument.allow_nil? |  |  |  |  |

| `required` | str_key | required: input.required |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `resource` | str_key | resource: inspect(node.resource) |  |  |  |  |

| `returns` | str_key | Map.get("returns") |  |  |  |  |

| `returns` | str_key | returns: type_name(type) |  |  |  |  |

| `returns` | str_key | returns: output.returns |  |  |  |  |

| `section` | str_key | section: @section |  |  |  |  |

| `section` | str_key | section: [atom()] |  |  |  |  |

| `section` | str_key | section: @admitted_section_keys |  |  |  |  |

| `type` | str_key | type: type_name(argument.type) |  |  |  |  |

| `type` | str_key | type: input.type |  |  |  |  |

| `unknown_public_action` | str_key | {:error, {:unknown_public_action, action, public |> Enum.map(& &1.name) |> Enum.sort()}} |  |  |  |  |


### AshSurface.Compiler.Capability

| `build` | function | build/2 |  |  |  |  |

| `__struct__` | str_key | __struct__: AshA2A.Skill |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `authority_required` | str_key | authority_required: command_bus_authority_requirement(consequence) |  |  |  |  |

| `capability_id` | str_key | capability_id: id |  |  |  |  |

| `consequence` | str_key | consequence: consequence |  |  |  |  |

| `consequence_class` | str_key | consequence_class: consequence |  |  |  |  |

| `id` | str_key | id: id |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `receipt_required` | str_key | receipt_required: receipt_required?(consequence) |  |  |  |  |

| `resource` | str_key | Map.get("resource") |  |  |  |  |


### AshSurface.Compiler.IR

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: boolean() |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `aria` | str_key | aria: map() |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `description` | str_key | description: String.t() | nil |  |  |  |  |

| `input` | str_key | input: %{optional(String.t()) => map()} |  |  |  |  |

| `inputs` | str_key | inputs: [Input.t()] |  |  |  |  |

| `name` | str_key | name: atom() | String.t() |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] |  |  |  |  |

| `presentation` | str_key | presentation: map() | nil |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `type` | str_key | type: Ash.Info.Manifest.Type.t() | atom() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() |  |  |  |  |


### AshSurface.Compiler.IR.Capability

| `authority_required` | str_key | authority_required: boolean() | nil |  |  |  |  |

| `capability_id` | str_key | capability_id: String.t() | nil |  |  |  |  |

| `consequence_class` | str_key | consequence_class: consequence_class() | nil |  |  |  |  |

| `receipt_required` | str_key | receipt_required: boolean() | nil |  |  |  |  |

| `AshSurface.Compiler.IR.Capability` | struct | defstruct capability_id, consequence_class, authority_required, receipt_required |  |  |  |  |

| `consequence_class` | type | @type consequence_class :: :observe | :change | :external_do | :unknown |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ capability_id: String.t() | nil, consequence_class: consequence_class() | nil, authority_required: boolean() | nil, receipt_required: boolean() | nil } |  |  |  |  |


### AshSurface.Compiler.IR.Presentation

| `format` | str_key | format: nil |  |  |  |  |

| `format` | str_key | format: String.t() | nil |  |  |  |  |

| `group` | str_key | group: nil |  |  |  |  |

| `group` | str_key | group: String.t() | nil |  |  |  |  |

| `label` | str_key | label: nil |  |  |  |  |

| `label` | str_key | label: String.t() |  |  |  |  |

| `order` | str_key | order: 0 |  |  |  |  |

| `order` | str_key | order: number() |  |  |  |  |

| `widget` | str_key | widget: "default" |  |  |  |  |

| `widget` | str_key | widget: String.t() |  |  |  |  |

| `AshSurface.Compiler.IR.Presentation` | struct | defstruct label: nil, group: nil, order: 0, widget: "default", format: nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ label: String.t(), group: String.t() | nil, order: number(), widget: String.t(), format: String.t() | nil } |  |  |  |  |


### AshSurface.Compiler.Presentation

| `build` | function | build/2 |  |  |  |  |

| `ash_surface` | str_key | Map.get("ash_surface") |  |  |  |  |

| `code` | str_key | code: "unknown_widget_presentation" |  |  |  |  |

| `code` | str_key | code: "invalid_presentation_compilation" |  |  |  |  |

| `detail` | str_key | detail: "presentation for #{inspect(name)} declares widget #{inspect(widget)}; admitted widgets are " <> inspect(@admitted_widgets) |  |  |  |  |

| `detail` | str_key | detail: detail |  |  |  |  |

| `format` | str_key | format: overrides["format"] |  |  |  |  |

| `group` | str_key | group: overrides["group"] |  |  |  |  |

| `label` | str_key | label: overrides["label"] || humanize(name) |  |  |  |  |

| `name` | str_key | name: name |  |  |  |  |

| `order` | str_key | order: overrides["order"] || 0 |  |  |  |  |

| `presentation` | str_key | Map.get("presentation") |  |  |  |  |

| `widget` | str_key | widget: overrides["widget"] || "default" |  |  |  |  |

| `widget` | str_key | "widget" => _ |  |  |  |  |


### AshSurface.Compiler.Schema

| `build` | function | build/2 |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `action_count` | str_key | action_count: non_neg_integer() |  |  |  |  |

| `action_count` | str_key | action_count: map_size(ir) |  |  |  |  |

| `action_without_id` | str_key | {:error, {:action_without_id, other}} |  |  |  |  |

| `actions` | str_key | Map.get("actions") |  |  |  |  |

| `actions_must_be_a_list` | str_key | {:error, {:actions_must_be_a_list, other}} |  |  |  |  |

| `argument_count` | str_key | argument_count: non_neg_integer() |  |  |  |  |

| `argument_count` | str_key | argument_count: arg_count |  |  |  |  |

| `argument_without_name` | str_key | {:error, {:argument_without_name, id}} |  |  |  |  |

| `arguments` | str_key | Map.get("arguments") |  |  |  |  |

| `arguments_must_be_a_list` | str_key | {:error, {:arguments_must_be_a_list, id, other}} |  |  |  |  |

| `aria` | str_key | aria: render_aria(id, args) |  |  |  |  |

| `array` | str_key | "array" => _ |  |  |  |  |

| `boolean` | str_key | "boolean" => _ |  |  |  |  |

| `datetime` | str_key | "datetime" => _ |  |  |  |  |

| `decimal` | str_key | "decimal" => _ |  |  |  |  |

| `discovery_must_be_a_map` | str_key | {:error, :discovery_must_be_a_map} |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `input` | str_key | input: input |  |  |  |  |

| `integer` | str_key | "integer" => _ |  |  |  |  |

| `invalid_returns` | str_key | {:error, {:invalid_returns, id, other}} |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `map` | str_key | "map" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `output` | str_key | output: returns |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `returns` | str_key | Map.get("returns") |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `type` | str_key | "type" => _ |  |  |  |  |

| `utc_datetime` | str_key | "utc_datetime" => _ |  |  |  |  |

| `uuid` | str_key | "uuid" => _ |  |  |  |  |

| `z.unknown()` | str_key | Map.get("z.unknown()") |  |  |  |  |

| `zod` | str_key | zod: render_zod(id, args, returns) |  |  |  |  |


### AshSurface.Compiler.Section.Ash

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `resource` | str_key | Map.get("resource") |  |  |  |  |


### AshSurface.Compiler.Section.Capability

| `build` | function | build/2 |  |  |  |  |

| `as` | str_key | as: CapabilitySection |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |


### AshSurface.Compiler.Section.Presentation

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `custom` | str_key | Map.get("custom") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |


### AshSurface.Compiler.Section.Schema

| `build` | function | build/2 |  |  |  |  |

| `action_missing_from_schema_section` | str_key | {:error, {:action_missing_from_schema_section, id}} |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `allow_nil` | str_key | Map.get("allow_nil") |  |  |  |  |

| `allow_nil?` | str_key | "allow_nil?" => _ |  |  |  |  |

| `arguments` | str_key | "arguments" => _ |  |  |  |  |

| `id` | str_key | Map.get("id") |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `inputs` | str_key | Map.get("inputs") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `name` | str_key | Map.get("name") |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `name` | str_key | Map.fetch!("name") |  |  |  |  |

| `returns` | str_key | "returns" => _ |  |  |  |  |

| `type` | str_key | Map.get("type") |  |  |  |  |


### AshSurface.Compiler.Section.Semantic

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `resource` | str_key | Map.get("resource") |  |  |  |  |


### AshSurface.Compiler.Semantic

| `build` | function | build/2 |  |  |  |  |

| `as` | str_key | as: R2RMLInfo |  |  |  |  |

| `capability_iri` | str_key | capability_iri: capability |  |  |  |  |

| `capture` | str_key | capture: :all_names |  |  |  |  |

| `class_iris` | str_key | class_iris: [capability | _] |  |  |  |  |

| `class_iris` | str_key | class_iris: [] |  |  |  |  |

| `ontology` | str_key | ontology: ontology(mapping) |  |  |  |  |

| `predicates` | str_key | predicates: predicates(mapping) |  |  |  |  |

| `resources` | str_key | resources: [mapping] |  |  |  |  |

| `shape_id` | str_key | shape_id: shape_id(mapping, capability) |  |  |  |  |

| `subject_iri` | str_key | subject_iri: subject_iri(mapping) |  |  |  |  |

| `subject_map` | str_key | subject_map: %{term_type: :iri, value: value} |  |  |  |  |

| `subject_map` | str_key | subject_map: %{term_type: :blank_node} |  |  |  |  |

| `term_type` | str_key | term_type: :iri |  |  |  |  |

| `term_type` | str_key | term_type: :blank_node |  |  |  |  |

| `value` | str_key | value: value |  |  |  |  |


### AshSurface.DevotionalEpisode

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `audioRef` | str_key | Map.get("audioRef") |  |  |  |  |

| `audioRef` | str_key | "audioRef" => _ |  |  |  |  |

| `audio_ref` | str_key | Map.get("audio_ref") |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `completionReceiptRef` | str_key | "completionReceiptRef" => _ |  |  |  |  |

| `completion_receipt_ref` | str_key | Keyword.get("completion_receipt_ref") |  |  |  |  |

| `completion_receipt_ref` | str_key | completion_receipt_ref: completion_receipt_ref |  |  |  |  |

| `continuousPlay` | str_key | "continuousPlay" => _ |  |  |  |  |

| `continuous_play` | str_key | continuous_play: true |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `durationSeconds` | str_key | Map.get("durationSeconds") |  |  |  |  |

| `durationSeconds` | str_key | "durationSeconds" => _ |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: duration_seconds |  |  |  |  |

| `duration_seconds` | str_key | Map.get("duration_seconds") |  |  |  |  |

| `episodeId` | str_key | "episodeId" => _ |  |  |  |  |

| `episode_id` | str_key | episode_id: "dev_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `hypothesisRefs` | str_key | "hypothesisRefs" => _ |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: [] |  |  |  |  |

| `hypothesis_refs` | str_key | Keyword.get("hypothesis_refs") |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: Enum.sort(hypothesis_refs) |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: hypothesis_refs |  |  |  |  |

| `kind` | str_key | Map.get("kind") |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `label` | str_key | Map.get("label") |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `message` | str_key | message: "unknown devotional segment kind: #{inspect(value)}" |  |  |  |  |

| `playbackPolicy` | str_key | "playbackPolicy" => _ |  |  |  |  |

| `playback_policy` | str_key | playback_policy: :STRAIGHT_THROUGH |  |  |  |  |

| `position` | str_key | "position" => _ |  |  |  |  |

| `ref` | str_key | Map.get("ref") |  |  |  |  |

| `ref` | str_key | "ref" => _ |  |  |  |  |

| `segments` | str_key | segments: [] |  |  |  |  |

| `segments` | str_key | segments: normalized_segments |  |  |  |  |

| `segments` | str_key | "segments" => _ |  |  |  |  |

| `sourceRefs` | str_key | "sourceRefs" => _ |  |  |  |  |

| `source_refs` | str_key | source_refs: [] |  |  |  |  |

| `source_refs` | str_key | Keyword.get("source_refs") |  |  |  |  |

| `source_refs` | str_key | source_refs: Enum.sort(source_refs) |  |  |  |  |

| `source_refs` | str_key | source_refs: source_refs |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `status` | str_key | Keyword.get("status") |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `subtitle` | str_key | subtitle: Keyword.get(opts, :subtitle) |  |  |  |  |

| `subtitle` | str_key | Keyword.get("subtitle") |  |  |  |  |

| `subtitle` | str_key | subtitle: canonical.subtitle |  |  |  |  |

| `subtitle` | str_key | "subtitle" => _ |  |  |  |  |

| `title` | str_key | title: title |  |  |  |  |

| `title` | str_key | "title" => _ |  |  |  |  |

| `whyThisRef` | str_key | "whyThisRef" => _ |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: Keyword.get(opts, :why_this_ref) |  |  |  |  |

| `why_this_ref` | str_key | Keyword.get("why_this_ref") |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: canonical.why_this_ref |  |  |  |  |

| `AshSurface.DevotionalEpisode` | struct | defstruct episode_id, title, subtitle, why_this_ref, status, duration_seconds, completion_receipt_ref, state_digest, segments: [], hypothesis_refs: [], source_refs: [], playback_policy: :STRAIGHT_THROUGH, continuous_play: true, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.Digest

| `content_digest` | function | content_digest/1 |  |  |  |  |

| `deterministic_term_digest` | function | deterministic_term_digest/1 |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |


### AshSurface.DigestParityFixtures

| `document` | function | document/0 |  |  |  |  |

| `encode` | function | encode/0 |  |  |  |  |

| `output_path` | function | output_path/0 |  |  |  |  |

| `write!` | function | write!/0 |  |  |  |  |

| `AshSurface.Fixtures.VolunteerMilestone#record` | str_key | "AshSurface.Fixtures.VolunteerMilestone#record" => _ |  |  |  |  |

| `a` | str_key | "a" => _ |  |  |  |  |

| `action` | str_key | action: struct!(Action, Keyword.merge([name: name, type: type, custom: %{}], action_opts)) |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `actions` | str_key | Map.fetch!("actions") |  |  |  |  |

| `ash` | str_key | "ash" => _ |  |  |  |  |

| `audience` | str_key | "audience" => _ |  |  |  |  |

| `b` | str_key | "b" => _ |  |  |  |  |

| `bools` | str_key | "bools" => _ |  |  |  |  |

| `bounds` | str_key | "bounds" => _ |  |  |  |  |

| `capability` | str_key | "capability" => _ |  |  |  |  |

| `consequence` | str_key | "consequence" => _ |  |  |  |  |

| `consumer` | str_key | "consumer" => _ |  |  |  |  |

| `contract` | str_key | "contract" => _ |  |  |  |  |

| `cost_physical` | str_key | "cost_physical" => _ |  |  |  |  |

| `custom` | str_key | custom: %{} |  |  |  |  |

| `dispatchState` | str_key | "dispatchState" => _ |  |  |  |  |

| `elixirDigest` | str_key | "elixirDigest" => _ |  |  |  |  |

| `elixirEventId` | str_key | "elixirEventId" => _ |  |  |  |  |

| `elixirObservationId` | str_key | "elixirObservationId" => _ |  |  |  |  |

| `elixirReceiptHash` | str_key | "elixirReceiptHash" => _ |  |  |  |  |

| `elixirStateDigest` | str_key | "elixirStateDigest" => _ |  |  |  |  |

| `empty` | str_key | "empty" => _ |  |  |  |  |

| `empty_list` | str_key | "empty_list" => _ |  |  |  |  |

| `empty_map` | str_key | "empty_map" => _ |  |  |  |  |

| `entrypoints` | str_key | entrypoints: [entrypoint(AshSurface.Fixtures.VolunteerMilestone, :read, :read)] |  |  |  |  |

| `entrypoints` | str_key | entrypoints: [ entrypoint(AshSurface.Fixtures.VolunteerMilestone, :read, :read), entrypoint(AshSurface.Fixtures.VolunteerMilestone, :record, :create) ] |  |  |  |  |

| `event` | str_key | "event" => _ |  |  |  |  |

| `eventType` | str_key | "eventType" => _ |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `facts` | str_key | "facts" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `floats` | str_key | "floats" => _ |  |  |  |  |

| `floor` | str_key | "floor" => _ |  |  |  |  |

| `gap` | str_key | "gap" => _ |  |  |  |  |

| `generator` | str_key | "generator" => _ |  |  |  |  |

| `generatorIdentity` | str_key | "generatorIdentity" => _ |  |  |  |  |

| `glyph` | str_key | "glyph" => _ |  |  |  |  |

| `glyphs` | str_key | "glyphs" => _ |  |  |  |  |

| `group` | str_key | "group" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `int32min1` | str_key | "int32min1" => _ |  |  |  |  |

| `ir` | str_key | "ir" => _ |  |  |  |  |

| `l` | str_key | "l" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `lawVersion` | str_key | "lawVersion" => _ |  |  |  |  |

| `list` | str_key | "list" => _ |  |  |  |  |

| `m` | str_key | "m" => _ |  |  |  |  |

| `manifestDigest` | str_key | "manifestDigest" => _ |  |  |  |  |

| `manifestDigest` | str_key | Map.fetch!("manifestDigest") |  |  |  |  |

| `member_id` | str_key | "member_id" => _ |  |  |  |  |

| `meta` | str_key | "meta" => _ |  |  |  |  |

| `milestone_id` | str_key | "milestone_id" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `name` | str_key | name: name |  |  |  |  |

| `negBig` | str_key | "negBig" => _ |  |  |  |  |

| `negative` | str_key | "negative" => _ |  |  |  |  |

| `nested` | str_key | "nested" => _ |  |  |  |  |

| `note` | str_key | "note" => _ |  |  |  |  |

| `nλ` | str_key | "nλ" => _ |  |  |  |  |

| `observation` | str_key | "observation" => _ |  |  |  |  |

| `observed_at` | str_key | observed_at: @fixed_time |  |  |  |  |

| `occurred_at` | str_key | occurred_at: @fixed_time |  |  |  |  |

| `ok` | str_key | "ok" => _ |  |  |  |  |

| `order` | str_key | "order" => _ |  |  |  |  |

| `payload` | str_key | payload: e1_payload |  |  |  |  |

| `payload` | str_key | payload: e2_payload |  |  |  |  |

| `payload` | str_key | payload: %{} |  |  |  |  |

| `payload` | str_key | "payload" => _ |  |  |  |  |

| `possibleRefusals` | str_key | "possibleRefusals" => _ |  |  |  |  |

| `presentation` | str_key | "presentation" => _ |  |  |  |  |

| `profile` | str_key | profile: kiosk_profile |  |  |  |  |

| `profile` | str_key | profile: profile |  |  |  |  |

| `quota` | str_key | "quota" => _ |  |  |  |  |

| `ratio` | str_key | "ratio" => _ |  |  |  |  |

| `receipt` | str_key | "receipt" => _ |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `retries` | str_key | "retries" => _ |  |  |  |  |

| `reward_spiritual` | str_key | "reward_spiritual" => _ |  |  |  |  |

| `safeCeiling` | str_key | "safeCeiling" => _ |  |  |  |  |

| `schema` | str_key | "schema" => _ |  |  |  |  |

| `score` | str_key | "score" => _ |  |  |  |  |

| `sections` | str_key | "sections" => _ |  |  |  |  |

| `seen` | str_key | "seen" => _ |  |  |  |  |

| `selectedTransport` | str_key | "selectedTransport" => _ |  |  |  |  |

| `semantic` | str_key | "semantic" => _ |  |  |  |  |

| `sequence` | str_key | "sequence" => _ |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `surface` | str_key | Map.fetch!("surface") |  |  |  |  |

| `surfaceSchemaVersion` | str_key | "surfaceSchemaVersion" => _ |  |  |  |  |

| `tables` | str_key | "tables" => _ |  |  |  |  |

| `tags` | str_key | "tags" => _ |  |  |  |  |

| `timestamp` | str_key | "timestamp" => _ |  |  |  |  |

| `type` | str_key | type: type |  |  |  |  |

| `witnesses` | str_key | "witnesses" => _ |  |  |  |  |

| `Σ🜂#capability` | str_key | "Σ🜂#capability" => _ |  |  |  |  |


### AshSurface.Dsl.Projection

| `transport` | str_key | transport: :auto |  |  |  |  |

| `AshSurface.Dsl.Projection` | struct | defstruct action, consumer, __identifier__, __spark_metadata__, transport: :auto |  |  |  |  |


### AshSurface.Event

| `create` | function | create/4 |  |  |  |  |

| `from_receipt` | function | from_receipt/2 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `eventId` | str_key | "eventId" => _ |  |  |  |  |

| `eventType` | str_key | "eventType" => _ |  |  |  |  |

| `event_id` | str_key | event_id: String.t() |  |  |  |  |

| `event_id` | str_key | event_id: event_id |  |  |  |  |

| `event_type` | str_key | event_type: String.t() |  |  |  |  |

| `event_type` | str_key | event_type: event_type |  |  |  |  |

| `evidenceRef` | str_key | "evidenceRef" => _ |  |  |  |  |

| `evidence_ref` | str_key | evidence_ref: String.t() | nil |  |  |  |  |

| `evidence_ref` | str_key | Keyword.get("evidence_ref") |  |  |  |  |

| `evidence_ref` | str_key | evidence_ref: evidence_ref |  |  |  |  |

| `occurredAt` | str_key | "occurredAt" => _ |  |  |  |  |

| `occurred_at` | str_key | occurred_at: nil |  |  |  |  |

| `occurred_at` | str_key | occurred_at: DateTime.t() |  |  |  |  |

| `occurred_at` | str_key | Keyword.get("occurred_at") |  |  |  |  |

| `occurred_at` | str_key | occurred_at: occurred_at |  |  |  |  |

| `payload` | str_key | payload: map() | nil |  |  |  |  |

| `payload` | str_key | Keyword.get("payload") |  |  |  |  |

| `payload` | str_key | payload: payload |  |  |  |  |

| `payload` | str_key | "payload" => _ |  |  |  |  |

| `receiptRef` | str_key | "receiptRef" => _ |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: String.t() | nil |  |  |  |  |

| `receipt_ref` | str_key | Keyword.get("receipt_ref") |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: receipt_ref |  |  |  |  |

| `sequence` | str_key | sequence: non_neg_integer() |  |  |  |  |

| `sequence` | str_key | sequence: sequence |  |  |  |  |

| `sequence` | str_key | "sequence" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: String.t() |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `AshSurface.Event` | struct | defstruct event_id, sequence, subject_ref, event_type, state_digest, evidence_ref, receipt_ref, payload, occurred_at: nil, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ event_id: String.t(), sequence: non_neg_integer(), subject_ref: String.t(), event_type: String.t(), state_digest: String.t(), evidence_ref: String.t() | nil, receipt_ref: String.t() | nil, payload: map() | nil, occurred_at: DateTime.t(), authority_boundary: :OBSERVE } |  |  |  |  |


### AshSurface.Fixtures.Domain

| `validate_config_inclusion?` | str_key | validate_config_inclusion?: false |  |  |  |  |


### AshSurface.Fixtures.Server

| `get_port` | function | get_port/1 |  |  |  |  |

| `handle_call` | function | handle_call/3 |  |  |  |  |

| `init` | function | init/1 |  |  |  |  |

| `start_link` | function | start_link/1 |  |  |  |  |

| `stop` | function | stop/1 |  |  |  |  |

| `terminate` | function | terminate/2 |  |  |  |  |

| `acceptor_pid` | str_key | acceptor_pid: acceptor_pid |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `action` | str_key | action: :record |  |  |  |  |

| `active` | str_key | active: false |  |  |  |  |

| `body` | str_key | body: rest |  |  |  |  |

| `body` | str_key | body: new_body |  |  |  |  |

| `body` | str_key | body: body |  |  |  |  |

| `closed` | str_key | {:error, :closed} |  |  |  |  |

| `cost_physical` | str_key | "cost_physical" => _ |  |  |  |  |

| `data` | str_key | "data" => _ |  |  |  |  |

| `domain` | str_key | domain: AshSurface.Fixtures.Domain |  |  |  |  |

| `error` | str_key | "error" => _ |  |  |  |  |

| `headers` | str_key | headers: headers_part |  |  |  |  |

| `headers` | str_key | headers: headers |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `listen_socket` | str_key | listen_socket: listen_socket |  |  |  |  |

| `member_id` | str_key | "member_id" => _ |  |  |  |  |

| `milestone_id` | str_key | "milestone_id" => _ |  |  |  |  |

| `packet` | str_key | packet: :raw |  |  |  |  |

| `parts` | str_key | parts: 2 |  |  |  |  |

| `port` | str_key | port: port |  |  |  |  |

| `reuseaddr` | str_key | reuseaddr: true |  |  |  |  |

| `reward_spiritual` | str_key | "reward_spiritual" => _ |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `success` | str_key | "success" => _ |  |  |  |  |


### AshSurface.Fixtures.VolunteerMilestone

| `AshSurface.Fixtures.VolunteerMilestone` | ash_resource |  |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: false |  |  |  |  |

| `data_layer` | str_key | data_layer: Ash.DataLayer.Ets |  |  |  |  |

| `default` | str_key | default: "completed" |  |  |  |  |

| `domain` | str_key | domain: AshSurface.Fixtures.Domain |  |  |  |  |

| `public?` | str_key | public?: true |  |  |  |  |


### AshSurface.Health

| `check` | function | check/0 |  |  |  |  |

| `check_surface` | function | check_surface/2 |  |  |  |  |

| `ready?` | function | ready?/0 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `algorithm` | str_key | algorithm: @digest_algorithm |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `bytes` | str_key | bytes: bytes |  |  |  |  |

| `checkedAt` | str_key | "checkedAt" => _ |  |  |  |  |

| `checked_at` | str_key | checked_at: DateTime.t() |  |  |  |  |

| `checked_at` | str_key | checked_at: DateTime.utc_now() |  |  |  |  |

| `checked_at` | str_key | checked_at: %DateTime{} = checked_at |  |  |  |  |

| `checks` | str_key | checks: [check_result()] |  |  |  |  |

| `checks` | str_key | checks: checks |  |  |  |  |

| `checks` | str_key | "checks" => _ |  |  |  |  |

| `detail` | str_key | detail: term() |  |  |  |  |

| `detail` | str_key | detail: detail |  |  |  |  |

| `detail` | str_key | "detail" => _ |  |  |  |  |

| `detail` | str_key | detail: %{required: @required_apps, missing: missing} |  |  |  |  |

| `detail` | str_key | detail: %{selected: :http} |  |  |  |  |

| `detail` | str_key | detail: %{result: inspect(other)} |  |  |  |  |

| `detail` | str_key | detail: %{loaded: loaded?, generate_1_exported: exported?} |  |  |  |  |

| `detail` | str_key | detail: %{path: path, bytes: bytes} |  |  |  |  |

| `detail` | str_key | detail: %{path: path, reason: reason} |  |  |  |  |

| `detail` | str_key | detail: %{ stored: surface.digest, recomputed: recomputed, algorithm: @digest_algorithm } |  |  |  |  |

| `generate_1_exported` | str_key | generate_1_exported: exported? |  |  |  |  |

| `loaded` | str_key | loaded: loaded? |  |  |  |  |

| `missing` | str_key | missing: missing |  |  |  |  |

| `name` | str_key | name: atom() |  |  |  |  |

| `name` | str_key | name: name |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `name` | str_key | name: :applications_started |  |  |  |  |

| `name` | str_key | name: :transport_module |  |  |  |  |

| `name` | str_key | name: :ash_manifest_module |  |  |  |  |

| `name` | str_key | name: :runtime_present |  |  |  |  |

| `name` | str_key | name: :digest_integrity |  |  |  |  |

| `path` | str_key | path: path |  |  |  |  |

| `preferred` | str_key | preferred: :http |  |  |  |  |

| `reason` | str_key | reason: term() |  |  |  |  |

| `reason` | str_key | reason: :surface_struct_required |  |  |  |  |

| `reason` | str_key | reason: {:runtime_path_must_be_binary, other} |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `recomputed` | str_key | recomputed: recomputed |  |  |  |  |

| `required` | str_key | required: @required_apps |  |  |  |  |

| `result` | str_key | result: inspect(other) |  |  |  |  |

| `runtime_path` | str_key | Keyword.get("runtime_path") |  |  |  |  |

| `runtime_path` | str_key | Keyword.fetch("runtime_path") |  |  |  |  |

| `selected` | str_key | selected: :http |  |  |  |  |

| `size` | str_key | size: bytes |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_SUBJECT |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_OPTION |  |  |  |  |

| `status` | str_key | status: :ok | :error |  |  |  |  |

| `status` | str_key | status: :ok | :degraded |  |  |  |  |

| `status` | str_key | status: surface_status() |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `status` | str_key | status: if(missing == [], do: :ok, else: :error) |  |  |  |  |

| `status` | str_key | status: :ok |  |  |  |  |

| `status` | str_key | status: :error |  |  |  |  |

| `status` | str_key | status: if(exported?, do: :ok, else: :error) |  |  |  |  |

| `status` | str_key | status: if(recomputed == surface.digest, do: :ok, else: :error) |  |  |  |  |

| `stored` | str_key | stored: surface.digest |  |  |  |  |

| `subject` | str_key | subject: String.t() |  |  |  |  |

| `subject` | str_key | subject: surface.digest |  |  |  |  |

| `subject` | str_key | subject: subject |  |  |  |  |

| `subject` | str_key | "subject" => _ |  |  |  |  |

| `check_result` | type | @type check_result :: %{ name: atom(), status: :ok | :error, detail: term() } |  |  |  |  |

| `refusal` | type | @type refusal :: %{ standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION, reason: term(), authority_boundary: :OBSERVE } |  |  |  |  |

| `report` | type | @type report :: %{ status: :ok | :degraded, authority_boundary: :OBSERVE, checks: [check_result()], checked_at: DateTime.t() } |  |  |  |  |

| `surface_report` | type | @type surface_report :: %{ status: surface_status(), subject: String.t(), authority_boundary: :OBSERVE, checks: [check_result()] } |  |  |  |  |

| `surface_status` | type | @type surface_status :: :healthy | :missing_runtime | :digest_drift |  |  |  |  |


### AshSurface.HumanSurface

| `create` | function | create/2 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `__struct__` | str_key | __struct__: ^module |  |  |  |  |

| `areas` | str_key | areas: @areas |  |  |  |  |

| `areas` | str_key | "areas" => _ |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `bible` | str_key | Keyword.get("bible") |  |  |  |  |

| `bible` | str_key | bible: bible |  |  |  |  |

| `bible` | str_key | "bible" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `commitmentBoundaries` | str_key | "commitmentBoundaries" => _ |  |  |  |  |

| `commitmentBoundaryRefs` | str_key | "commitmentBoundaryRefs" => _ |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: [] |  |  |  |  |

| `commitment_boundaries` | str_key | Keyword.get("commitment_boundaries") |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: canonicalize(commitment_boundaries, &CommitmentBoundary.to_map/1, "boundaryId") |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: commitment_boundaries |  |  |  |  |

| `devotionalEpisodeRefs` | str_key | "devotionalEpisodeRefs" => _ |  |  |  |  |

| `devotionalEpisodes` | str_key | "devotionalEpisodes" => _ |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: [] |  |  |  |  |

| `devotional_episodes` | str_key | Keyword.get("devotional_episodes") |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: canonicalize(devotional_episodes, &DevotionalEpisode.to_map/1, "episodeId") |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: devotional_episodes |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `explanationRefs` | str_key | "explanationRefs" => _ |  |  |  |  |

| `explanations` | str_key | explanations: [] |  |  |  |  |

| `explanations` | str_key | Keyword.get("explanations") |  |  |  |  |

| `explanations` | str_key | explanations: canonicalize(explanations, &WhyThis.to_map/1, "explanationId") |  |  |  |  |

| `explanations` | str_key | explanations: explanations |  |  |  |  |

| `explanations` | str_key | "explanations" => _ |  |  |  |  |

| `grammar` | str_key | grammar: @grammar |  |  |  |  |

| `grammar` | str_key | "grammar" => _ |  |  |  |  |

| `journeyRefs` | str_key | "journeyRefs" => _ |  |  |  |  |

| `journeys` | str_key | journeys: [] |  |  |  |  |

| `journeys` | str_key | Keyword.get("journeys") |  |  |  |  |

| `journeys` | str_key | journeys: canonicalize(journeys, &Journey.to_map/1, "journeyId") |  |  |  |  |

| `journeys` | str_key | journeys: journeys |  |  |  |  |

| `journeys` | str_key | "journeys" => _ |  |  |  |  |

| `life` | str_key | Keyword.get("life") |  |  |  |  |

| `life` | str_key | life: life |  |  |  |  |

| `life` | str_key | "life" => _ |  |  |  |  |

| `manufactureTraceRefs` | str_key | "manufactureTraceRefs" => _ |  |  |  |  |

| `manufactureTraces` | str_key | "manufactureTraces" => _ |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: [] |  |  |  |  |

| `manufacture_traces` | str_key | Keyword.get("manufacture_traces") |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: canonicalize(manufacture_traces, &ManufactureTrace.to_map/1, "traceId") |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: manufacture_traces |  |  |  |  |

| `outcomeHypotheses` | str_key | "outcomeHypotheses" => _ |  |  |  |  |

| `outcomeHypothesisRefs` | str_key | "outcomeHypothesisRefs" => _ |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: [] |  |  |  |  |

| `outcome_hypotheses` | str_key | Keyword.get("outcome_hypotheses") |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: canonicalize(outcome_hypotheses, &OutcomeHypothesis.to_map/1, "hypothesisId") |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: outcome_hypotheses |  |  |  |  |

| `personalizationContextRefs` | str_key | "personalizationContextRefs" => _ |  |  |  |  |

| `personalizationContexts` | str_key | "personalizationContexts" => _ |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: [] |  |  |  |  |

| `personalization_contexts` | str_key | Keyword.get("personalization_contexts") |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: canonicalize(personalization_contexts, &PersonalizationContext.to_map/1, "contextId") |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: personalization_contexts |  |  |  |  |

| `possibilitySetRefs` | str_key | "possibilitySetRefs" => _ |  |  |  |  |

| `possibilitySets` | str_key | "possibilitySets" => _ |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: [] |  |  |  |  |

| `possibility_sets` | str_key | Keyword.get("possibility_sets") |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: canonicalize(possibility_sets, &PossibilitySet.to_map/1, "setId") |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: possibility_sets |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipt_refs) |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipt_refs |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `surfaceId` | str_key | "surfaceId" => _ |  |  |  |  |

| `surface_id` | str_key | surface_id: "hs_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `today` | str_key | Keyword.get("today") |  |  |  |  |

| `today` | str_key | today: today |  |  |  |  |

| `today` | str_key | "today" => _ |  |  |  |  |

| `you` | str_key | Keyword.get("you") |  |  |  |  |

| `you` | str_key | you: you |  |  |  |  |

| `you` | str_key | "you" => _ |  |  |  |  |

| `zoe` | str_key | Keyword.get("zoe") |  |  |  |  |

| `zoe` | str_key | zoe: zoe |  |  |  |  |

| `zoe` | str_key | "zoe" => _ |  |  |  |  |

| `AshSurface.HumanSurface` | struct | defstruct surface_id, exact_subject, state_digest, today, bible, life, zoe, you, possibility_sets: [], explanations: [], devotional_episodes: [], outcome_hypotheses: [], commitment_boundaries: [], journeys: [], personalization_contexts: [], manufacture_traces: [], evidence_refs: [], receipt_refs: [], standing: :PARTIAL_ALIVE, grammar: @grammar, areas: @areas, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.IR

| `delegated` | function | delegated/2 |  |  |  |  |

| `delegated_facts` | function | delegated_facts/0 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `section` | function | section/1 |  |  |  |  |

| `section` | function | section/2 |  |  |  |  |

| `sections` | function | sections/0 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action` | str_key | action: String.t() | atom() | nil |  |  |  |  |

| `action_type` | str_key | action_type: String.t() | atom() | nil |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `ash` | str_key | ash: __MODULE__.Ash.t() | nil |  |  |  |  |

| `ash` | str_key | ash: __MODULE__.Ash |  |  |  |  |

| `ash_surface` | str_key | ash_surface: section |  |  |  |  |

| `ash_surface` | str_key | "ash_surface" => _ |  |  |  |  |

| `bypass` | str_key | bypass: boolean() |  |  |  |  |

| `capability` | str_key | capability: __MODULE__.Capability.t() | nil |  |  |  |  |

| `capability` | str_key | capability: __MODULE__.Capability |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `check` | str_key | check: String.t() |  |  |  |  |

| `checks` | str_key | checks: [check()] |  |  |  |  |

| `conditions` | str_key | conditions: [condition()] |  |  |  |  |

| `custom` | str_key | custom: custom |  |  |  |  |

| `default` | str_key | default: term() |  |  |  |  |

| `digest` | str_key | digest: String.t() | nil |  |  |  |  |

| `format` | str_key | format: String.t() | nil |  |  |  |  |

| `group` | str_key | group: String.t() | nil |  |  |  |  |

| `input` | str_key | input: map() | nil |  |  |  |  |

| `inputs` | str_key | inputs: [map()] | map() | nil |  |  |  |  |

| `kind` | str_key | kind: atom() |  |  |  |  |

| `label` | str_key | label: String.t() | nil |  |  |  |  |

| `name` | str_key | name: atom() |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] | String.t() | nil |  |  |  |  |

| `opts` | str_key | opts: map() |  |  |  |  |

| `order` | str_key | order: non_neg_integer() | nil |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `outputs` | str_key | outputs: [map()] | map() | nil |  |  |  |  |

| `policies` | str_key | policies: [map()] | nil |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil |  |  |  |  |

| `presentation` | str_key | presentation: __MODULE__.Presentation.t() | nil |  |  |  |  |

| `presentation` | str_key | presentation: __MODULE__.Presentation |  |  |  |  |

| `profile` | str_key | profile: profile |  |  |  |  |

| `profile` | str_key | "profile" => _ |  |  |  |  |

| `required` | str_key | required: boolean() |  |  |  |  |

| `resource` | str_key | resource: module() | String.t() | nil |  |  |  |  |

| `returns` | str_key | returns: String.t() | nil |  |  |  |  |

| `schema` | str_key | schema: __MODULE__.Schema.t() | nil |  |  |  |  |

| `schema` | str_key | schema: __MODULE__.Schema |  |  |  |  |

| `semantic` | str_key | semantic: __MODULE__.Semantic.t() | nil |  |  |  |  |

| `semantic` | str_key | semantic: __MODULE__.Semantic |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `type` | str_key | type: String.t() |  |  |  |  |

| `version` | str_key | version: String.t() | nil |  |  |  |  |

| `widget` | str_key | widget: String.t() | atom() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() | nil |  |  |  |  |

| `AshSurface.IR` | struct | defstruct version, digest, ash, semantic, capability, presentation, schema |  |  |  |  |

| `section_name` | type | @type section_name :: :ash | :semantic | :capability | :presentation | :schema |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ version: String.t() | nil, digest: String.t() | nil, ash: __MODULE__.Ash.t() | nil, semantic: __MODULE__.Semantic.t() | nil, capability: __MODULE__.Capability.t() | nil, presentation: __MODULE__.Presentation.t() | nil, schema: __MODULE__.Schema.t() | nil } |  |  |  |  |


### AshSurface.IR.Capability

| `authority_required` | function | authority_required/1 |  |  |  |  |

| `authority_required` | str_key | authority_required: false |  |  |  |  |

| `authority_required` | str_key | authority_required: boolean() |  |  |  |  |

| `authority_required` | str_key | authority_required: required |  |  |  |  |

| `capability_id` | str_key | capability_id: String.t() | nil |  |  |  |  |

| `consequence_class` | str_key | consequence_class: String.t() | atom() | nil |  |  |  |  |

| `receipt_required` | str_key | receipt_required: false |  |  |  |  |

| `receipt_required` | str_key | receipt_required: boolean() |  |  |  |  |

| `AshSurface.IR.Capability` | struct | defstruct capability_id, consequence_class, authority_required: false, receipt_required: false |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ capability_id: String.t() | nil, consequence_class: String.t() | atom() | nil, authority_required: boolean(), receipt_required: boolean() } |  |  |  |  |


### AshSurface.IR.Codec

| `digest` | function | digest/1 |  |  |  |  |

| `from_map` | function | from_map/1 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `validate_facts` | function | validate_facts/1 |  |  |  |  |

| `ash` | str_key | "ash" => _ |  |  |  |  |

| `ash` | str_key | ash: build_section(map["ash"], IR.Ash, @ash_fields) |  |  |  |  |

| `capability` | str_key | "capability" => _ |  |  |  |  |

| `capability` | str_key | capability: build_section(map["capability"], IR.Capability, @capability_fields) |  |  |  |  |

| `digest` | str_key | digest: digest(to_map(ir)) |  |  |  |  |

| `invalid_fact` | str_key | {:error, {:invalid_fact, atom(), atom()}} |  |  |  |  |

| `invalid_fact` | str_key | {:error, {:invalid_fact, section, field}} |  |  |  |  |

| `ir_map_required` | str_key | {:error, {:ir_map_required, other}} |  |  |  |  |

| `missing_ir_sections` | str_key | {:error, {:missing_ir_sections, Enum.sort(missing)}} |  |  |  |  |

| `not_json_isomorphic` | str_key | {:error, {:not_json_isomorphic, section, value}} |  |  |  |  |

| `not_json_isomorphic` | str_key | {:error, {:not_json_isomorphic, section, k}} |  |  |  |  |

| `presentation` | str_key | "presentation" => _ |  |  |  |  |

| `presentation` | str_key | presentation: build_section(map["presentation"], IR.Presentation, @presentation_fields) |  |  |  |  |

| `schema` | str_key | "schema" => _ |  |  |  |  |

| `schema` | str_key | schema: build_section(map["schema"], IR.Schema, @schema_fields) |  |  |  |  |

| `section_must_be_map_or_nil` | str_key | {:error, {:section_must_be_map_or_nil, key, value}} |  |  |  |  |

| `semantic` | str_key | "semantic" => _ |  |  |  |  |

| `semantic` | str_key | semantic: build_section(map["semantic"], IR.Semantic, @semantic_fields) |  |  |  |  |

| `version` | str_key | "version" => _ |  |  |  |  |

| `version` | str_key | version: map["version"] |  |  |  |  |

| `version_must_be_string_or_nil` | str_key | {:error, {:version_must_be_string_or_nil, version}} |  |  |  |  |


### AshSurface.IR.EventProjection

| `from_receipt` | function | from_receipt/2 |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `consequence` | str_key | "consequence" => _ |  |  |  |  |

| `dispatchState` | str_key | "dispatchState" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `occurred_at` | str_key | occurred_at: occurred |  |  |  |  |

| `payload` | str_key | payload: fetch(receipt, [:consequence, "consequence"]) || %{} |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `reason` | str_key | reason: {:no_parseable_receipt_timestamp, raw} |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: fetch(receipt, [:receipt_hash, "receiptHash", :receipt_ref, "receiptRef"]) |  |  |  |  |

| `selectedTransport` | str_key | "selectedTransport" => _ |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_SUBJECT |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_MISSING_TIMESTAMP |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_RECEIPT_DIGEST_MISMATCH |  |  |  |  |

| `timestamp` | str_key | "timestamp" => _ |  |  |  |  |

| `ir_action` | type | @type ir_action :: %{ optional(:resource) => String.t(), optional(:action) => String.t(), optional(:semantic) => semantic(), # JSON-decoded receipts/actions arrive with string keys; every key # above is read through both spellings (see `fetch/2`). optional(String.t()) => term() } |  |  |  |  |

| `receipt` | type | @type receipt :: map() |  |  |  |  |

| `refusal` | type | @type refusal :: %{ required(:standing) => atom(), required(:reason) => term(), required(:authority_boundary) => :OBSERVE } |  |  |  |  |

| `semantic` | type | @type semantic :: %{ optional(:subject_iri) => String.t() | nil, optional(String.t()) => term() } |  |  |  |  |


### AshSurface.Idempotency

| `admit` | function | admit/3 |  |  |  |  |

| `complete` | function | complete/4 |  |  |  |  |

| `derive_key` | function | derive_key/2 |  |  |  |  |

| `protocol` | function | protocol/0 |  |  |  |  |

| `request_digest` | function | request_digest/2 |  |  |  |  |

| `reserve` | function | reserve/3 |  |  |  |  |

| `valid_key?` | function | valid_key?/1 |  |  |  |  |

| `validate_key` | function | validate_key/1 |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `already_completed` | str_key | {:error, :already_completed} |  |  |  |  |

| `commandId` | str_key | "commandId" => _ |  |  |  |  |

| `digest` | str_key | digest: String.t() |  |  |  |  |

| `digest` | str_key | digest: recorded |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `digest_mismatch` | str_key | {:error, :digest_mismatch} |  |  |  |  |

| `ik_` | str_key | "ik_" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `invalid_key` | str_key | {:error, :invalid_key} |  |  |  |  |

| `invalid_utf8` | str_key | {:error, {:invalid_utf8, Enum.reverse(path)}} |  |  |  |  |

| `non_string_key` | str_key | {:error, {:non_string_key, Enum.reverse(path)}} |  |  |  |  |

| `not_a_string` | str_key | {:error, :not_a_string} |  |  |  |  |

| `not_first` | str_key | {:error, {:not_first, admission()}} |  |  |  |  |

| `not_first` | str_key | {:error, {:not_first, other}} |  |  |  |  |

| `not_portable` | str_key | {:error, {:not_portable, Enum.reverse(path)}} |  |  |  |  |

| `not_reserved` | str_key | {:error, :not_reserved} |  |  |  |  |

| `outcome` | str_key | outcome: :pending | {:done, term()} |  |  |  |  |

| `outcome` | str_key | outcome: :pending |  |  |  |  |

| `outcome` | str_key | outcome: {:done, outcome} |  |  |  |  |

| `outcome` | str_key | outcome: {:done, _} |  |  |  |  |

| `unsafe_integer` | str_key | {:error, {:unsafe_integer, Enum.reverse(path)}} |  |  |  |  |

| `admission` | type | @type admission :: :first | {:replay, term()} | {:conflict, :digest_mismatch | :in_flight} |  |  |  |  |

| `entry` | type | @type entry :: %{digest: String.t(), outcome: :pending | {:done, term()}} |  |  |  |  |

| `state` | type | @type state :: %{optional(String.t()) => entry()} |  |  |  |  |


### AshSurface.Intent

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `createdAt` | str_key | "createdAt" => _ |  |  |  |  |

| `created_at` | str_key | created_at: DateTime.t() |  |  |  |  |

| `created_at` | str_key | Keyword.get("created_at") |  |  |  |  |

| `created_at` | str_key | created_at: created_at |  |  |  |  |

| `input` | str_key | input: map() |  |  |  |  |

| `input` | str_key | input: input |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `intentId` | str_key | "intentId" => _ |  |  |  |  |

| `intent_id` | str_key | intent_id: String.t() |  |  |  |  |

| `intent_id` | str_key | intent_id: intent_id |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: String.t() |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `surfaceActionId` | str_key | "surfaceActionId" => _ |  |  |  |  |

| `surface_action_id` | str_key | surface_action_id: String.t() |  |  |  |  |

| `surface_action_id` | str_key | surface_action_id: surface_action_id |  |  |  |  |

| `AshSurface.Intent` | struct | defstruct surface_action_id, input, subject_ref, created_at, intent_id |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ surface_action_id: String.t(), input: map(), subject_ref: String.t(), created_at: DateTime.t(), intent_id: String.t() } |  |  |  |  |


### AshSurface.Intent.Candidate

| `to_candidate` | function | to_candidate/2 |  |  |  |  |


### AshSurface.Intent.Dispatch

| `submit` | function | submit/3 |  |  |  |  |

| `REFUSED_NO_COMMAND_BUS` | str_key | {:error, :REFUSED_NO_COMMAND_BUS} |  |  |  |  |

| `REFUSED_UNKNOWN_ACTION` | str_key | {:error, :REFUSED_UNKNOWN_ACTION} |  |  |  |  |

| `action_id` | str_key | Map.get("action_id") |  |  |  |  |

| `action_id` | str_key | action_id: candidate_map.action_id |  |  |  |  |

| `admitted_action_ids` | str_key | Map.fetch("admitted_action_ids") |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, :missing_action_id}} |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, :invalid_action_id}} |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, :candidate_must_be_a_map}} |  |  |  |  |

| `invalid_context` | str_key | {:error, {:invalid_context, :admitted_action_ids_must_be_a_list_of_strings}} |  |  |  |  |

| `payload` | str_key | payload: Map.delete(candidate_map, :action_id) |  |  |  |  |


### AshSurface.Intent.Envelope

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `payload` | str_key | payload: map() |  |  |  |  |

| `AshSurface.Intent.Envelope` | struct | defstruct action_id, payload |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t(), payload: map() } |  |  |  |  |


### AshSurface.Intent.IR

| `create` | function | create/3 |  |  |  |  |

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `action_id` | str_key | action_id: action_id |  |  |  |  |

| `capability` | str_key | capability: section() |  |  |  |  |

| `capability` | str_key | capability: capability |  |  |  |  |

| `semantic` | str_key | semantic: section() |  |  |  |  |

| `semantic` | str_key | semantic: semantic |  |  |  |  |

| `AshSurface.Intent.IR` | struct | defstruct action_id, capability, semantic |  |  |  |  |

| `section` | type | @type section :: map() | nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t(), capability: section(), semantic: section() } |  |  |  |  |


### AshSurface.Journey

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `entries` | str_key | entries: [] |  |  |  |  |

| `entries` | str_key | entries: normalized |  |  |  |  |

| `entries` | str_key | "entries" => _ |  |  |  |  |

| `entryId` | str_key | "entryId" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceRefs` | str_key | Map.get("evidenceRefs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | Map.get("evidence_refs") |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `journeyId` | str_key | "journeyId" => _ |  |  |  |  |

| `journey_id` | str_key | journey_id: "journey_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `occurredAt` | str_key | "occurredAt" => _ |  |  |  |  |

| `privacyScope` | str_key | "privacyScope" => _ |  |  |  |  |

| `privacy_scope` | str_key | privacy_scope: :SUBJECT_PRIVATE |  |  |  |  |

| `receiptRef` | str_key | Map.get("receiptRef") |  |  |  |  |

| `receiptRef` | str_key | "receiptRef" => _ |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_ref` | str_key | Map.get("receipt_ref") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipt_refs) |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipt_refs |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `standing` | str_key | Map.get("standing") |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `AshSurface.Journey` | struct | defstruct journey_id, exact_subject, state_digest, entries: [], evidence_refs: [], receipt_refs: [], privacy_scope: :SUBJECT_PRIVATE, standing: :PARTIAL_ALIVE, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.MXEpisode

| `calver` | function | calver/0 |  |  |  |  |

| `compose` | function | compose/1 |  |  |  |  |

| `required_fields` | function | required_fields/0 |  |  |  |  |

| `selected_decomposition` | function | selected_decomposition/0 |  |  |  |  |

| `validate` | function | validate/1 |  |  |  |  |

| `verifier_path` | function | verifier_path/0 |  |  |  |  |

| `verify` | function | verify/2 |  |  |  |  |

| `verify_file` | function | verify_file/2 |  |  |  |  |

| `args` | str_key | args: [verifier_path(), episode_path] |  |  |  |  |

| `authority_ceiling` | str_key | "authority_ceiling" => _ |  |  |  |  |

| `calver_mismatch` | str_key | {:error, {:calver_mismatch, name, value}} |  |  |  |  |

| `compose_input_must_be_a_map` | str_key | {:error, {:compose_input_must_be_a_map, input}} |  |  |  |  |

| `consequence_id` | str_key | "consequence_id" => _ |  |  |  |  |

| `cost_score` | str_key | "cost_score" => _ |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `domain_version` | str_key | "domain_version" => _ |  |  |  |  |

| `episode_id` | str_key | "episode_id" => _ |  |  |  |  |

| `episode_must_be_a_map` | str_key | {:error, :episode_must_be_a_map} |  |  |  |  |

| `episode_must_be_a_map` | str_key | {:error, {:episode_must_be_a_map, episode}} |  |  |  |  |

| `episode_not_json_encodable` | str_key | {:error, {:episode_not_json_encodable, reason}} |  |  |  |  |

| `episode_not_json_encodable` | str_key | {:error, {:episode_not_json_encodable, error}} |  |  |  |  |

| `event_id` | str_key | "event_id" => _ |  |  |  |  |

| `fond_version` | str_key | "fond_version" => _ |  |  |  |  |

| `hddl_version` | str_key | "hddl_version" => _ |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, key, module}} |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, key, {:expected_binary, value}}} |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, :cost_score, {:expected_number, other}}} |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, :episode_id, {:expected_binary, other}}} |  |  |  |  |

| `invalid_standing` | str_key | {:error, {:invalid_standing, value}} |  |  |  |  |

| `invalid_standing` | str_key | {:error, {:invalid_standing, standing}} |  |  |  |  |

| `invalid_surface_digest` | str_key | {:error, {:invalid_surface_digest, digest}} |  |  |  |  |

| `invalid_verifier_timeout` | str_key | {:error, {:invalid_verifier_timeout, timeout}} |  |  |  |  |

| `marketplace_identity` | str_key | "marketplace_identity" => _ |  |  |  |  |

| `missing_compose_fields` | str_key | {:error, {:missing_compose_fields, missing}} |  |  |  |  |

| `missing_compose_fields` | str_key | {:error, {:missing_compose_fields, [key]}} |  |  |  |  |

| `missing_fields` | str_key | {:error, {:missing_fields, missing}} |  |  |  |  |

| `observed_transitions` | str_key | "observed_transitions" => _ |  |  |  |  |

| `outcome` | str_key | "outcome" => _ |  |  |  |  |

| `padding` | str_key | padding: false |  |  |  |  |

| `pattern_version` | str_key | "pattern_version" => _ |  |  |  |  |

| `planning_episode_id` | str_key | "planning_episode_id" => _ |  |  |  |  |

| `receipt_hash` | str_key | "receipt_hash" => _ |  |  |  |  |

| `resulting_standing` | str_key | "resulting_standing" => _ |  |  |  |  |

| `resulting_standing` | str_key | Map.get("resulting_standing") |  |  |  |  |

| `selected_decomposition` | str_key | "selected_decomposition" => _ |  |  |  |  |

| `state_digest` | str_key | "state_digest" => _ |  |  |  |  |

| `stderr_to_stdout` | str_key | stderr_to_stdout: true |  |  |  |  |

| `step` | str_key | "step" => _ |  |  |  |  |

| `subject_binding_violation` | str_key | {:error, {:subject_binding_violation, event.subject_ref}} |  |  |  |  |

| `subject_head` | str_key | "subject_head" => _ |  |  |  |  |

| `subject_ref` | str_key | "subject_ref" => _ |  |  |  |  |

| `subject_repo` | str_key | "subject_repo" => _ |  |  |  |  |

| `surface_digest` | str_key | "surface_digest" => _ |  |  |  |  |

| `timeout` | str_key | Keyword.get("timeout") |  |  |  |  |

| `verifier_failed` | str_key | {:error, {:verifier_failed, exit_code, output}} |  |  |  |  |

| `verifier_python_not_found` | str_key | {:error, :verifier_python_not_found} |  |  |  |  |

| `verifier_timeout` | str_key | {:error, {:verifier_timeout, timeout}} |  |  |  |  |

| `verifier_tmp_unwritable` | str_key | {:error, {:verifier_tmp_unwritable, tmp_path, reason}} |  |  |  |  |

| `verifier_unparseable` | str_key | {:error, {:verifier_unparseable, exit_code, output}} |  |  |  |  |

| `verifier_version` | str_key | "verifier_version" => _ |  |  |  |  |

| `episode` | type | @type episode :: %{optional(String.t()) => term()} |  |  |  |  |

| `verify_result` | type | @type verify_result :: {:ok, :valid} | {:error, {code :: String.t(), message :: String.t()}} | {:error, term()} |  |  |  |  |


### AshSurface.ManufactureTrace

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `admittedRefs` | str_key | "admittedRefs" => _ |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: [] |  |  |  |  |

| `admitted_refs` | str_key | Keyword.get("admitted_refs") |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: admitted |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: Enum.sort(admitted) |  |  |  |  |

| `alignedRefs` | str_key | "alignedRefs" => _ |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: [] |  |  |  |  |

| `aligned_refs` | str_key | Keyword.get("aligned_refs") |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: aligned |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: Enum.sort(aligned) |  |  |  |  |

| `artifactRef` | str_key | "artifactRef" => _ |  |  |  |  |

| `artifact_ref` | str_key | artifact_ref: artifact_ref |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `boundedRefs` | str_key | "boundedRefs" => _ |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: [] |  |  |  |  |

| `bounded_refs` | str_key | Keyword.get("bounded_refs") |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: bounded |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: Enum.sort(bounded) |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `equation` | str_key | "equation" => _ |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `falsifiers` | str_key | falsifiers: [] |  |  |  |  |

| `falsifiers` | str_key | Keyword.get("falsifiers") |  |  |  |  |

| `falsifiers` | str_key | falsifiers: falsifiers |  |  |  |  |

| `falsifiers` | str_key | falsifiers: Enum.sort(falsifiers) |  |  |  |  |

| `falsifiers` | str_key | "falsifiers" => _ |  |  |  |  |

| `groundedRefs` | str_key | "groundedRefs" => _ |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: [] |  |  |  |  |

| `grounded_refs` | str_key | Keyword.get("grounded_refs") |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: grounded |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: Enum.sort(grounded) |  |  |  |  |

| `humanSummary` | str_key | "humanSummary" => _ |  |  |  |  |

| `human_summary` | str_key | human_summary: Keyword.get(opts, :human_summary) |  |  |  |  |

| `human_summary` | str_key | Keyword.get("human_summary") |  |  |  |  |

| `human_summary` | str_key | human_summary: canonical.human_summary |  |  |  |  |

| `manufacturerIdentity` | str_key | "manufacturerIdentity" => _ |  |  |  |  |

| `manufacturer_identity` | str_key | manufacturer_identity: manufacturer_identity |  |  |  |  |

| `oStarRefs` | str_key | "oStarRefs" => _ |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: [] |  |  |  |  |

| `o_star_refs` | str_key | Keyword.get("o_star_refs") |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: o_star |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: Enum.sort(o_star) |  |  |  |  |

| `observedRefs` | str_key | "observedRefs" => _ |  |  |  |  |

| `observed_refs` | str_key | observed_refs: [] |  |  |  |  |

| `observed_refs` | str_key | Keyword.get("observed_refs") |  |  |  |  |

| `observed_refs` | str_key | observed_refs: observed |  |  |  |  |

| `observed_refs` | str_key | observed_refs: Enum.sort(observed) |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipts |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipts) |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `traceId` | str_key | "traceId" => _ |  |  |  |  |

| `trace_id` | str_key | trace_id: "mt_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `AshSurface.ManufactureTrace` | struct | defstruct trace_id, exact_subject, artifact_ref, manufacturer_identity, human_summary, state_digest, observed_refs: [], admitted_refs: [], grounded_refs: [], bounded_refs: [], aligned_refs: [], o_star_refs: [], receipt_refs: [], falsifiers: [], standing: :PARTIAL_ALIVE, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.Obligation

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `assignedTo` | str_key | "assignedTo" => _ |  |  |  |  |

| `assigned_to` | str_key | assigned_to: String.t() | nil |  |  |  |  |

| `assigned_to` | str_key | Keyword.get("assigned_to") |  |  |  |  |

| `assigned_to` | str_key | assigned_to: assigned_to |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `capabilityId` | str_key | "capabilityId" => _ |  |  |  |  |

| `capability_id` | str_key | capability_id: String.t() |  |  |  |  |

| `capability_id` | str_key | capability_id: capability_id |  |  |  |  |

| `causeRef` | str_key | "causeRef" => _ |  |  |  |  |

| `cause_ref` | str_key | cause_ref: String.t() |  |  |  |  |

| `cause_ref` | str_key | cause_ref: cause_ref |  |  |  |  |

| `escalationPath` | str_key | "escalationPath" => _ |  |  |  |  |

| `escalation_path` | str_key | escalation_path: [] |  |  |  |  |

| `escalation_path` | str_key | escalation_path: [String.t()] |  |  |  |  |

| `escalation_path` | str_key | Keyword.get("escalation_path") |  |  |  |  |

| `escalation_path` | str_key | escalation_path: escalation_path |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [String.t()] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: String.t() |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `obligationId` | str_key | "obligationId" => _ |  |  |  |  |

| `obligation_id` | str_key | obligation_id: String.t() |  |  |  |  |

| `obligation_id` | str_key | obligation_id: "obl_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `postconditionRef` | str_key | "postconditionRef" => _ |  |  |  |  |

| `postcondition_ref` | str_key | postcondition_ref: String.t() | nil |  |  |  |  |

| `postcondition_ref` | str_key | Keyword.get("postcondition_ref") |  |  |  |  |

| `postcondition_ref` | str_key | postcondition_ref: postcondition_ref |  |  |  |  |

| `receiptRef` | str_key | "receiptRef" => _ |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: String.t() | nil |  |  |  |  |

| `receipt_ref` | str_key | Keyword.get("receipt_ref") |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: receipt_ref |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `status` | str_key | status: status() |  |  |  |  |

| `status` | str_key | Keyword.get("status") |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `AshSurface.Obligation` | struct | defstruct obligation_id, exact_subject, capability_id, cause_ref, status, state_digest, assigned_to, receipt_ref, postcondition_ref, escalation_path: [], evidence_refs: [], authority_boundary: :OBSERVE |  |  |  |  |

| `status` | type | @type status :: :open | :assigned | :acknowledged | :executing | :resolved | :blocked | :unknown |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ obligation_id: String.t(), exact_subject: String.t(), capability_id: String.t(), cause_ref: String.t(), status: status(), state_digest: String.t(), assigned_to: String.t() | nil, receipt_ref: String.t() | nil, postcondition_ref: String.t() | nil, escalation_path: [String.t()], evidence_refs: [String.t()], authority_boundary: :OBSERVE } |  |  |  |  |


### AshSurface.Observation

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [String.t()] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: String.t() |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `facts` | str_key | facts: map() |  |  |  |  |

| `facts` | str_key | facts: facts |  |  |  |  |

| `facts` | str_key | "facts" => _ |  |  |  |  |

| `observationId` | str_key | "observationId" => _ |  |  |  |  |

| `observation_id` | str_key | observation_id: String.t() |  |  |  |  |

| `observation_id` | str_key | observation_id: observation_id |  |  |  |  |

| `observedAt` | str_key | "observedAt" => _ |  |  |  |  |

| `observed_at` | str_key | observed_at: DateTime.t() |  |  |  |  |

| `observed_at` | str_key | Keyword.get("observed_at") |  |  |  |  |

| `observed_at` | str_key | observed_at: observed_at |  |  |  |  |

| `projectionPurpose` | str_key | "projectionPurpose" => _ |  |  |  |  |

| `projection_purpose` | str_key | projection_purpose: "consumer_state_observation" |  |  |  |  |

| `projection_purpose` | str_key | projection_purpose: String.t() |  |  |  |  |

| `projection_purpose` | str_key | Keyword.get("projection_purpose") |  |  |  |  |

| `projection_purpose` | str_key | projection_purpose: purpose |  |  |  |  |

| `standing` | str_key | standing: :ALIVE |  |  |  |  |

| `standing` | str_key | standing: AshSurface.Standing.t() |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `AshSurface.Observation` | struct | defstruct observation_id, exact_subject, observed_at, state_digest, facts, evidence_refs: [], standing: :ALIVE, projection_purpose: "consumer_state_observation", authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ observation_id: String.t(), exact_subject: String.t(), observed_at: DateTime.t(), state_digest: String.t(), facts: map(), evidence_refs: [String.t()], standing: AshSurface.Standing.t(), projection_purpose: String.t(), authority_boundary: :OBSERVE } |  |  |  |  |


### AshSurface.OutcomeHypothesis

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `causalClaim` | str_key | "causalClaim" => _ |  |  |  |  |

| `causal_claim` | str_key | causal_claim: false |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceState` | str_key | "evidenceState" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_state` | str_key | evidence_state: :UNKNOWN |  |  |  |  |

| `evidence_state` | str_key | Keyword.get("evidence_state") |  |  |  |  |

| `evidence_state` | str_key | evidence_state: evidence_state |  |  |  |  |

| `falsifier` | str_key | Keyword.fetch!("falsifier") |  |  |  |  |

| `falsifier` | str_key | falsifier: falsifier |  |  |  |  |

| `falsifier` | str_key | "falsifier" => _ |  |  |  |  |

| `horizon` | str_key | horizon: Keyword.get(opts, :horizon) |  |  |  |  |

| `horizon` | str_key | Keyword.get("horizon") |  |  |  |  |

| `horizon` | str_key | horizon: canonical.horizon |  |  |  |  |

| `horizon` | str_key | "horizon" => _ |  |  |  |  |

| `hypothesisId` | str_key | "hypothesisId" => _ |  |  |  |  |

| `hypothesis_id` | str_key | hypothesis_id: "hyp_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `observationRefs` | str_key | "observationRefs" => _ |  |  |  |  |

| `observation_refs` | str_key | observation_refs: [] |  |  |  |  |

| `observation_refs` | str_key | Keyword.get("observation_refs") |  |  |  |  |

| `observation_refs` | str_key | observation_refs: Enum.sort(observation_refs) |  |  |  |  |

| `observation_refs` | str_key | observation_refs: observation_refs |  |  |  |  |

| `outcomeRef` | str_key | "outcomeRef" => _ |  |  |  |  |

| `outcome_ref` | str_key | outcome_ref: outcome_ref |  |  |  |  |

| `practiceRef` | str_key | "practiceRef" => _ |  |  |  |  |

| `practice_ref` | str_key | practice_ref: practice_ref |  |  |  |  |

| `relationship` | str_key | Keyword.get("relationship") |  |  |  |  |

| `relationship` | str_key | relationship: relationship |  |  |  |  |

| `relationship` | str_key | "relationship" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `AshSurface.OutcomeHypothesis` | struct | defstruct hypothesis_id, subject_ref, practice_ref, outcome_ref, relationship, falsifier, horizon, state_digest, evidence_state: :UNKNOWN, evidence_refs: [], observation_refs: [], causal_claim: false, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.PersonalizationContext

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `consentRef` | str_key | "consentRef" => _ |  |  |  |  |

| `consent_ref` | str_key | Keyword.get("consent_ref") |  |  |  |  |

| `consent_ref` | str_key | consent_ref: consent_ref |  |  |  |  |

| `contextId` | str_key | "contextId" => _ |  |  |  |  |

| `context_id` | str_key | context_id: "pc_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `dimension` | str_key | "dimension" => _ |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceRefs` | str_key | Map.get("evidenceRefs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | Map.get("evidence_refs") |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `facetId` | str_key | "facetId" => _ |  |  |  |  |

| `facets` | str_key | facets: [] |  |  |  |  |

| `facets` | str_key | facets: normalized |  |  |  |  |

| `facets` | str_key | "facets" => _ |  |  |  |  |

| `falsifier` | str_key | Map.get("falsifier") |  |  |  |  |

| `falsifier` | str_key | "falsifier" => _ |  |  |  |  |

| `privacyScope` | str_key | "privacyScope" => _ |  |  |  |  |

| `privacy_scope` | str_key | privacy_scope: :SUBJECT_PRIVATE |  |  |  |  |

| `shareScope` | str_key | "shareScope" => _ |  |  |  |  |

| `share_scope` | str_key | share_scope: :SUBJECT_ONLY |  |  |  |  |

| `source` | str_key | "source" => _ |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `standing` | str_key | Map.get("standing") |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `valueRef` | str_key | "valueRef" => _ |  |  |  |  |

| `AshSurface.PersonalizationContext` | struct | defstruct context_id, exact_subject, state_digest, consent_ref, facets: [], evidence_refs: [], standing: :PARTIAL_ALIVE, privacy_scope: :SUBJECT_PRIVATE, share_scope: :SUBJECT_ONLY, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.PlanningEpisode

| `create` | function | create/2 |  |  |  |  |

| `digest` | function | digest/1 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityCeiling` | str_key | "authorityCeiling" => _ |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :SELECT |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :SELECT | :CONSTRUCT |  |  |  |  |

| `authority_ceiling` | str_key | Keyword.get("authority_ceiling") |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: ceiling |  |  |  |  |

| `candidateActions` | str_key | "candidateActions" => _ |  |  |  |  |

| `candidate_actions` | str_key | candidate_actions: [] |  |  |  |  |

| `candidate_actions` | str_key | candidate_actions: [map()] |  |  |  |  |

| `candidate_actions` | str_key | Keyword.get("candidate_actions") |  |  |  |  |

| `candidate_actions` | str_key | candidate_actions: candidates |  |  |  |  |

| `episodeId` | str_key | "episodeId" => _ |  |  |  |  |

| `episode_id` | str_key | episode_id: String.t() |  |  |  |  |

| `episode_id` | str_key | episode_id: "" |  |  |  |  |

| `episode_id` | str_key | episode_id: "ep_" <> binary_part(digest, 0, 16) |  |  |  |  |

| `plannerIdentity` | str_key | "plannerIdentity" => _ |  |  |  |  |

| `planner_identity` | str_key | planner_identity: String.t() |  |  |  |  |

| `planner_identity` | str_key | Keyword.fetch!("planner_identity") |  |  |  |  |

| `planner_identity` | str_key | planner_identity: planner |  |  |  |  |

| `policyIdentity` | str_key | "policyIdentity" => _ |  |  |  |  |

| `policyStanding` | str_key | "policyStanding" => _ |  |  |  |  |

| `policy_identity` | str_key | policy_identity: String.t() |  |  |  |  |

| `policy_identity` | str_key | Keyword.fetch!("policy_identity") |  |  |  |  |

| `policy_identity` | str_key | policy_identity: policy |  |  |  |  |

| `policy_standing` | str_key | policy_standing: :VALID_STRONG |  |  |  |  |

| `policy_standing` | str_key | policy_standing: standing() |  |  |  |  |

| `policy_standing` | str_key | Keyword.get("policy_standing") |  |  |  |  |

| `policy_standing` | str_key | policy_standing: standing |  |  |  |  |

| `taskNetworkRef` | str_key | "taskNetworkRef" => _ |  |  |  |  |

| `task_network_ref` | str_key | task_network_ref: String.t() | nil |  |  |  |  |

| `task_network_ref` | str_key | Keyword.get("task_network_ref") |  |  |  |  |

| `task_network_ref` | str_key | task_network_ref: task_network |  |  |  |  |

| `worldStateRef` | str_key | "worldStateRef" => _ |  |  |  |  |

| `world_state_ref` | str_key | world_state_ref: String.t() |  |  |  |  |

| `world_state_ref` | str_key | world_state_ref: world_state_ref |  |  |  |  |

| `AshSurface.PlanningEpisode` | struct | defstruct episode_id, world_state_ref, task_network_ref, planner_identity, policy_identity, policy_standing: :VALID_STRONG, candidate_actions: [], authority_ceiling: :SELECT |  |  |  |  |

| `standing` | type | @type standing :: :VALID_STRONG | :VALID_STRONG_CYCLIC | :REFUSED |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ episode_id: String.t(), world_state_ref: String.t(), task_network_ref: String.t() | nil, planner_identity: String.t(), policy_identity: String.t(), policy_standing: standing(), candidate_actions: [map()], authority_ceiling: :SELECT | :CONSTRUCT } |  |  |  |  |


### AshSurface.Possibility

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `actionRef` | str_key | "actionRef" => _ |  |  |  |  |

| `action_ref` | str_key | Keyword.get("action_ref") |  |  |  |  |

| `action_ref` | str_key | action_ref: action_ref |  |  |  |  |

| `authorityCeiling` | str_key | "authorityCeiling" => _ |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :SELECT |  |  |  |  |

| `authority_ceiling` | str_key | Keyword.get("authority_ceiling") |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: ceiling |  |  |  |  |

| `capabilityId` | str_key | "capabilityId" => _ |  |  |  |  |

| `capability_id` | str_key | capability_id: capability_id |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `consequenceSummary` | str_key | "consequenceSummary" => _ |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: Keyword.get(opts, :consequence_summary) |  |  |  |  |

| `consequence_summary` | str_key | Keyword.get("consequence_summary") |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: canonical.consequence_summary |  |  |  |  |

| `costSummary` | str_key | "costSummary" => _ |  |  |  |  |

| `cost_summary` | str_key | cost_summary: Keyword.get(opts, :cost_summary) |  |  |  |  |

| `cost_summary` | str_key | Keyword.get("cost_summary") |  |  |  |  |

| `cost_summary` | str_key | cost_summary: canonical.cost_summary |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `expiresAt` | str_key | "expiresAt" => _ |  |  |  |  |

| `expires_at` | str_key | expires_at: normalize_datetime(Keyword.get(opts, :expires_at)) |  |  |  |  |

| `expires_at` | str_key | Keyword.get("expires_at") |  |  |  |  |

| `expires_at` | str_key | expires_at: Keyword.get(opts, :expires_at) |  |  |  |  |

| `label` | str_key | label: label |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `possibilityId` | str_key | "possibilityId" => _ |  |  |  |  |

| `possibility_id` | str_key | possibility_id: "pos_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `requirements` | str_key | requirements: [] |  |  |  |  |

| `requirements` | str_key | Keyword.get("requirements") |  |  |  |  |

| `requirements` | str_key | requirements: Enum.sort(requirements) |  |  |  |  |

| `requirements` | str_key | requirements: requirements |  |  |  |  |

| `requirements` | str_key | "requirements" => _ |  |  |  |  |

| `reversibility` | str_key | Keyword.get("reversibility") |  |  |  |  |

| `reversibility` | str_key | reversibility: reversibility |  |  |  |  |

| `reversibility` | str_key | "reversibility" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `status` | str_key | Keyword.get("status") |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `summary` | str_key | summary: Keyword.get(opts, :summary) |  |  |  |  |

| `summary` | str_key | Keyword.get("summary") |  |  |  |  |

| `summary` | str_key | summary: canonical.summary |  |  |  |  |

| `summary` | str_key | "summary" => _ |  |  |  |  |

| `whyThisRef` | str_key | "whyThisRef" => _ |  |  |  |  |

| `why_this_ref` | str_key | Keyword.get("why_this_ref") |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: why_this_ref |  |  |  |  |

| `AshSurface.Possibility` | struct | defstruct possibility_id, exact_subject, capability_id, label, summary, action_ref, why_this_ref, status, reversibility, state_digest, cost_summary, consequence_summary, expires_at, requirements: [], evidence_refs: [], authority_ceiling: :SELECT |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.PossibilitySet

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `closureReason` | str_key | "closureReason" => _ |  |  |  |  |

| `closure_reason` | str_key | closure_reason: Keyword.get(opts, :closure_reason) |  |  |  |  |

| `closure_reason` | str_key | Keyword.get("closure_reason") |  |  |  |  |

| `closure_reason` | str_key | closure_reason: canonical.closure_reason |  |  |  |  |

| `constraints` | str_key | constraints: [] |  |  |  |  |

| `constraints` | str_key | Keyword.get("constraints") |  |  |  |  |

| `constraints` | str_key | constraints: constraints |  |  |  |  |

| `constraints` | str_key | constraints: Enum.sort(constraints) |  |  |  |  |

| `constraints` | str_key | "constraints" => _ |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `horizon` | str_key | horizon: Keyword.get(opts, :horizon) |  |  |  |  |

| `horizon` | str_key | Keyword.get("horizon") |  |  |  |  |

| `horizon` | str_key | horizon: canonical.horizon |  |  |  |  |

| `horizon` | str_key | "horizon" => _ |  |  |  |  |

| `mode` | str_key | mode: :MAXIMAL_REVERSIBLE_FRONTIER |  |  |  |  |

| `mode` | str_key | "mode" => _ |  |  |  |  |

| `objective` | str_key | objective: objective |  |  |  |  |

| `objective` | str_key | "objective" => _ |  |  |  |  |

| `possibilities` | str_key | possibilities: [] |  |  |  |  |

| `possibilities` | str_key | possibilities: possibilities |> Enum.map(&Possibility.to_map/1) |> Enum.sort_by(& &1["possibilityId"]) |  |  |  |  |

| `possibilities` | str_key | possibilities: possibilities |  |  |  |  |

| `possibilities` | str_key | "possibilities" => _ |  |  |  |  |

| `selectionRef` | str_key | "selectionRef" => _ |  |  |  |  |

| `selection_ref` | str_key | selection_ref: Keyword.get(opts, :selection_ref) |  |  |  |  |

| `selection_ref` | str_key | Keyword.get("selection_ref") |  |  |  |  |

| `selection_ref` | str_key | selection_ref: canonical.selection_ref |  |  |  |  |

| `setId` | str_key | "setId" => _ |  |  |  |  |

| `set_id` | str_key | set_id: "ps_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `sourceEpisodeRefs` | str_key | "sourceEpisodeRefs" => _ |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: [] |  |  |  |  |

| `source_episode_refs` | str_key | Keyword.get("source_episode_refs") |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: source_episode_refs |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: Enum.sort(source_episode_refs) |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `AshSurface.PossibilitySet` | struct | defstruct set_id, exact_subject, objective, horizon, selection_ref, closure_reason, state_digest, possibilities: [], constraints: [], source_episode_refs: [], evidence_refs: [], standing: :PARTIAL_ALIVE, mode: :MAXIMAL_REVERSIBLE_FRONTIER, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.Projector.Expo

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `.actions.mjs` | str_key | ".actions.mjs" => _ |  |  |  |  |

| `.events.mjs` | str_key | ".events.mjs" => _ |  |  |  |  |

| `.mjs` | str_key | ".mjs" => _ |  |  |  |  |

| `.receipts.mjs` | str_key | ".receipts.mjs" => _ |  |  |  |  |

| `.schemas.mjs` | str_key | ".schemas.mjs" => _ |  |  |  |  |

| `.tanstack.mjs` | str_key | ".tanstack.mjs" => _ |  |  |  |  |

| `action_count` | str_key | action_count: length(actions) |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `module` | str_key | "module" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `pretty` | str_key | pretty: true |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `type` | str_key | "type" => _ |  |  |  |  |


### AshSurface.Projector.IR

| `from_surface` | function | from_surface/1 |  |  |  |  |

| `project` | function | project/3 |  |  |  |  |

| `to_surface` | function | to_surface/1 |  |  |  |  |

| `action_ids` | str_key | action_ids: surface.action_ids |  |  |  |  |

| `action_ids` | str_key | action_ids: action_ids |  |  |  |  |

| `ash` | str_key | ash: %{ manifest: surface.manifest, contract: surface.contract, digest: surface.digest, action_ids: surface.action_ids } |  |  |  |  |

| `ash` | str_key | ash: ash |  |  |  |  |

| `contract` | str_key | contract: surface.contract |  |  |  |  |

| `contract` | str_key | contract: contract |  |  |  |  |

| `digest` | str_key | digest: surface.digest |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `duplicate_surface_irs` | str_key | {:error, {:duplicate_surface_irs, length(surface_irs)}} |  |  |  |  |

| `foreign_ir` | str_key | {:error, {:foreign_ir, foreign_irs}} |  |  |  |  |

| `invalid_ir` | str_key | {:error, {:invalid_ir, element}} |  |  |  |  |

| `invalid_irs` | str_key | {:error, {:invalid_irs, other}} |  |  |  |  |

| `invalid_surface_facts` | str_key | {:error, {:invalid_surface_facts, Map.keys(ash) |> Enum.sort()}} |  |  |  |  |

| `invalid_surface_facts` | str_key | {:error, {:invalid_surface_facts, []}} |  |  |  |  |

| `kind` | str_key | kind: @surface_ir_kind |  |  |  |  |

| `manifest` | str_key | manifest: surface.manifest |  |  |  |  |

| `manifest` | str_key | manifest: %Ash.Info.Manifest{} = manifest |  |  |  |  |

| `manifest` | str_key | manifest: manifest |  |  |  |  |

| `missing_surface_ir` | str_key | {:error, {:missing_surface_ir, length(rest)}} |  |  |  |  |

| `unknown_projector_kind` | str_key | {:error, {:unknown_projector_kind, projector}} |  |  |  |  |

| `unknown_projector_kind` | str_key | {:error, {:unknown_projector_kind, other}} |  |  |  |  |

| `input` | type | @type input :: ir() | AshSurface.IR.t() | [ir() | AshSurface.IR.t()] |  |  |  |  |

| `ir` | type | @type ir :: %{ required(:kind) => String.t(), required(:ash) => term(), optional(atom()) => term() } |  |  |  |  |

| `surface_facts` | type | @type surface_facts :: %{ required(:manifest) => Ash.Info.Manifest.t(), required(:contract) => map(), required(:digest) => String.t(), required(:action_ids) => [String.t()] } |  |  |  |  |


### AshSurface.Projector.IREntry

| `authority_boundary` | function | authority_boundary/1 |  |  |  |  |

| `describe` | function | describe/1 |  |  |  |  |

| `do_boundary?` | function | do_boundary?/1 |  |  |  |  |

| `entries` | function | entries/1 |  |  |  |  |

| `__struct__` | str_key | __struct__: _ |  |  |  |  |

| `action` | str_key | action: String.t() |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action_type` | str_key | action_type: String.t() | nil |  |  |  |  |

| `action_type` | str_key | action_type: ash.action_type && to_string(ash.action_type) |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: String.t() | nil |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: authority_boundary(ir) |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: boundary |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `capability_iri` | str_key | capability_iri: ir.semantic && ir.semantic.capability_iri |  |  |  |  |

| `full_resource` | str_key | full_resource: full_resource |  |  |  |  |

| `id` | str_key | id: String.t() |  |  |  |  |

| `id` | str_key | id: "#{resource}.#{action}" |  |  |  |  |

| `label` | str_key | label: String.t() | nil |  |  |  |  |

| `label` | str_key | label: presentation.label |  |  |  |  |

| `receipt_required` | str_key | receipt_required: boolean() |  |  |  |  |

| `receipt_required` | str_key | receipt_required: capability.receipt_required == true |  |  |  |  |

| `resource` | str_key | resource: String.t() |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `zod` | str_key | zod: String.t() | nil |  |  |  |  |

| `zod` | str_key | zod: schema.zod |  |  |  |  |

| `AshSurface.Projector.IREntry` | struct | defstruct id, resource, action, action_type, authority_boundary, receipt_required, capability_iri, label, zod, full_resource |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), resource: String.t(), action: String.t(), action_type: String.t() | nil, authority_boundary: String.t() | nil, receipt_required: boolean(), capability_iri: String.t() | nil, label: String.t() | nil, zod: String.t() | nil } |  |  |  |  |


### AshSurface.Projector.VoiceKiosk

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `voice_ir` | function | voice_ir/2 |  |  |  |  |

| `.voice.json` | str_key | ".voice.json" => _ |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `any value` | str_key | Map.get("any value") |  |  |  |  |

| `autoExecute` | str_key | "autoExecute" => _ |  |  |  |  |

| `boolean` | str_key | "boolean" => _ |  |  |  |  |

| `datetime` | str_key | "datetime" => _ |  |  |  |  |

| `decimal` | str_key | "decimal" => _ |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `grammar` | str_key | "grammar" => _ |  |  |  |  |

| `integer` | str_key | "integer" => _ |  |  |  |  |

| `intent_count` | str_key | intent_count: length(ir["intents"]) |  |  |  |  |

| `intents` | str_key | "intents" => _ |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `mode` | str_key | "mode" => _ |  |  |  |  |

| `module` | str_key | "module" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `pretty` | str_key | pretty: true |  |  |  |  |

| `prompt` | str_key | "prompt" => _ |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `slots` | str_key | "slots" => _ |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `surfaceDigest` | str_key | "surfaceDigest" => _ |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `utc_datetime` | str_key | "utc_datetime" => _ |  |  |  |  |

| `uuid` | str_key | "uuid" => _ |  |  |  |  |


### AshSurface.Projectors.ARIA

| `contract` | function | contract/1 |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `to_json` | function | to_json/1 |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `aria-describedby` | str_key | "aria-describedby" => _ |  |  |  |  |

| `contract` | str_key | "contract" => _ |  |  |  |  |

| `emitted` | str_key | emitted: emitted |  |  |  |  |

| `group` | str_key | "group" => _ |  |  |  |  |

| `group_count` | str_key | group_count: length(contract["groups"]) |  |  |  |  |

| `groups` | str_key | "groups" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `inputs` | str_key | "inputs" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `live` | str_key | "live" => _ |  |  |  |  |

| `members` | str_key | "members" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, term()}} |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, other}} |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `resource` | str_key | "resource" => _ |  |  |  |  |

| `role` | str_key | "role" => _ |  |  |  |  |

| `surface_count` | str_key | surface_count: length(contract["surfaces"]) |  |  |  |  |

| `surfaces` | str_key | "surfaces" => _ |  |  |  |  |

| `tabOrder` | str_key | "tabOrder" => _ |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `version` | str_key | "version" => _ |  |  |  |  |


### AshSurface.Projectors.JS

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action_count` | str_key | action_count: length(entries) |  |  |  |  |

| `ash` | str_key | ash: %{resource: resource} |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: nil |  |  |  |  |

| `duplicate_js_member` | str_key | {:error, {:duplicate_js_member, id}} |  |  |  |  |

| `escape` | str_key | escape: :javascript_safe |  |  |  |  |

| `id` | str_key | id: "#{binding}.#{entry.action}" |  |  |  |  |

| `id` | str_key | id: id |  |  |  |  |

| `invalid_namespace_names` | str_key | {:error, {:invalid_namespace_names, names}} |  |  |  |  |

| `invalid_namespace_prefix` | str_key | {:error, {:invalid_namespace_prefix, value}} |  |  |  |  |

| `invalid_prefix` | str_key | {:error, {:invalid_prefix, prefix}} |  |  |  |  |

| `js_binding_collision` | str_key | {:error, {:js_binding_collision, name}} |  |  |  |  |

| `js_namespace_collision` | str_key | {:error, {:js_namespace_collision, short, many}} |  |  |  |  |

| `namespace_count` | str_key | namespace_count: entries |> Enum.map(& &1.resource) |> Enum.uniq() |> length() |  |  |  |  |

| `namespace_names` | str_key | Keyword.get("namespace_names") |  |  |  |  |

| `namespace_prefix` | str_key | Keyword.get("namespace_prefix") |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, other}} |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `unadmitted_field` | str_key | {:error, {:unadmitted_field, entry.id, field}} |  |  |  |  |

| `unadmitted_zod` | str_key | {:error, {:unadmitted_zod, entry.id, reason}} |  |  |  |  |

| `unsafe_js_member` | str_key | {:error, {:unsafe_js_member, id}} |  |  |  |  |

| `unsafe_js_namespace` | str_key | {:error, {:unsafe_js_namespace, v}} |  |  |  |  |

| `unsafe_js_namespace` | str_key | {:error, {:unsafe_js_namespace, bound}} |  |  |  |  |

| `zod` | str_key | zod: nil |  |  |  |  |

| `zod` | str_key | zod: zod |  |  |  |  |

| `zod` | str_key | zod: expr |  |  |  |  |


### AshSurface.Projectors.JS.ZodGuard

| `admit` | function | admit/1 |  |  |  |  |

| `expression` | function | expression/1 |  |  |  |  |

| `capture` | str_key | capture: :all_but_first |  |  |  |  |

| `zod_bare_z` | str_key | {:error, :zod_bare_z} |  |  |  |  |

| `zod_denied_key` | str_key | {:error, {:zod_denied_key, key}} |  |  |  |  |

| `zod_denied_member` | str_key | {:error, {:zod_denied_member, name}} |  |  |  |  |

| `zod_empty` | str_key | {:error, :zod_empty} |  |  |  |  |

| `zod_expected_member_name` | str_key | {:error, :zod_expected_member_name} |  |  |  |  |

| `zod_expected_z` | str_key | {:error, {:zod_expected_z, token}} |  |  |  |  |

| `zod_not_a_string` | str_key | {:error, {:zod_not_a_string, other}} |  |  |  |  |

| `zod_trailing_token` | str_key | {:error, {:zod_trailing_token, token}} |  |  |  |  |

| `zod_truncated` | str_key | {:error, :zod_truncated} |  |  |  |  |

| `zod_unadmitted_key` | str_key | {:error, {:zod_unadmitted_key, token}} |  |  |  |  |

| `zod_unadmitted_text` | str_key | {:error, {:zod_unadmitted_text, String.slice(text, 0, 24)}} |  |  |  |  |

| `zod_unadmitted_value` | str_key | {:error, {:zod_unadmitted_value, token}} |  |  |  |  |

| `zod_unclosed` | str_key | {:error, {:zod_unclosed, close}} |  |  |  |  |

| `zod_unexpected_token` | str_key | {:error, {:zod_unexpected_token, token}} |  |  |  |  |


### AshSurface.Projectors.LiveView

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `action_count` | str_key | "action_count" => _ |  |  |  |  |

| `action_type` | str_key | "action_type" => _ |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `allow_nil?` | str_key | "allow_nil?" => _ |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: false |  |  |  |  |

| `authority_gate` | str_key | "authority_gate" => _ |  |  |  |  |

| `authority_required` | str_key | "authority_required" => _ |  |  |  |  |

| `boolean` | str_key | "boolean" => _ |  |  |  |  |

| `capability` | str_key | capability: nil |  |  |  |  |

| `capability` | str_key | capability: capability |  |  |  |  |

| `cardinality` | str_key | "cardinality" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `columns` | str_key | "columns" => _ |  |  |  |  |

| `consequence_class` | str_key | "consequence_class" => _ |  |  |  |  |

| `control` | str_key | "control" => _ |  |  |  |  |

| `date` | str_key | "date" => _ |  |  |  |  |

| `datetime` | str_key | "datetime" => _ |  |  |  |  |

| `decimal` | str_key | "decimal" => _ |  |  |  |  |

| `destination` | str_key | "destination" => _ |  |  |  |  |

| `digest` | str_key | "digest" => _ |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `format` | str_key | "format" => _ |  |  |  |  |

| `forms` | str_key | "forms" => _ |  |  |  |  |

| `gated` | str_key | "gated" => _ |  |  |  |  |

| `group` | str_key | "group" => _ |  |  |  |  |

| `group_count` | str_key | "group_count" => _ |  |  |  |  |

| `groups` | str_key | "groups" => _ |  |  |  |  |

| `integer` | str_key | "integer" => _ |  |  |  |  |

| `intent_target` | str_key | "intent_target" => _ |  |  |  |  |

| `ir_version` | str_key | "ir_version" => _ |  |  |  |  |

| `ir_version_conflict` | str_key | {:error, {:ir_version_conflict, many}} |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `kind` | str_key | kind: kind |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `malformed_relationship` | str_key | {:error, {:malformed_relationship, entry}} |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `navigation` | str_key | "navigation" => _ |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, other}} |  |  |  |  |

| `not_ir_input` | str_key | {:error, {:not_ir_input, other}} |  |  |  |  |

| `order` | str_key | "order" => _ |  |  |  |  |

| `path` | str_key | "path" => _ |  |  |  |  |

| `predicates` | str_key | Map.get("predicates") |  |  |  |  |

| `presentation` | str_key | presentation: nil |  |  |  |  |

| `presentation` | str_key | presentation: presentation |  |  |  |  |

| `projector` | str_key | "projector" => _ |  |  |  |  |

| `receipt_required` | str_key | "receipt_required" => _ |  |  |  |  |

| `relationships` | str_key | "relationships" => _ |  |  |  |  |

| `relationships` | str_key | Map.get("relationships") |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `required` | str_key | required: required |  |  |  |  |

| `resource` | str_key | "resource" => _ |  |  |  |  |

| `resource_count` | str_key | "resource_count" => _ |  |  |  |  |

| `resources` | str_key | "resources" => _ |  |  |  |  |

| `schema` | str_key | schema: nil |  |  |  |  |

| `schema` | str_key | schema: schema |  |  |  |  |

| `semantic` | str_key | semantic: nil |  |  |  |  |

| `semantic` | str_key | semantic: semantic |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `surface_action_id` | str_key | "surface_action_id" => _ |  |  |  |  |

| `table` | str_key | "table" => _ |  |  |  |  |

| `text` | str_key | Map.get("text") |  |  |  |  |

| `type` | str_key | "type" => _ |  |  |  |  |

| `type` | str_key | type: %{kind: kind} |  |  |  |  |

| `type` | str_key | type: type |  |  |  |  |

| `utc_datetime` | str_key | "utc_datetime" => _ |  |  |  |  |

| `uuid` | str_key | "uuid" => _ |  |  |  |  |

| `widget` | str_key | "widget" => _ |  |  |  |  |


### AshSurface.Resource

| `action` | str_key | action: [type: :atom, required: true, doc: "Public Ash action name this projection describes."] |  |  |  |  |

| `args` | str_key | args: [:action] |  |  |  |  |

| `consumer` | str_key | consumer: [type: :atom, required: false, doc: "Optional consumer class such as web, mobile, or internal."] |  |  |  |  |

| `default` | str_key | default: :auto |  |  |  |  |

| `describe` | str_key | describe: "Declares consumer projection intent for public Ash actions without duplicating Ash semantics." |  |  |  |  |

| `doc` | str_key | doc: "Public Ash action name this projection describes." |  |  |  |  |

| `doc` | str_key | doc: "Optional consumer class such as web, mobile, or internal." |  |  |  |  |

| `doc` | str_key | doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives." |  |  |  |  |

| `entities` | str_key | entities: [ @projection, ] |  |  |  |  |

| `identifier` | str_key | identifier: :action |  |  |  |  |

| `name` | str_key | name: :projection |  |  |  |  |

| `name` | str_key | name: :surface |  |  |  |  |

| `required` | str_key | required: true |  |  |  |  |

| `required` | str_key | required: false |  |  |  |  |

| `schema` | str_key | schema: [ action: [type: :atom, required: true, doc: "Public Ash action name this projection describes."], consumer: [type: :atom, required: false, doc: "Optional consumer class such as web, mobile, or internal."], transport: [type: {:one_of, [:auto, :http, :phoenix_channel]}, required: false, default: :auto, doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives."], ] |  |  |  |  |

| `sections` | str_key | sections: [@surface] |  |  |  |  |

| `single_extension_kinds` | str_key | single_extension_kinds: [:ash_surface] |  |  |  |  |

| `target` | str_key | target: AshSurface.Dsl.Projection |  |  |  |  |

| `transformers` | str_key | transformers: [AshSurface.Resource.Persist] |  |  |  |  |

| `transport` | str_key | transport: [type: {:one_of, [:auto, :http, :phoenix_channel]}, required: false, default: :auto, doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives."] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: {:one_of, [:auto, :http, :phoenix_channel]} |  |  |  |  |

| `verifiers` | str_key | verifiers: [AshSurface.Resource.Verify] |  |  |  |  |


### AshSurface.Resource.Info

| `compiled` | function | compiled/1 |  |  |  |  |

| `compiled!` | function | compiled!/1 |  |  |  |  |

| `compiled?` | function | compiled?/1 |  |  |  |  |

| `compiled_result` | function | compiled_result/1 |  |  |  |  |

| `surface` | function | surface/1 |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |


### AshSurface.Resource.Persist

| `transform` | function | transform/1 |  |  |  |  |

| `metadata` | str_key | metadata: %{source: :ash_manifest} |  |  |  |  |

| `source` | str_key | source: :ash_manifest |  |  |  |  |

| `surface` | str_key | surface: surface_entities |  |  |  |  |


### AshSurface.Resource.Validator

| `validate` | function | validate/1 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `code` | str_key | code: "duplicate_action_projection" |  |  |  |  |

| `code` | str_key | code: "unknown_action_projection" |  |  |  |  |

| `code` | str_key | code: code |  |  |  |  |

| `code` | str_key | code: "invalid_surface_compilation" |  |  |  |  |

| `detail` | str_key | detail: "surface projection for #{inspect(action)} is declared more than once" |  |  |  |  |

| `detail` | str_key | detail: "surface projection names #{inspect(action)}, which is not in the exact public action set " <> inspect(Enum.sort(public_actions)) |  |  |  |  |

| `detail` | str_key | detail: "surface projection for #{inspect(projection.action)} declares #{label} #{inspect(kind)}; admitted kinds are " <> inspect(admitted) |  |  |  |  |

| `detail` | str_key | detail: detail |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `surface` | str_key | surface: projections |  |  |  |  |


### AshSurface.Resource.Verify

| `verify` | function | verify/1 |  |  |  |  |

| `message` | str_key | message: "ash_surface: transformer did not persist :ash_surface_compiled -- Persist must run before Verify" |  |  |  |  |

| `message` | str_key | message: Enum.map_join(refusals, "; ", &"#{&1.code}: #{&1.detail}") |  |  |  |  |

| `path` | str_key | path: [] |  |  |  |  |


### AshSurface.Standing

| `base_standings` | function | base_standings/0 |  |  |  |  |

| `refused?` | function | refused?/1 |  |  |  |  |

| `valid?` | function | valid?/1 |  |  |  |  |

| `validate!` | function | validate!/1 |  |  |  |  |

| `base` | type | @type base :: :ALIVE | :PARTIAL_ALIVE | :BLOCKED | :BUILD_BROKEN | :UNSUPPORTED |  |  |  |  |

| `refused` | type | @type refused :: atom() |  |  |  |  |

| `t` | type | @type t :: base() | refused() |  |  |  |  |


### AshSurface.Telemetry

| `events` | function | events/0 |  |  |  |  |

| `intent_dispatched` | function | intent_dispatched/2 |  |  |  |  |

| `receipt_refused` | function | receipt_refused/1 |  |  |  |  |

| `transport_selected` | function | transport_selected/1 |  |  |  |  |

| `REFUSED_NO_COMMAND_BUS` | str_key | {:error, :REFUSED_NO_COMMAND_BUS} |  |  |  |  |

| `REFUSED_UNKNOWN_ACTION` | str_key | {:error, :REFUSED_UNKNOWN_ACTION} |  |  |  |  |

| `action_id` | str_key | action_id: decision.action_id |  |  |  |  |

| `action_id` | str_key | action_id: if(is_binary(action_id), do: action_id) |  |  |  |  |

| `available` | str_key | available: decision.available |  |  |  |  |

| `available_count` | str_key | available_count: length(decision.available) |  |  |  |  |

| `count` | str_key | count: 1 |  |  |  |  |

| `declared` | str_key | declared: decision.declared |  |  |  |  |

| `dimensions` | str_key | dimensions: decision.dimensions |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, _}} |  |  |  |  |

| `invalid_context` | str_key | {:error, {:invalid_context, _}} |  |  |  |  |

| `outcome` | str_key | outcome: outcome(result) |  |  |  |  |

| `reason` | str_key | reason: decision.reason |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `reason_class` | str_key | reason_class: reason_class(reason) |  |  |  |  |

| `selected` | str_key | selected: decision.selected |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |


### AshSurface.TestSupport.CompilerEchoSection

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action_id` | str_key | action_id: context.action_id |  |  |  |  |

| `echo` | str_key | echo: context.action_id |  |  |  |  |

| `token` | str_key | token: context.discovery.token |  |  |  |  |


### AshSurface.TestSupport.LineageCourt

| `git` | function | git/2 |  |  |  |  |

| `verdict` | function | verdict/2 |  |  |  |  |

| `base` | str_key | base: claim.base |  |  |  |  |

| `base_paths` | str_key | base_paths: MapSet.size(base_paths) |  |  |  |  |

| `env` | str_key | env: [ {"GIT_CONFIG_NOSYSTEM", "1"}, {"GIT_TERMINAL_PROMPT", "0"}, {"GIT_NO_REPLACE_OBJECTS", "1"} ] |  |  |  |  |

| `head` | str_key | head: claim.head |  |  |  |  |

| `head_paths` | str_key | head_paths: MapSet.size(head_paths) |  |  |  |  |

| `head_tree` | str_key | Map.get("head_tree") |  |  |  |  |

| `head_tree` | str_key | head_tree: head_tree |  |  |  |  |

| `merge` | str_key | Map.get("merge") |  |  |  |  |

| `merge` | str_key | merge: Map.get(claim, :merge) |  |  |  |  |

| `retired` | str_key | Map.get("retired") |  |  |  |  |

| `retired` | str_key | retired: Enum.sort(retired) |  |  |  |  |

| `stderr_to_stdout` | str_key | stderr_to_stdout: true |  |  |  |  |

| `trim` | str_key | trim: true |  |  |  |  |

| `claim` | type | @type claim :: %{ required(:base) => String.t(), required(:head) => String.t(), optional(:head_tree) => String.t() | nil, optional(:merge) => String.t() | nil, optional(:retired) => [String.t()] } |  |  |  |  |

| `refusal` | type | @type refusal :: :malformed_subject | :unknown_subject | :base_not_ancestor | :vacuous_lineage | :merge_not_in_lineage | :retired_not_in_base | :head_tree_mismatch | :merge_not_found | :merge_tree_not_conserved | :retired_path_resurrected | :base_path_dropped |  |  |  |  |


### AshSurface.TestSupport.VerifiedSurface

| `seal` | function | seal/1 |  |  |  |  |

| `digest` | str_key | digest: AshSurface.contract_digest(surface.contract) |  |  |  |  |

| `manifest` | str_key | manifest: manifest |  |  |  |  |


### AshSurface.Transport

| `facts_from_profile` | function | facts_from_profile/1 |  |  |  |  |

| `fallback_allowed?` | function | fallback_allowed?/1 |  |  |  |  |

| `mark_dispatched` | function | mark_dispatched/1 |  |  |  |  |

| `select` | function | select/3 |  |  |  |  |

| `action_id` | str_key | action_id: String.t() | nil |  |  |  |  |

| `action_id` | str_key | Keyword.get("action_id") |  |  |  |  |

| `action_id` | str_key | action_id: action_id |  |  |  |  |

| `available` | str_key | available: [atom()] |  |  |  |  |

| `available` | str_key | available: available |  |  |  |  |

| `available` | str_key | available: [] |  |  |  |  |

| `declared` | str_key | declared: [atom()] |  |  |  |  |

| `declared` | str_key | declared: declared |  |  |  |  |

| `dimensions` | str_key | dimensions: dimensions() |  |  |  |  |

| `dimensions` | str_key | dimensions: :undelegated |  |  |  |  |

| `dimensions` | str_key | dimensions: dimensions |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched | :dispatched |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :dispatched |  |  |  |  |

| `duplicate_transport` | str_key | {:error, {:duplicate_transport, duplicates |> Enum.map(&elem(&1, 0)) |> Enum.sort()}} |  |  |  |  |

| `facts` | str_key | Keyword.get("facts") |  |  |  |  |

| `facts_must_be_a_map` | str_key | {:error, :facts_must_be_a_map} |  |  |  |  |

| `fallback` | str_key | fallback: :pre_dispatch_only |  |  |  |  |

| `frontier` | str_key | frontier: [atom()] |  |  |  |  |

| `frontier` | str_key | frontier: [] |  |  |  |  |

| `frontier` | str_key | frontier: frontier |  |  |  |  |

| `preferred` | str_key | preferred: atom() |  |  |  |  |

| `preferred` | str_key | Keyword.get("preferred") |  |  |  |  |

| `preferred` | str_key | preferred: preferred |  |  |  |  |

| `profile_must_be_a_map` | str_key | {:error, :profile_must_be_a_map} |  |  |  |  |

| `reason` | str_key | reason: atom() |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `selected` | str_key | selected: atom() |  |  |  |  |

| `selected` | str_key | selected: selected |  |  |  |  |

| `transportFacts` | str_key | Map.get("transportFacts") |  |  |  |  |

| `transport_facts_must_be_a_map` | str_key | {:error, :transport_facts_must_be_a_map} |  |  |  |  |

| `transports_must_be_a_list` | str_key | {:error, :transports_must_be_a_list} |  |  |  |  |

| `unadmitted_transport` | str_key | {:error, {:unadmitted_transport, unadmitted}} |  |  |  |  |

| `unknown_dimension` | str_key | {:error, {:unknown_dimension, {transport, other}}} |  |  |  |  |

| `unknown_dimension_class` | str_key | {:error, {:unknown_dimension_class, {transport, dimension, other}}} |  |  |  |  |

| `unknown_transport` | str_key | {:error, {:unknown_transport, [other]}} |  |  |  |  |

| `unknown_transport` | str_key | {:error, {:unknown_transport, preferred}} |  |  |  |  |

| `unknown_transport` | str_key | {:error, {:unknown_transport, unknown}} |  |  |  |  |

| `unsupported_transport` | str_key | {:error, {:unsupported_transport, %{preferred: preferred, available: []}}} |  |  |  |  |


### AshSurface.Vocabulary

| `base_standings` | function | base_standings/0 |  |  |  |  |

| `digest?` | function | digest?/1 |  |  |  |  |

| `digest_hex_length` | function | digest_hex_length/0 |  |  |  |  |

| `digest_shape?` | function | digest_shape?/1 |  |  |  |  |

| `dimension_classes` | function | dimension_classes/0 |  |  |  |  |

| `dimension_priority` | function | dimension_priority/0 |  |  |  |  |

| `dimensions` | function | dimensions/0 |  |  |  |  |

| `dispatch_outcomes` | function | dispatch_outcomes/0 |  |  |  |  |

| `dispatch_states` | function | dispatch_states/0 |  |  |  |  |

| `idempotency_protocol` | function | idempotency_protocol/0 |  |  |  |  |

| `known_transports` | function | known_transports/0 |  |  |  |  |

| `reconcile_statuses` | function | reconcile_statuses/0 |  |  |  |  |

| `refusal_atom?` | function | refusal_atom?/1 |  |  |  |  |

| `refusal_code?` | function | refusal_code?/1 |  |  |  |  |

| `refusal_prefix` | function | refusal_prefix/0 |  |  |  |  |

| `to_map` | function | to_map/0 |  |  |  |  |

| `digestHexLength` | str_key | "digestHexLength" => _ |  |  |  |  |

| `dimensionClasses` | str_key | "dimensionClasses" => _ |  |  |  |  |

| `dimensions` | str_key | "dimensions" => _ |  |  |  |  |

| `dispatchOutcomes` | str_key | "dispatchOutcomes" => _ |  |  |  |  |

| `dispatchStates` | str_key | "dispatchStates" => _ |  |  |  |  |

| `idempotencyProtocol` | str_key | "idempotencyProtocol" => _ |  |  |  |  |

| `knownTransports` | str_key | "knownTransports" => _ |  |  |  |  |

| `reconcileStatuses` | str_key | "reconcileStatuses" => _ |  |  |  |  |

| `refusalPrefix` | str_key | "refusalPrefix" => _ |  |  |  |  |

| `standingValues` | str_key | "standingValues" => _ |  |  |  |  |


### AshSurface.WhyThis

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `basis` | str_key | basis: [] |  |  |  |  |

| `basis` | str_key | Keyword.get("basis") |  |  |  |  |

| `basis` | str_key | basis: basis |  |  |  |  |

| `basis` | str_key | basis: Enum.sort(basis) |  |  |  |  |

| `basis` | str_key | "basis" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `caveats` | str_key | caveats: [] |  |  |  |  |

| `caveats` | str_key | Keyword.get("caveats") |  |  |  |  |

| `caveats` | str_key | caveats: caveats |  |  |  |  |

| `caveats` | str_key | caveats: Enum.sort(caveats) |  |  |  |  |

| `caveats` | str_key | "caveats" => _ |  |  |  |  |

| `claimKind` | str_key | "claimKind" => _ |  |  |  |  |

| `claim_kind` | str_key | Keyword.get("claim_kind") |  |  |  |  |

| `claim_kind` | str_key | claim_kind: claim_kind |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceState` | str_key | "evidenceState" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_state` | str_key | Keyword.get("evidence_state") |  |  |  |  |

| `evidence_state` | str_key | evidence_state: evidence_state |  |  |  |  |

| `explanationId` | str_key | "explanationId" => _ |  |  |  |  |

| `explanation_id` | str_key | explanation_id: "why_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `falsifier` | str_key | Keyword.get("falsifier") |  |  |  |  |

| `falsifier` | str_key | falsifier: falsifier |  |  |  |  |

| `falsifier` | str_key | "falsifier" => _ |  |  |  |  |

| `hypothesisRefs` | str_key | "hypothesisRefs" => _ |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: [] |  |  |  |  |

| `hypothesis_refs` | str_key | Keyword.get("hypothesis_refs") |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: hypothesis_refs |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: Enum.sort(hypothesis_refs) |  |  |  |  |

| `profileRefs` | str_key | "profileRefs" => _ |  |  |  |  |

| `profile_refs` | str_key | profile_refs: [] |  |  |  |  |

| `profile_refs` | str_key | Keyword.get("profile_refs") |  |  |  |  |

| `profile_refs` | str_key | profile_refs: profile_refs |  |  |  |  |

| `profile_refs` | str_key | profile_refs: Enum.sort(profile_refs) |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `summary` | str_key | summary: summary |  |  |  |  |

| `summary` | str_key | "summary" => _ |  |  |  |  |

| `title` | str_key | title: title |  |  |  |  |

| `title` | str_key | "title" => _ |  |  |  |  |

| `AshSurface.WhyThis` | struct | defstruct explanation_id, subject_ref, title, summary, claim_kind, evidence_state, falsifier, state_digest, basis: [], caveats: [], profile_refs: [], evidence_refs: [], hypothesis_refs: [], authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |


### AshSurface.ZoeDemo

| `acceptance` | function | acceptance/0 |  |  |  |  |

| `map` | function | map/0 |  |  |  |  |

| `surface` | function | surface/0 |  |  |  |  |

| `action_ref` | str_key | action_ref: "Zoela.Devotional |  |  |  |  |

| `action_ref` | str_key | action_ref: "Zoela.Service |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `asOf` | str_key | "asOf" => _ |  |  |  |  |

| `audio_ref` | str_key | audio_ref: "demo-audio:James.1.2-8" |  |  |  |  |

| `audio_ref` | str_key | audio_ref: "demo-audio:Romans.5.1-5" |  |  |  |  |

| `audio_ref` | str_key | audio_ref: "demo-audio:reflection:perseverance" |  |  |  |  |

| `basis` | str_key | basis: [ "demo profile selects consistency as an outcome", "devotional passage theme is perseverance" ] |  |  |  |  |

| `bible` | str_key | bible: %{ "headline" => "Bible", "devotionalEpisodeRefs" => [devotional.episode_id], "continuousPlayAvailable" => true } |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `causalClaimsAdmitted` | str_key | "causalClaimsAdmitted" => _ |  |  |  |  |

| `caveats` | str_key | caveats: [ "synthetic demo profile", "candidate relevance only", "no causal effect has been admitted" ] |  |  |  |  |

| `claim_kind` | str_key | claim_kind: :HYPOTHESIS |  |  |  |  |

| `commitmentBoundaryRefs` | str_key | "commitmentBoundaryRefs" => _ |  |  |  |  |

| `commitmentStopsBeforeDo` | str_key | "commitmentStopsBeforeDo" => _ |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: [service_boundary] |  |  |  |  |

| `confirmation_state` | str_key | confirmation_state: :UNCONFIRMED |  |  |  |  |

| `consent_ref` | str_key | consent_ref: "demo-consent:subject-only" |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "Begins client playback; no external organizational mutation." |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "Opens local reading surface; no external mutation." |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "No roster or team notification occurs during exploration." |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "No new consequence." |  |  |  |  |

| `continuousDevotional` | str_key | "continuousDevotional" => _ |  |  |  |  |

| `continuousPlayAvailable` | str_key | "continuousPlayAvailable" => _ |  |  |  |  |

| `cost_summary` | str_key | cost_summary: "About 7 minutes" |  |  |  |  |

| `cost_summary` | str_key | cost_summary: "Self-paced" |  |  |  |  |

| `devotionalEpisodeRefs` | str_key | "devotionalEpisodeRefs" => _ |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: [devotional] |  |  |  |  |

| `dimension` | str_key | dimension: "life:outcome" |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 180 |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 5 |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 140 |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 120 |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: ["demo-evidence:synthetic-profile"] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: manufacture_trace.receipt_refs |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: ["demo-evidence:synthetic-only"] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: ["demo-evidence:reflection:001"] |  |  |  |  |

| `evidence_state` | str_key | evidence_state: :UNKNOWN |  |  |  |  |

| `explanationRefs` | str_key | "explanationRefs" => _ |  |  |  |  |

| `explanations` | str_key | explanations: [why] |  |  |  |  |

| `external_effects` | str_key | external_effects: [ "team notification after authorized DO", "roster mutation after authorized DO" ] |  |  |  |  |

| `falsifier` | str_key | falsifier: "Across repeated observations, devotional completion does not precede improvement in the member-selected consistency measure." |  |  |  |  |

| `falsifier` | str_key | falsifier: "No repeated association appears between this practice and the selected outcome." |  |  |  |  |

| `falsifiers` | str_key | falsifiers: [ "The profile facet is withdrawn or no longer admitted.", "The devotional semantics no longer include the mapped perseverance concept." ] |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `headline` | str_key | "headline" => _ |  |  |  |  |

| `horizon` | str_key | horizon: "7d" |  |  |  |  |

| `horizon` | str_key | horizon: "today" |  |  |  |  |

| `humanAreas` | str_key | "humanAreas" => _ |  |  |  |  |

| `human_summary` | str_key | human_summary: "The candidate was manufactured from the admitted demo goal and devotional semantics." |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: [hypothesis.hypothesis_id] |  |  |  |  |

| `journeyPrivate` | str_key | "journeyPrivate" => _ |  |  |  |  |

| `journeyRefs` | str_key | "journeyRefs" => _ |  |  |  |  |

| `journeys` | str_key | journeys: [journey] |  |  |  |  |

| `kind` | str_key | kind: :SCRIPTURE |  |  |  |  |

| `kind` | str_key | kind: :TRANSITION |  |  |  |  |

| `kind` | str_key | kind: :REFLECTION |  |  |  |  |

| `kind` | str_key | kind: :ATTENDANCE |  |  |  |  |

| `kind` | str_key | kind: :PRACTICE |  |  |  |  |

| `label` | str_key | label: "James 1:2-8" |  |  |  |  |

| `label` | str_key | label: "Continue" |  |  |  |  |

| `label` | str_key | label: "Romans 5:1-5" |  |  |  |  |

| `label` | str_key | label: "Reflection" |  |  |  |  |

| `label` | str_key | label: "Sunday service attendance — demo receipt" |  |  |  |  |

| `label` | str_key | label: "Prior devotional — demo receipt" |  |  |  |  |

| `label` | str_key | label: "Reflection saved — demo evidence" |  |  |  |  |

| `life` | str_key | life: %{ "headline" => "Life", "selectedOutcomeRefs" => ["life:outcome:consistency"], "outcomeHypothesisRefs" => [hypothesis.hypothesis_id], "personalizationContextRefs" => [personalization.context_id], "manufactureTraceRefs" => [manufacture_trace.trace_id], "causalClaimsAdmitted" => false } |  |  |  |  |

| `liveProviderReads` | str_key | "liveProviderReads" => _ |  |  |  |  |

| `manufactureReceipted` | str_key | "manufactureReceipted" => _ |  |  |  |  |

| `manufactureTraceRefs` | str_key | "manufactureTraceRefs" => _ |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: [manufacture_trace] |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `observed_refs` | str_key | observed_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `occurred_at` | str_key | occurred_at: "2026-09-20T12:00:00-07:00" |  |  |  |  |

| `occurred_at` | str_key | occurred_at: "2026-09-21T08:00:00-07:00" |  |  |  |  |

| `occurred_at` | str_key | occurred_at: "2026-09-21T08:08:00-07:00" |  |  |  |  |

| `outcomeHypothesisNonCausal` | str_key | "outcomeHypothesisNonCausal" => _ |  |  |  |  |

| `outcomeHypothesisRefs` | str_key | "outcomeHypothesisRefs" => _ |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: [hypothesis] |  |  |  |  |

| `personalizationBounded` | str_key | "personalizationBounded" => _ |  |  |  |  |

| `personalizationContextRefs` | str_key | "personalizationContextRefs" => _ |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: [personalization] |  |  |  |  |

| `pluralDfcmFrontier` | str_key | "pluralDfcmFrontier" => _ |  |  |  |  |

| `possibilities` | str_key | Map.fetch!("possibilities") |  |  |  |  |

| `possibilitySetRefs` | str_key | "possibilitySetRefs" => _ |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: [frontier] |  |  |  |  |

| `privacyScope` | str_key | "privacyScope" => _ |  |  |  |  |

| `profile_refs` | str_key | profile_refs: [personalization.context_id] |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: "demo-receipt:attendance:001" |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: "demo-receipt:devotional:001" |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: ["demo-receipt:manufacture:001"] |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: ["demo-receipt:attendance:001", "demo-receipt:devotional:001"] |  |  |  |  |

| `ref` | str_key | ref: "bible:James.1.2-8" |  |  |  |  |

| `ref` | str_key | ref: "transition:james-romans" |  |  |  |  |

| `ref` | str_key | ref: "bible:Romans.5.1-5" |  |  |  |  |

| `ref` | str_key | ref: "reflection:perseverance" |  |  |  |  |

| `relationship` | str_key | relationship: :MAY_SUPPORT |  |  |  |  |

| `requirements` | str_key | requirements: ["audio-capable client"] |  |  |  |  |

| `reversibility` | str_key | reversibility: :REVERSIBLE |  |  |  |  |

| `reversibility` | str_key | reversibility: :CONDITIONAL |  |  |  |  |

| `selectedOutcomeRefs` | str_key | "selectedOutcomeRefs" => _ |  |  |  |  |

| `source` | str_key | source: :USER_STATED |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: ["demo-planner:episode:2026-09-23"] |  |  |  |  |

| `source_refs` | str_key | source_refs: ["demo-source:bible-content"] |  |  |  |  |

| `standing` | str_key | standing: :ALIVE |  |  |  |  |

| `subject_ref` | str_key | subject_ref: "zoe:service:demo-sunday" |  |  |  |  |

| `subject_ref` | str_key | subject_ref: "practice:devotional:demo-prior" |  |  |  |  |

| `subject_ref` | str_key | subject_ref: "reflection:demo-prior" |  |  |  |  |

| `subtitle` | str_key | subtitle: "7 minutes · straight through" |  |  |  |  |

| `summary` | str_key | summary: "Play all readings and reflection in one uninterrupted episode." |  |  |  |  |

| `summary` | str_key | summary: "Open the same episode as an ordered reading sequence." |  |  |  |  |

| `summary` | str_key | summary: "See currently admitted service possibilities without joining a roster." |  |  |  |  |

| `summary` | str_key | summary: "Preserve the option to make no new commitment today." |  |  |  |  |

| `syntheticOnly` | str_key | "syntheticOnly" => _ |  |  |  |  |

| `today` | str_key | today: %{ "headline" => "Today", "asOf" => @demo_time, "possibilitySetRefs" => [frontier.set_id], "explanationRefs" => [why.explanation_id], "devotionalEpisodeRefs" => [devotional.episode_id] } |  |  |  |  |

| `value_ref` | str_key | value_ref: "life:outcome:consistency" |  |  |  |  |

| `whyThisPresent` | str_key | "whyThisPresent" => _ |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: why.explanation_id |  |  |  |  |

| `you` | str_key | you: %{ "headline" => "You", "journeyRefs" => [journey.journey_id], "privacyScope" => "SUBJECT_PRIVATE" } |  |  |  |  |

| `zoe` | str_key | zoe: %{ "headline" => "ZOE", "possibilitySetRefs" => [frontier.set_id], "commitmentBoundaryRefs" => [service_boundary.boundary_id], "liveProviderReads" => false } |  |  |  |  |


### AshSurfaceZoe

| `runtime_path` | function | runtime_path/0 |  |  |  |  |

| `runtime_source` | function | runtime_source/0 |  |  |  |  |


### AshSurfaceZoe.Fixtures.Domain

| `validate_config_inclusion?` | str_key | validate_config_inclusion?: false |  |  |  |  |


### AshSurfaceZoe.Fixtures.VolunteerMilestone

| `AshSurfaceZoe.Fixtures.VolunteerMilestone` | ash_resource |  |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: false |  |  |  |  |

| `data_layer` | str_key | data_layer: Ash.DataLayer.Ets |  |  |  |  |

| `default` | str_key | default: "completed" |  |  |  |  |

| `domain` | str_key | domain: AshSurfaceZoe.Fixtures.Domain |  |  |  |  |

| `public?` | str_key | public?: true |  |  |  |  |


### AshSurfaceZoe.Projector.Human

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `.demo.mjs` | str_key | ".demo.mjs" => _ |  |  |  |  |

| `.human.mjs` | str_key | ".human.mjs" => _ |  |  |  |  |

| `human_surface` | str_key | human_surface: true |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |


### Boundary

| `aria` | str_key | aria: map() |  |  |  |  |

| `input` | str_key | input: %{optional(String.t()) => map()} |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() |  |  |  |  |

| `Boundary` | struct | defstruct input, output, zod, aria |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ input: %{optional(String.t()) => map()}, output: map() | nil, zod: String.t(), aria: map() } |  |  |  |  |


### CompositionSpecimens.Alpha

| `args` | str_key | args: [:name] |  |  |  |  |

| `describe` | str_key | describe: "Specimen extension A section" |  |  |  |  |

| `doc` | str_key | doc: "Singleton entity name (positional arg and identifier)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen weight" |  |  |  |  |

| `doc` | str_key | doc: "Specimen A label" |  |  |  |  |

| `entities` | str_key | entities: [ @entity ] |  |  |  |  |

| `identifier` | str_key | identifier: :name |  |  |  |  |

| `label` | str_key | label: [type: :string, doc: "Specimen A label"] |  |  |  |  |

| `name` | str_key | name: :entity |  |  |  |  |

| `name` | str_key | name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"] |  |  |  |  |

| `name` | str_key | name: :alpha |  |  |  |  |

| `schema` | str_key | schema: [ name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"], weight: [type: :integer, doc: "Specimen weight"] ] |  |  |  |  |

| `schema` | str_key | schema: [ label: [type: :string, doc: "Specimen A label"] ] |  |  |  |  |

| `sections` | str_key | sections: [@alpha] |  |  |  |  |

| `singleton_entity_keys` | str_key | singleton_entity_keys: [:entity] |  |  |  |  |

| `target` | str_key | target: CompositionSpecimens.Alpha.Entity |  |  |  |  |

| `transformers` | str_key | transformers: [CompositionSpecimens.Alpha.Persist] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: :integer |  |  |  |  |

| `type` | str_key | type: :string |  |  |  |  |

| `verifiers` | str_key | verifiers: [] |  |  |  |  |

| `weight` | str_key | weight: [type: :integer, doc: "Specimen weight"] |  |  |  |  |


### CompositionSpecimens.Alpha.Entity

| `__spark_metadata__` | str_key | __spark_metadata__: nil |  |  |  |  |

| `CompositionSpecimens.Alpha.Entity` | struct | defstruct name, weight, __identifier__, __spark_metadata__: nil |  |  |  |  |


### CompositionSpecimens.Alpha.Info

| `alpha` | function | alpha/1 |  |  |  |  |

| `compiled` | function | compiled/1 |  |  |  |  |

| `compiled?` | function | compiled?/1 |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |


### CompositionSpecimens.Alpha.Persist

| `transform` | function | transform/1 |  |  |  |  |

| `alpha` | str_key | alpha: alpha_entities |  |  |  |  |

| `alpha_label` | str_key | alpha_label: Spark.Dsl.Transformer.get_option(dsl_state, [:alpha], :label) |  |  |  |  |


### CompositionSpecimens.AlphaClash

| `args` | str_key | args: [:name] |  |  |  |  |

| `describe` | str_key | describe: "Specimen extension A' (clash mutant) section" |  |  |  |  |

| `doc` | str_key | doc: "Singleton entity name (positional arg and identifier)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen weight (clash mutant)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen A' label" |  |  |  |  |

| `entities` | str_key | entities: [ @entity ] |  |  |  |  |

| `identifier` | str_key | identifier: :name |  |  |  |  |

| `label` | str_key | label: [type: :string, doc: "Specimen A' label"] |  |  |  |  |

| `name` | str_key | name: :entity |  |  |  |  |

| `name` | str_key | name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"] |  |  |  |  |

| `name` | str_key | name: :alpha |  |  |  |  |

| `schema` | str_key | schema: [ name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"], weight: [type: :integer, doc: "Specimen weight (clash mutant)"] ] |  |  |  |  |

| `schema` | str_key | schema: [ label: [type: :string, doc: "Specimen A' label"] ] |  |  |  |  |

| `sections` | str_key | sections: [@alpha] |  |  |  |  |

| `singleton_entity_keys` | str_key | singleton_entity_keys: [:entity] |  |  |  |  |

| `target` | str_key | target: CompositionSpecimens.AlphaClash.Entity |  |  |  |  |

| `transformers` | str_key | transformers: [CompositionSpecimens.AlphaClash.Persist] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: :integer |  |  |  |  |

| `type` | str_key | type: :string |  |  |  |  |

| `verifiers` | str_key | verifiers: [] |  |  |  |  |

| `weight` | str_key | weight: [type: :integer, doc: "Specimen weight (clash mutant)"] |  |  |  |  |


### CompositionSpecimens.AlphaClash.Entity

| `__spark_metadata__` | str_key | __spark_metadata__: nil |  |  |  |  |

| `CompositionSpecimens.AlphaClash.Entity` | struct | defstruct name, weight, __identifier__, __spark_metadata__: nil |  |  |  |  |


### CompositionSpecimens.AlphaClash.Persist

| `transform` | function | transform/1 |  |  |  |  |

| `alpha` | str_key | alpha: alpha_entities |  |  |  |  |

| `alpha_label` | str_key | alpha_label: Spark.Dsl.Transformer.get_option(dsl_state, [:alpha], :label) |  |  |  |  |


### CompositionSpecimens.Beta

| `args` | str_key | args: [:name] |  |  |  |  |

| `count` | str_key | count: [type: :integer, doc: "Specimen count"] |  |  |  |  |

| `describe` | str_key | describe: "Specimen extension B section" |  |  |  |  |

| `doc` | str_key | doc: "Singleton entity name (positional arg and identifier)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen count" |  |  |  |  |

| `doc` | str_key | doc: "Specimen B label" |  |  |  |  |

| `entities` | str_key | entities: [ @entity ] |  |  |  |  |

| `identifier` | str_key | identifier: :name |  |  |  |  |

| `label` | str_key | label: [type: :string, doc: "Specimen B label"] |  |  |  |  |

| `name` | str_key | name: :entity |  |  |  |  |

| `name` | str_key | name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"] |  |  |  |  |

| `name` | str_key | name: :beta |  |  |  |  |

| `schema` | str_key | schema: [ name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"], count: [type: :integer, doc: "Specimen count"] ] |  |  |  |  |

| `schema` | str_key | schema: [ label: [type: :string, doc: "Specimen B label"] ] |  |  |  |  |

| `sections` | str_key | sections: [@beta] |  |  |  |  |

| `singleton_entity_keys` | str_key | singleton_entity_keys: [:entity] |  |  |  |  |

| `target` | str_key | target: CompositionSpecimens.Beta.Entity |  |  |  |  |

| `transformers` | str_key | transformers: [CompositionSpecimens.Beta.Persist] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: :integer |  |  |  |  |

| `type` | str_key | type: :string |  |  |  |  |

| `verifiers` | str_key | verifiers: [] |  |  |  |  |


### CompositionSpecimens.Beta.Entity

| `__spark_metadata__` | str_key | __spark_metadata__: nil |  |  |  |  |

| `CompositionSpecimens.Beta.Entity` | struct | defstruct name, count, __identifier__, __spark_metadata__: nil |  |  |  |  |


### CompositionSpecimens.Beta.Info

| `beta` | function | beta/1 |  |  |  |  |

| `compiled` | function | compiled/1 |  |  |  |  |

| `compiled?` | function | compiled?/1 |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |


### CompositionSpecimens.Beta.Persist

| `transform` | function | transform/1 |  |  |  |  |

| `beta` | str_key | beta: beta_entities |  |  |  |  |

| `beta_label` | str_key | beta_label: Spark.Dsl.Transformer.get_option(dsl_state, [:beta], :label) |  |  |  |  |


### CompositionSpecimens.Order

| `record` | function | record/1 |  |  |  |  |

| `recorded` | function | recorded/0 |  |  |  |  |

| `reset` | function | reset/0 |  |  |  |  |

| `table` | function | table/0 |  |  |  |  |

| `read_concurrency` | str_key | read_concurrency: true |  |  |  |  |


### CourtProbe.Mutant.PersistentTerm

| `after?` | function | after?/1 |  |  |  |  |

| `transform` | function | transform/1 |  |  |  |  |

| `mode` | str_key | mode: hidden |  |  |  |  |

| `name` | str_key | name: &1.name |  |  |  |  |

| `steps` | str_key | steps: steps |  |  |  |  |

| `via` | str_key | via: &1.via |  |  |  |  |


### Decision

| `action_id` | str_key | action_id: String.t() | nil |  |  |  |  |

| `available` | str_key | available: [atom()] |  |  |  |  |

| `declared` | str_key | declared: [atom()] |  |  |  |  |

| `dimensions` | str_key | dimensions: dimensions() |  |  |  |  |

| `dimensions` | str_key | dimensions: :undelegated |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched | :dispatched |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched |  |  |  |  |

| `fallback` | str_key | fallback: :pre_dispatch_only |  |  |  |  |

| `frontier` | str_key | frontier: [atom()] |  |  |  |  |

| `frontier` | str_key | frontier: [] |  |  |  |  |

| `preferred` | str_key | preferred: atom() |  |  |  |  |

| `reason` | str_key | reason: atom() |  |  |  |  |

| `selected` | str_key | selected: atom() |  |  |  |  |

| `Decision` | struct | defstruct action_id, declared, available, selected, preferred, reason, dispatch_state: :not_dispatched, fallback: :pre_dispatch_only, dimensions: :undelegated, frontier: [] |  |  |  |  |

| `dimensions` | type | @type dimensions :: :undelegated | :declared |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t() | nil, declared: [atom()], available: [atom()], selected: atom(), preferred: atom(), reason: atom(), dispatch_state: :not_dispatched | :dispatched, fallback: :pre_dispatch_only, dimensions: dimensions(), frontier: [atom()] } |  |  |  |  |


### Input

| `allow_nil?` | str_key | allow_nil?: boolean() |  |  |  |  |

| `description` | str_key | description: String.t() | nil |  |  |  |  |

| `name` | str_key | name: atom() | String.t() |  |  |  |  |

| `type` | str_key | type: Ash.Info.Manifest.Type.t() | atom() | nil |  |  |  |  |

| `Input` | struct | defstruct name, type, allow_nil?, description |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ name: atom() | String.t(), type: Ash.Info.Manifest.Type.t() | atom() | nil, allow_nil?: boolean(), description: String.t() | nil } |  |  |  |  |


### Input

| `default` | str_key | default: term() |  |  |  |  |

| `name` | str_key | name: atom() |  |  |  |  |

| `required` | str_key | required: boolean() |  |  |  |  |

| `type` | str_key | type: String.t() |  |  |  |  |

| `Input` | struct | defstruct name, type, required, default |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ name: atom(), type: String.t(), required: boolean(), default: term() } |  |  |  |  |


### Mix.Tasks.AshSurface.Install

| `igniter` | function | igniter/1 |  |  |  |  |

| `info` | function | info/2 |  |  |  |  |

| `example` | str_key | example: "mix ash_surface.install --target MyApp.SomeResource" |  |  |  |  |

| `group` | str_key | group: :ash_surface |  |  |  |  |

| `placement` | str_key | placement: :after |  |  |  |  |

| `positional` | str_key | positional: [] |  |  |  |  |

| `required` | str_key | required: [] |  |  |  |  |

| `schema` | str_key | schema: [target: :string] |  |  |  |  |

| `target` | str_key | target: :string |  |  |  |  |


### Output

| `returns` | str_key | returns: String.t() | nil |  |  |  |  |

| `Output` | struct | defstruct returns |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{returns: String.t() | nil} |  |  |  |  |


### Policy

| `bypass` | str_key | bypass: boolean() |  |  |  |  |

| `check` | str_key | check: String.t() |  |  |  |  |

| `checks` | str_key | checks: [check()] |  |  |  |  |

| `conditions` | str_key | conditions: [condition()] |  |  |  |  |

| `kind` | str_key | kind: atom() |  |  |  |  |

| `opts` | str_key | opts: map() |  |  |  |  |

| `Policy` | struct | defstruct bypass, conditions, checks |  |  |  |  |

| `check` | type | @type check :: %{check: String.t(), kind: atom()} |  |  |  |  |

| `condition` | type | @type condition :: %{check: String.t(), opts: map()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ bypass: boolean(), conditions: [condition()], checks: [check()] } |  |  |  |  |


### Presentation

| `format` | str_key | format: String.t() | nil |  |  |  |  |

| `group` | str_key | group: String.t() | nil |  |  |  |  |

| `label` | str_key | label: String.t() | nil |  |  |  |  |

| `order` | str_key | order: non_neg_integer() | nil |  |  |  |  |

| `widget` | str_key | widget: String.t() | atom() | nil |  |  |  |  |

| `Presentation` | struct | defstruct label, group, order, widget, format |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ label: String.t() | nil, group: String.t() | nil, order: non_neg_integer() | nil, widget: String.t() | atom() | nil, format: String.t() | nil } |  |  |  |  |


### Schema

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `inputs` | str_key | inputs: [Input.t()] |  |  |  |  |

| `presentation` | str_key | presentation: map() | nil |  |  |  |  |

| `Schema` | struct | defstruct action_id, inputs, presentation, aria |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t(), inputs: [Input.t()], presentation: map() | nil, aria: map() | nil } |  |  |  |  |


### Schema

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `input` | str_key | input: map() | nil |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() | nil |  |  |  |  |

| `Schema` | struct | defstruct input, output, zod, aria |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ input: map() | nil, output: map() | nil, zod: String.t() | nil, aria: map() | nil } |  |  |  |  |


### Semantic

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `Semantic` | struct | defstruct subject_iri, capability_iri, predicates, shape_id, ontology |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ subject_iri: String.t() | nil, capability_iri: String.t() | nil, predicates: [String.t()], shape_id: String.t() | nil, ontology: [String.t()] } |  |  |  |  |


### Semantic

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] | String.t() | nil |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `Semantic` | struct | defstruct subject_iri, capability_iri, predicates, shape_id, ontology |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ subject_iri: String.t() | nil, capability_iri: String.t() | nil, predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil, shape_id: String.t() | nil, ontology: [String.t()] | String.t() | nil } |  |  |  |  |


### SparkClosureConsumer.Example.Post

| `SparkClosureConsumer.Example.Post` | ash_resource |  |  |  |  |  |

| `data_layer` | str_key | data_layer: Ash.DataLayer.Ets |  |  |  |  |

| `domain` | str_key | domain: SparkClosureConsumer.Example |  |  |  |  |


### Surface

| `action_ids` | str_key | action_ids: [String.t()] |  |  |  |  |

| `contract` | str_key | contract: map() |  |  |  |  |

| `digest` | str_key | digest: String.t() |  |  |  |  |

| `manifest` | str_key | manifest: Ash.Info.Manifest.t() |  |  |  |  |

| `Surface` | struct | defstruct manifest, contract, digest, action_ids |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ manifest: Ash.Info.Manifest.t(), contract: map(), digest: String.t(), action_ids: [String.t()] } |  |  |  |  |


### ash_surface-js-projection

| `check` | script | node --check priv/static/ash_surface_runtime.mjs && node --check priv/static/ash_surface_playwright.mjs |  |  |  |  |

| `test` | script | node --test test/js/*.test.mjs |  |  |  |  |

| `test:coverage` | script | node --experimental-test-coverage --test test/js/*.test.mjs |  |  |  |  |


### ash_surface_zoe-js-projection

| `check` | script | node --check priv/static/ash_surface_zoe.mjs |  |  |  |  |

| `pretest` | script | node scripts/link_core_runtime.mjs |  |  |  |  |

| `test` | script | node --test test/js/*.test.mjs |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `action` | str_key | action: String.t() | atom() | nil |  |  |  |  |

| `action_type` | str_key | action_type: String.t() | atom() | nil |  |  |  |  |

| `inputs` | str_key | inputs: [map()] | map() | nil |  |  |  |  |

| `outputs` | str_key | outputs: [map()] | map() | nil |  |  |  |  |

| `policies` | str_key | policies: [map()] | nil |  |  |  |  |

| `resource` | str_key | resource: module() | String.t() | nil |  |  |  |  |

| `Ash` | struct | defstruct resource, action, action_type, inputs, outputs, policies |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ resource: module() | String.t() | nil, action: String.t() | atom() | nil, action_type: String.t() | atom() | nil, inputs: [map()] | map() | nil, outputs: [map()] | map() | nil, policies: [map()] | nil } |  |  |  |  |

| `action_id` | function | action_id/1 |  |  |  |  |

| `contract_digest` | function | contract_digest/1 |  |  |  |  |

| `delegated` | function | delegated/2 |  |  |  |  |

| `from_app` | function | from_app/2 |  |  |  |  |

| `from_manifest` | function | from_manifest/2 |  |  |  |  |

| `project` | function | project/3 |  |  |  |  |

| `runtime_path` | function | runtime_path/0 |  |  |  |  |

| `runtime_source` | function | runtime_source/0 |  |  |  |  |

| `schema_version` | function | schema_version/0 |  |  |  |  |

| `verify_surface_digest` | function | verify_surface_digest/1 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `action` | str_key | action: %{action | custom: custom} |  |  |  |  |

| `action_ids` | str_key | action_ids: [String.t()] |  |  |  |  |

| `action_ids` | str_key | action_ids: action_ids |  |  |  |  |

| `action_profile_must_be_a_map` | str_key | {:error, {:action_profile_must_be_a_map, id, action_profile}} |  |  |  |  |

| `actions` | str_key | Map.get("actions") |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `ashManifestSchemaVersion` | str_key | "ashManifestSchemaVersion" => _ |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `contract` | str_key | contract: map() |  |  |  |  |

| `contract` | str_key | contract: contract |  |  |  |  |

| `custom` | str_key | custom: custom |  |  |  |  |

| `custom` | str_key | custom: root_custom |  |  |  |  |

| `digest` | str_key | digest: String.t() |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `digest` | str_key | digest: claimed |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `entrypoints` | str_key | entrypoints: entrypoints |  |  |  |  |

| `evidenceRequired` | str_key | "evidenceRequired" => _ |  |  |  |  |

| `evidenceRequired` | str_key | Map.get("evidenceRequired") |  |  |  |  |

| `evidence_required_must_be_boolean` | str_key | {:error, {:evidence_required_must_be_boolean, id, evidence}} |  |  |  |  |

| `generatorIdentity` | str_key | "generatorIdentity" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `manifest` | str_key | manifest: Ash.Info.Manifest.t() |  |  |  |  |

| `manifest` | str_key | manifest: decorated |  |  |  |  |

| `manifest` | str_key | "manifest" => _ |  |  |  |  |

| `manifestDigest` | str_key | "manifestDigest" => _ |  |  |  |  |

| `marketplaceIdentity` | str_key | "marketplaceIdentity" => _ |  |  |  |  |

| `otp_app` | str_key | otp_app: otp_app |  |  |  |  |

| `possibleRefusals` | str_key | "possibleRefusals" => _ |  |  |  |  |

| `possibleRefusals` | str_key | Map.get("possibleRefusals") |  |  |  |  |

| `possible_refusal_not_a_refusal_code` | str_key | {:error, {:possible_refusal_not_a_refusal_code, id, bad}} |  |  |  |  |

| `possible_refusals_must_be_strings` | str_key | {:error, {:possible_refusals_must_be_strings, id, refusals}} |  |  |  |  |

| `profile` | str_key | Keyword.get("profile") |  |  |  |  |

| `profile` | str_key | "profile" => _ |  |  |  |  |

| `profile_actions_must_be_a_map` | str_key | {:error, :profile_actions_must_be_a_map} |  |  |  |  |

| `profile_key_not_serializable` | str_key | {:error, {:profile_key_not_serializable, key}} |  |  |  |  |

| `profile_must_be_a_map` | str_key | {:error, :profile_must_be_a_map} |  |  |  |  |

| `profile_value_not_serializable` | str_key | {:error, {:profile_value_not_serializable, value}} |  |  |  |  |

| `receiptRequired` | str_key | "receiptRequired" => _ |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `resource` | str_key | "resource" => _ |  |  |  |  |

| `schemaVersion` | str_key | "schemaVersion" => _ |  |  |  |  |

| `semanticId` | str_key | "semanticId" => _ |  |  |  |  |

| `surface` | str_key | "surface" => _ |  |  |  |  |

| `surfaceSchemaVersion` | str_key | "surfaceSchemaVersion" => _ |  |  |  |  |

| `surface_digest_mismatch` | str_key | {:error, {:surface_digest_mismatch, term(), String.t()}} |  |  |  |  |

| `surface_digest_mismatch` | str_key | {:error, {:surface_digest_mismatch, claimed, actual}} |  |  |  |  |

| `unknown_action_profile` | str_key | {:error, {:unknown_action_profile, unknown}} |  |  |  |  |

| `unsupported_projector` | str_key | {:error, {:unsupported_projector, projector}} |  |  |  |  |

| `agent_card_fragment` | function | agent_card_fragment/2 |  |  |  |  |

| `skills` | function | skills/1 |  |  |  |  |

| `description` | str_key | description: String.t() |  |  |  |  |

| `description` | str_key | description: Keyword.get( opts, :description, "ash_surface MX/agent surface projection " <> "(ash_surface v" <> AshSurface.schema_version() <> "). " <> "Authority: this card is descriptive only and grants no " <> "authority; consequential DO is reachable only through a " <> "receipted admission boundary." ) |  |  |  |  |

| `description` | str_key | Keyword.get("description") |  |  |  |  |

| `name` | str_key | name: String.t() |  |  |  |  |

| `name` | str_key | name: Keyword.get(opts, :name, "ash_surface") |  |  |  |  |

| `name` | str_key | Keyword.get("name") |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |

| `url` | str_key | url: String.t() |  |  |  |  |

| `url` | str_key | url: Keyword.get(opts, :url, "http: |  |  |  |  |

| `url` | str_key | Keyword.get("url") |  |  |  |  |

| `version` | str_key | version: String.t() |  |  |  |  |

| `version` | str_key | version: Keyword.get(opts, :version, AshSurface.schema_version()) |  |  |  |  |

| `version` | str_key | Keyword.get("version") |  |  |  |  |

| `opts` | type | @type opts :: [ name: String.t(), description: String.t(), url: String.t(), version: String.t() ] |  |  |  |  |

| `default_path` | function | default_path/0 |  |  |  |  |

| `persist` | function | persist/2 |  |  |  |  |

| `serialize` | function | serialize/1 |  |  |  |  |

| `capabilities` | str_key | "capabilities" => _ |  |  |  |  |

| `defaultInputModes` | str_key | "defaultInputModes" => _ |  |  |  |  |

| `defaultOutputModes` | str_key | "defaultOutputModes" => _ |  |  |  |  |

| `description` | str_key | "description" => _ |  |  |  |  |

| `documentationUrl` | str_key | "documentationUrl" => _ |  |  |  |  |

| `iconUrl` | str_key | "iconUrl" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `pretty` | str_key | pretty: true |  |  |  |  |

| `protocolBinding` | str_key | "protocolBinding" => _ |  |  |  |  |

| `protocolVersion` | str_key | "protocolVersion" => _ |  |  |  |  |

| `provider` | str_key | "provider" => _ |  |  |  |  |

| `securitySchemes` | str_key | "securitySchemes" => _ |  |  |  |  |

| `skills` | str_key | "skills" => _ |  |  |  |  |

| `supportedInterfaces` | str_key | "supportedInterfaces" => _ |  |  |  |  |

| `tags` | str_key | "tags" => _ |  |  |  |  |

| `url` | str_key | "url" => _ |  |  |  |  |

| `version` | str_key | "version" => _ |  |  |  |  |

| `encode` | function | encode/1 |  |  |  |  |

| `sha256_hex` | function | sha256_hex/1 |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `actuation_authority?` | function | actuation_authority?/1 |  |  |  |  |

| `authority_ceiling` | function | authority_ceiling/0 |  |  |  |  |

| `canonical_truth?` | function | canonical_truth?/1 |  |  |  |  |

| `donors` | function | donors/0 |  |  |  |  |

| `fetch` | function | fetch/1 |  |  |  |  |

| `owner_capability` | function | owner_capability/0 |  |  |  |  |

| `projection_source` | function | projection_source/0 |  |  |  |  |

| `capability` | str_key | capability: :mobile_surface |  |  |  |  |

| `capability` | str_key | capability: :semantic_document_projection |  |  |  |  |

| `disposition` | str_key | disposition: :wrap |  |  |  |  |

| `disposition` | str_key | disposition: :candidate_wrap |  |  |  |  |

| `placement` | str_key | placement: :mobile_surface |  |  |  |  |

| `placement` | str_key | placement: :powerless_document_projection |  |  |  |  |

| `repository` | str_key | repository: "seanchatmangpt/ash_expo" |  |  |  |  |

| `repository` | str_key | repository: "seanchatmangpt/mmdio" |  |  |  |  |

| `sha` | str_key | sha: "024852b92330c76e12d0ab26531ef1e511c71041" |  |  |  |  |

| `sha` | str_key | sha: "afc1f6e890a6d1c17b84d5931b21d3c74a851ebc" |  |  |  |  |

| `unknown_castle_surface_donor` | str_key | {:error, :unknown_castle_surface_donor} |  |  |  |  |

| `create` | function | create/2 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `__struct__` | str_key | __struct__: ^module |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `capabilities` | str_key | capabilities: [map()] |  |  |  |  |

| `capabilities` | str_key | Keyword.get("capabilities") |  |  |  |  |

| `capabilities` | str_key | capabilities: Enum.sort_by(capabilities, &canonical_key/1) |  |  |  |  |

| `capabilities` | str_key | capabilities: capabilities |  |  |  |  |

| `capabilities` | str_key | "capabilities" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [String.t()] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: String.t() |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `obligations` | str_key | obligations: [Obligation.t()] |  |  |  |  |

| `obligations` | str_key | Keyword.get("obligations") |  |  |  |  |

| `obligations` | str_key | obligations: obligations |> Enum.map(&Obligation.to_map/1) |> Enum.sort_by(& &1["obligationId"]) |  |  |  |  |

| `obligations` | str_key | obligations: obligations |  |  |  |  |

| `obligations` | str_key | "obligations" => _ |  |  |  |  |

| `observations` | str_key | observations: [Observation.t()] |  |  |  |  |

| `observations` | str_key | Keyword.get("observations") |  |  |  |  |

| `observations` | str_key | observations: observations |> Enum.map(&Observation.to_map/1) |> Enum.sort_by(& &1["observationId"]) |  |  |  |  |

| `observations` | str_key | observations: observations |  |  |  |  |

| `observations` | str_key | "observations" => _ |  |  |  |  |

| `planningEpisodes` | str_key | "planningEpisodes" => _ |  |  |  |  |

| `planning_episodes` | str_key | planning_episodes: [PlanningEpisode.t()] |  |  |  |  |

| `planning_episodes` | str_key | Keyword.get("planning_episodes") |  |  |  |  |

| `planning_episodes` | str_key | planning_episodes: planning_episodes |> Enum.map(&PlanningEpisode.to_map/1) |> Enum.sort_by(& &1["episodeId"]) |  |  |  |  |

| `planning_episodes` | str_key | planning_episodes: planning_episodes |  |  |  |  |

| `projectionId` | str_key | "projectionId" => _ |  |  |  |  |

| `projection_id` | str_key | projection_id: String.t() |  |  |  |  |

| `projection_id` | str_key | projection_id: "cc_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [String.t()] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipt_refs) |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipt_refs |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | standing: :ALIVE | :PARTIAL_ALIVE | :REFUSED | :BLOCKED |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `AshSurface.CommandCenter` | struct | defstruct projection_id, exact_subject, state_digest, observations, obligations, planning_episodes, capabilities, receipt_refs, evidence_refs: [], standing: :PARTIAL_ALIVE, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ projection_id: String.t(), exact_subject: String.t(), state_digest: String.t(), observations: [Observation.t()], obligations: [Obligation.t()], planning_episodes: [PlanningEpisode.t()], capabilities: [map()], receipt_refs: [String.t()], evidence_refs: [String.t()], standing: :ALIVE | :PARTIAL_ALIVE | :REFUSED | :BLOCKED, authority_boundary: :OBSERVE } |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `actionRef` | str_key | "actionRef" => _ |  |  |  |  |

| `action_ref` | str_key | action_ref: action_ref |  |  |  |  |

| `authorityCeiling` | str_key | "authorityCeiling" => _ |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :CONSTRUCT |  |  |  |  |

| `boundaryId` | str_key | "boundaryId" => _ |  |  |  |  |

| `boundary_id` | str_key | boundary_id: "cb_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `confirmationRequired` | str_key | "confirmationRequired" => _ |  |  |  |  |

| `confirmationState` | str_key | "confirmationState" => _ |  |  |  |  |

| `confirmation_required` | str_key | confirmation_required: true |  |  |  |  |

| `confirmation_state` | str_key | Keyword.get("confirmation_state") |  |  |  |  |

| `confirmation_state` | str_key | confirmation_state: confirmation_state |  |  |  |  |

| `consequenceSummary` | str_key | "consequenceSummary" => _ |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: consequence_summary |  |  |  |  |

| `constructRef` | str_key | "constructRef" => _ |  |  |  |  |

| `construct_ref` | str_key | construct_ref: Keyword.get(opts, :construct_ref) |  |  |  |  |

| `construct_ref` | str_key | Keyword.get("construct_ref") |  |  |  |  |

| `construct_ref` | str_key | construct_ref: canonical.construct_ref |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `expiresAt` | str_key | "expiresAt" => _ |  |  |  |  |

| `expires_at` | str_key | expires_at: normalize_datetime(Keyword.get(opts, :expires_at)) |  |  |  |  |

| `expires_at` | str_key | Keyword.get("expires_at") |  |  |  |  |

| `expires_at` | str_key | expires_at: Keyword.get(opts, :expires_at) |  |  |  |  |

| `externalEffects` | str_key | "externalEffects" => _ |  |  |  |  |

| `external_effects` | str_key | external_effects: [] |  |  |  |  |

| `external_effects` | str_key | Keyword.get("external_effects") |  |  |  |  |

| `external_effects` | str_key | external_effects: Enum.sort(effects) |  |  |  |  |

| `external_effects` | str_key | external_effects: effects |  |  |  |  |

| `nextHandoff` | str_key | "nextHandoff" => _ |  |  |  |  |

| `next_handoff` | str_key | next_handoff: :BRCE |  |  |  |  |

| `reversibility` | str_key | Keyword.get("reversibility") |  |  |  |  |

| `reversibility` | str_key | reversibility: reversibility |  |  |  |  |

| `reversibility` | str_key | "reversibility" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `whyThisRef` | str_key | "whyThisRef" => _ |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: Keyword.get(opts, :why_this_ref) |  |  |  |  |

| `why_this_ref` | str_key | Keyword.get("why_this_ref") |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: canonical.why_this_ref |  |  |  |  |

| `AshSurface.CommitmentBoundary` | struct | defstruct boundary_id, subject_ref, action_ref, consequence_summary, reversibility, confirmation_state, construct_ref, why_this_ref, expires_at, state_digest, external_effects: [], evidence_refs: [], confirmation_required: true, next_handoff: :BRCE, authority_ceiling: :CONSTRUCT |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `compile` | function | compile/1 |  |  |  |  |

| `compile` | function | compile/2 |  |  |  |  |

| `action` | str_key | action: action.name |  |  |  |  |

| `action_id` | str_key | action_id: id |  |  |  |  |

| `action_type` | str_key | action_type: action.type |  |  |  |  |

| `actions` | str_key | actions: count |  |  |  |  |

| `allow_nil` | str_key | allow_nil: !!&1.allow_nil? |  |  |  |  |

| `ash` | str_key | ash: AshSurface.Compiler.Section.Ash |  |  |  |  |

| `ash` | str_key | ash: built.ash |  |  |  |  |

| `capability` | str_key | capability: AshSurface.Compiler.Section.Capability |  |  |  |  |

| `capability` | str_key | capability: built.capability |  |  |  |  |

| `custom` | str_key | custom: Map.get(action, :custom) || %{} |  |  |  |  |

| `custom` | str_key | Map.get("custom") |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `discovery` | str_key | discovery: receipt |  |  |  |  |

| `entrypoints` | str_key | entrypoints: entrypoints |  |  |  |  |

| `has_default` | str_key | has_default: !!&1.has_default? |  |  |  |  |

| `has_default` | str_key | has_default: !is_nil(&1.default) |  |  |  |  |

| `id` | str_key | id: action_id(resource, action.name) |  |  |  |  |

| `inputs` | str_key | inputs: action.inputs |> Kernel.||([]) |> Enum.map( &%{ name: to_string(&1.name), type: manifest_type_kind(Map.get(&1, :type)), allow_nil: !!&1.allow_nil?, has_default: !!&1.has_default? } ) |> Enum.sort_by(& &1.name) |  |  |  |  |

| `inputs` | str_key | inputs: action.arguments |> Kernel.||([]) |> Enum.filter(& &1.public?) |> Enum.map( &%{ name: to_string(&1.name), type: short_name_kind(Map.get(&1, :type)), allow_nil: !!&1.allow_nil?, has_default: !is_nil(&1.default) } ) |> Enum.sort_by(& &1.name) |  |  |  |  |

| `invalid_section_module` | str_key | {:error, {:invalid_section_module, key, module}} |  |  |  |  |

| `kind` | str_key | kind: kind |  |  |  |  |

| `missing_section_keys` | str_key | {:error, {:missing_section_keys, missing}} |  |  |  |  |

| `name` | str_key | name: to_string(&1.name) |  |  |  |  |

| `no_sections` | str_key | {:error, :no_sections} |  |  |  |  |

| `outputs` | str_key | outputs: action.metadata |> Kernel.||([]) |> Enum.map(&to_string(&1.name)) |> Enum.sort() |  |  |  |  |

| `presentation` | str_key | presentation: AshSurface.Compiler.Section.Presentation |  |  |  |  |

| `presentation` | str_key | presentation: built.presentation |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `resource_name` | str_key | resource_name: module_name(resource) |  |  |  |  |

| `schema` | str_key | schema: AshSurface.Compiler.Section.Schema |  |  |  |  |

| `schema` | str_key | schema: built.schema |  |  |  |  |

| `section_failed` | str_key | {:error, {:section_failed, id, reason}} |  |  |  |  |

| `sections` | str_key | Keyword.get("sections") |  |  |  |  |

| `sections_must_bind_keys_to_modules` | str_key | {:error, {:sections_must_bind_keys_to_modules, sections}} |  |  |  |  |

| `sections_must_bind_keys_to_modules` | str_key | {:error, {:sections_must_bind_keys_to_modules, other}} |  |  |  |  |

| `semantic` | str_key | semantic: AshSurface.Compiler.Section.Semantic |  |  |  |  |

| `semantic` | str_key | semantic: built.semantic |  |  |  |  |

| `source` | str_key | source: source |  |  |  |  |

| `token` | str_key | token: :erlang.unique_integer([:positive, :monotonic]) |  |  |  |  |

| `type` | str_key | type: manifest_type_kind(Map.get(&1, :type)) |  |  |  |  |

| `type` | str_key | Map.get("type") |  |  |  |  |

| `type` | str_key | type: short_name_kind(Map.get(&1, :type)) |  |  |  |  |

| `unknown_section_keys` | str_key | {:error, {:unknown_section_keys, unknown}} |  |  |  |  |

| `unsupported_source` | str_key | {:error, {:unsupported_source, domain}} |  |  |  |  |

| `unsupported_source` | str_key | {:error, {:unsupported_source, source}} |  |  |  |  |

| `version` | str_key | version: @ir_version |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `describedby_id` | function | describedby_id/2 |  |  |  |  |

| `mount` | function | mount/2 |  |  |  |  |

| `name` | function | name/0 |  |  |  |  |

| `role_for_type` | function | role_for_type/1 |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: Map.get(input, :allow_nil?) |  |  |  |  |

| `allow_nil?` | str_key | Map.get("allow_nil?") |  |  |  |  |

| `aria` | str_key | aria: aria |  |  |  |  |

| `boolean` | str_key | boolean: "checkbox" |  |  |  |  |

| `ci_string` | str_key | ci_string: "textbox" |  |  |  |  |

| `describedby` | str_key | "describedby" => _ |  |  |  |  |

| `description` | str_key | description: Map.get(input, :description) |  |  |  |  |

| `description` | str_key | Map.get("description") |  |  |  |  |

| `enum` | str_key | enum: "switch" |  |  |  |  |

| `inputs` | str_key | Map.get("inputs") |  |  |  |  |

| `integer` | str_key | integer: "slider" |  |  |  |  |

| `invalid_presentation` | str_key | {:error, {:invalid_presentation, presentation}} |  |  |  |  |

| `invalid_presentation` | str_key | {:error, {:invalid_presentation, other}} |  |  |  |  |

| `kind` | str_key | kind: kind |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `label` | str_key | Map.get("label") |  |  |  |  |

| `missing_action_id` | str_key | {:error, :missing_action_id} |  |  |  |  |

| `name` | str_key | name: Map.get(input, :name) |  |  |  |  |

| `name` | str_key | Map.get("name") |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `role` | str_key | "role" => _ |  |  |  |  |

| `string` | str_key | string: "textbox" |  |  |  |  |

| `type` | str_key | type: Map.get(input, :type) |  |  |  |  |

| `type` | str_key | Map.get("type") |  |  |  |  |

| `admitted_keys` | function | admitted_keys/0 |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `section` | function | section/2 |  |  |  |  |

| `action` | str_key | action: act.name |  |  |  |  |

| `action` | str_key | action: node.action |  |  |  |  |

| `action_type` | str_key | action_type: act.type |  |  |  |  |

| `action_type` | str_key | action_type: node.action_type |  |  |  |  |

| `bypass` | str_key | bypass: policy.bypass? == true |  |  |  |  |

| `bypass` | str_key | bypass: policy.bypass |  |  |  |  |

| `check` | str_key | check: inspect(module) |  |  |  |  |

| `check` | str_key | check: inspect(check.check_module) |  |  |  |  |

| `checks` | str_key | checks: Enum.map(policy.policies, &check_fact/1) |  |  |  |  |

| `checks` | str_key | checks: policy.checks |  |  |  |  |

| `conditions` | str_key | conditions: Enum.map(policy.condition, &condition_fact/1) |  |  |  |  |

| `conditions` | str_key | conditions: policy.conditions |  |  |  |  |

| `default` | str_key | default: argument.default |  |  |  |  |

| `default` | str_key | default: input.default |  |  |  |  |

| `fabricated_fact` | str_key | {:error, {:fabricated_fact, kind, actual}} |  |  |  |  |

| `input` | str_key | input: [atom()] |  |  |  |  |

| `input` | str_key | input: @admitted_input_keys |  |  |  |  |

| `inputs` | str_key | inputs: inputs(act) |  |  |  |  |

| `inputs` | str_key | inputs: Enum.map(node.inputs, &input_fact/1) |  |  |  |  |

| `kind` | str_key | kind: check.type |  |  |  |  |

| `name` | str_key | name: argument.name |  |  |  |  |

| `name` | str_key | name: input.name |  |  |  |  |

| `not_an_ash_resource` | str_key | {:error, {:not_an_ash_resource, resource}} |  |  |  |  |

| `opts` | str_key | opts: authored_opts(opts) |  |  |  |  |

| `output` | str_key | output: [atom()] |  |  |  |  |

| `output` | str_key | output: @admitted_output_keys |  |  |  |  |

| `outputs` | str_key | outputs: outputs(act) |  |  |  |  |

| `outputs` | str_key | outputs: output_fact(node.outputs) |  |  |  |  |

| `policies` | str_key | policies: policies(resource) |  |  |  |  |

| `policies` | str_key | policies: Enum.map(node.policies, &policy_fact/1) |  |  |  |  |

| `policy` | str_key | policy: [atom()] |  |  |  |  |

| `policy` | str_key | policy: @admitted_policy_keys |  |  |  |  |

| `required` | str_key | required: not argument.allow_nil? |  |  |  |  |

| `required` | str_key | required: input.required |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `resource` | str_key | resource: inspect(node.resource) |  |  |  |  |

| `returns` | str_key | Map.get("returns") |  |  |  |  |

| `returns` | str_key | returns: type_name(type) |  |  |  |  |

| `returns` | str_key | returns: output.returns |  |  |  |  |

| `section` | str_key | section: @section |  |  |  |  |

| `section` | str_key | section: [atom()] |  |  |  |  |

| `section` | str_key | section: @admitted_section_keys |  |  |  |  |

| `type` | str_key | type: type_name(argument.type) |  |  |  |  |

| `type` | str_key | type: input.type |  |  |  |  |

| `unknown_public_action` | str_key | {:error, {:unknown_public_action, action, public |> Enum.map(& &1.name) |> Enum.sort()}} |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `__struct__` | str_key | __struct__: AshA2A.Skill |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `authority_required` | str_key | authority_required: command_bus_authority_requirement(consequence) |  |  |  |  |

| `capability_id` | str_key | capability_id: id |  |  |  |  |

| `consequence` | str_key | consequence: consequence |  |  |  |  |

| `consequence_class` | str_key | consequence_class: consequence |  |  |  |  |

| `id` | str_key | id: id |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `receipt_required` | str_key | receipt_required: receipt_required?(consequence) |  |  |  |  |

| `resource` | str_key | Map.get("resource") |  |  |  |  |

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: boolean() |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `aria` | str_key | aria: map() |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `description` | str_key | description: String.t() | nil |  |  |  |  |

| `input` | str_key | input: %{optional(String.t()) => map()} |  |  |  |  |

| `inputs` | str_key | inputs: [Input.t()] |  |  |  |  |

| `name` | str_key | name: atom() | String.t() |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] |  |  |  |  |

| `presentation` | str_key | presentation: map() | nil |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `type` | str_key | type: Ash.Info.Manifest.Type.t() | atom() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() |  |  |  |  |

| `authority_required` | str_key | authority_required: boolean() | nil |  |  |  |  |

| `capability_id` | str_key | capability_id: String.t() | nil |  |  |  |  |

| `consequence_class` | str_key | consequence_class: consequence_class() | nil |  |  |  |  |

| `receipt_required` | str_key | receipt_required: boolean() | nil |  |  |  |  |

| `AshSurface.Compiler.IR.Capability` | struct | defstruct capability_id, consequence_class, authority_required, receipt_required |  |  |  |  |

| `consequence_class` | type | @type consequence_class :: :observe | :change | :external_do | :unknown |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ capability_id: String.t() | nil, consequence_class: consequence_class() | nil, authority_required: boolean() | nil, receipt_required: boolean() | nil } |  |  |  |  |

| `format` | str_key | format: nil |  |  |  |  |

| `format` | str_key | format: String.t() | nil |  |  |  |  |

| `group` | str_key | group: nil |  |  |  |  |

| `group` | str_key | group: String.t() | nil |  |  |  |  |

| `label` | str_key | label: nil |  |  |  |  |

| `label` | str_key | label: String.t() |  |  |  |  |

| `order` | str_key | order: 0 |  |  |  |  |

| `order` | str_key | order: number() |  |  |  |  |

| `widget` | str_key | widget: "default" |  |  |  |  |

| `widget` | str_key | widget: String.t() |  |  |  |  |

| `AshSurface.Compiler.IR.Presentation` | struct | defstruct label: nil, group: nil, order: 0, widget: "default", format: nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ label: String.t(), group: String.t() | nil, order: number(), widget: String.t(), format: String.t() | nil } |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `ash_surface` | str_key | Map.get("ash_surface") |  |  |  |  |

| `code` | str_key | code: "unknown_widget_presentation" |  |  |  |  |

| `code` | str_key | code: "invalid_presentation_compilation" |  |  |  |  |

| `detail` | str_key | detail: "presentation for #{inspect(name)} declares widget #{inspect(widget)}; admitted widgets are " <> inspect(@admitted_widgets) |  |  |  |  |

| `detail` | str_key | detail: detail |  |  |  |  |

| `format` | str_key | format: overrides["format"] |  |  |  |  |

| `group` | str_key | group: overrides["group"] |  |  |  |  |

| `label` | str_key | label: overrides["label"] || humanize(name) |  |  |  |  |

| `name` | str_key | name: name |  |  |  |  |

| `order` | str_key | order: overrides["order"] || 0 |  |  |  |  |

| `presentation` | str_key | Map.get("presentation") |  |  |  |  |

| `widget` | str_key | widget: overrides["widget"] || "default" |  |  |  |  |

| `widget` | str_key | "widget" => _ |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `action_count` | str_key | action_count: non_neg_integer() |  |  |  |  |

| `action_count` | str_key | action_count: map_size(ir) |  |  |  |  |

| `action_without_id` | str_key | {:error, {:action_without_id, other}} |  |  |  |  |

| `actions` | str_key | Map.get("actions") |  |  |  |  |

| `actions_must_be_a_list` | str_key | {:error, {:actions_must_be_a_list, other}} |  |  |  |  |

| `argument_count` | str_key | argument_count: non_neg_integer() |  |  |  |  |

| `argument_count` | str_key | argument_count: arg_count |  |  |  |  |

| `argument_without_name` | str_key | {:error, {:argument_without_name, id}} |  |  |  |  |

| `arguments` | str_key | Map.get("arguments") |  |  |  |  |

| `arguments_must_be_a_list` | str_key | {:error, {:arguments_must_be_a_list, id, other}} |  |  |  |  |

| `aria` | str_key | aria: render_aria(id, args) |  |  |  |  |

| `array` | str_key | "array" => _ |  |  |  |  |

| `boolean` | str_key | "boolean" => _ |  |  |  |  |

| `datetime` | str_key | "datetime" => _ |  |  |  |  |

| `decimal` | str_key | "decimal" => _ |  |  |  |  |

| `discovery_must_be_a_map` | str_key | {:error, :discovery_must_be_a_map} |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `input` | str_key | input: input |  |  |  |  |

| `integer` | str_key | "integer" => _ |  |  |  |  |

| `invalid_returns` | str_key | {:error, {:invalid_returns, id, other}} |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `map` | str_key | "map" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `output` | str_key | output: returns |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `returns` | str_key | Map.get("returns") |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `type` | str_key | "type" => _ |  |  |  |  |

| `utc_datetime` | str_key | "utc_datetime" => _ |  |  |  |  |

| `uuid` | str_key | "uuid" => _ |  |  |  |  |

| `z.unknown()` | str_key | Map.get("z.unknown()") |  |  |  |  |

| `zod` | str_key | zod: render_zod(id, args, returns) |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `resource` | str_key | Map.get("resource") |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `as` | str_key | as: CapabilitySection |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `custom` | str_key | Map.get("custom") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `action_missing_from_schema_section` | str_key | {:error, {:action_missing_from_schema_section, id}} |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `allow_nil` | str_key | Map.get("allow_nil") |  |  |  |  |

| `allow_nil?` | str_key | "allow_nil?" => _ |  |  |  |  |

| `arguments` | str_key | "arguments" => _ |  |  |  |  |

| `id` | str_key | Map.get("id") |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `inputs` | str_key | Map.get("inputs") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `name` | str_key | Map.get("name") |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `name` | str_key | Map.fetch!("name") |  |  |  |  |

| `returns` | str_key | "returns" => _ |  |  |  |  |

| `type` | str_key | Map.get("type") |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | Map.get("action") |  |  |  |  |

| `invalid_action_entry` | str_key | {:error, {:invalid_action_entry, action}} |  |  |  |  |

| `resource` | str_key | Map.get("resource") |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `as` | str_key | as: R2RMLInfo |  |  |  |  |

| `capability_iri` | str_key | capability_iri: capability |  |  |  |  |

| `capture` | str_key | capture: :all_names |  |  |  |  |

| `class_iris` | str_key | class_iris: [capability | _] |  |  |  |  |

| `class_iris` | str_key | class_iris: [] |  |  |  |  |

| `ontology` | str_key | ontology: ontology(mapping) |  |  |  |  |

| `predicates` | str_key | predicates: predicates(mapping) |  |  |  |  |

| `resources` | str_key | resources: [mapping] |  |  |  |  |

| `shape_id` | str_key | shape_id: shape_id(mapping, capability) |  |  |  |  |

| `subject_iri` | str_key | subject_iri: subject_iri(mapping) |  |  |  |  |

| `subject_map` | str_key | subject_map: %{term_type: :iri, value: value} |  |  |  |  |

| `subject_map` | str_key | subject_map: %{term_type: :blank_node} |  |  |  |  |

| `term_type` | str_key | term_type: :iri |  |  |  |  |

| `term_type` | str_key | term_type: :blank_node |  |  |  |  |

| `value` | str_key | value: value |  |  |  |  |

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `audioRef` | str_key | Map.get("audioRef") |  |  |  |  |

| `audioRef` | str_key | "audioRef" => _ |  |  |  |  |

| `audio_ref` | str_key | Map.get("audio_ref") |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `completionReceiptRef` | str_key | "completionReceiptRef" => _ |  |  |  |  |

| `completion_receipt_ref` | str_key | Keyword.get("completion_receipt_ref") |  |  |  |  |

| `completion_receipt_ref` | str_key | completion_receipt_ref: completion_receipt_ref |  |  |  |  |

| `continuousPlay` | str_key | "continuousPlay" => _ |  |  |  |  |

| `continuous_play` | str_key | continuous_play: true |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `durationSeconds` | str_key | Map.get("durationSeconds") |  |  |  |  |

| `durationSeconds` | str_key | "durationSeconds" => _ |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: duration_seconds |  |  |  |  |

| `duration_seconds` | str_key | Map.get("duration_seconds") |  |  |  |  |

| `episodeId` | str_key | "episodeId" => _ |  |  |  |  |

| `episode_id` | str_key | episode_id: "dev_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `hypothesisRefs` | str_key | "hypothesisRefs" => _ |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: [] |  |  |  |  |

| `hypothesis_refs` | str_key | Keyword.get("hypothesis_refs") |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: Enum.sort(hypothesis_refs) |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: hypothesis_refs |  |  |  |  |

| `kind` | str_key | Map.get("kind") |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `label` | str_key | Map.get("label") |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `message` | str_key | message: "unknown devotional segment kind: #{inspect(value)}" |  |  |  |  |

| `playbackPolicy` | str_key | "playbackPolicy" => _ |  |  |  |  |

| `playback_policy` | str_key | playback_policy: :STRAIGHT_THROUGH |  |  |  |  |

| `position` | str_key | "position" => _ |  |  |  |  |

| `ref` | str_key | Map.get("ref") |  |  |  |  |

| `ref` | str_key | "ref" => _ |  |  |  |  |

| `segments` | str_key | segments: [] |  |  |  |  |

| `segments` | str_key | segments: normalized_segments |  |  |  |  |

| `segments` | str_key | "segments" => _ |  |  |  |  |

| `sourceRefs` | str_key | "sourceRefs" => _ |  |  |  |  |

| `source_refs` | str_key | source_refs: [] |  |  |  |  |

| `source_refs` | str_key | Keyword.get("source_refs") |  |  |  |  |

| `source_refs` | str_key | source_refs: Enum.sort(source_refs) |  |  |  |  |

| `source_refs` | str_key | source_refs: source_refs |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `status` | str_key | Keyword.get("status") |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `subtitle` | str_key | subtitle: Keyword.get(opts, :subtitle) |  |  |  |  |

| `subtitle` | str_key | Keyword.get("subtitle") |  |  |  |  |

| `subtitle` | str_key | subtitle: canonical.subtitle |  |  |  |  |

| `subtitle` | str_key | "subtitle" => _ |  |  |  |  |

| `title` | str_key | title: title |  |  |  |  |

| `title` | str_key | "title" => _ |  |  |  |  |

| `whyThisRef` | str_key | "whyThisRef" => _ |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: Keyword.get(opts, :why_this_ref) |  |  |  |  |

| `why_this_ref` | str_key | Keyword.get("why_this_ref") |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: canonical.why_this_ref |  |  |  |  |

| `AshSurface.DevotionalEpisode` | struct | defstruct episode_id, title, subtitle, why_this_ref, status, duration_seconds, completion_receipt_ref, state_digest, segments: [], hypothesis_refs: [], source_refs: [], playback_policy: :STRAIGHT_THROUGH, continuous_play: true, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `content_digest` | function | content_digest/1 |  |  |  |  |

| `deterministic_term_digest` | function | deterministic_term_digest/1 |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `document` | function | document/0 |  |  |  |  |

| `encode` | function | encode/0 |  |  |  |  |

| `output_path` | function | output_path/0 |  |  |  |  |

| `write!` | function | write!/0 |  |  |  |  |

| `AshSurface.Fixtures.VolunteerMilestone#record` | str_key | "AshSurface.Fixtures.VolunteerMilestone#record" => _ |  |  |  |  |

| `a` | str_key | "a" => _ |  |  |  |  |

| `action` | str_key | action: struct!(Action, Keyword.merge([name: name, type: type, custom: %{}], action_opts)) |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `actions` | str_key | Map.fetch!("actions") |  |  |  |  |

| `ash` | str_key | "ash" => _ |  |  |  |  |

| `audience` | str_key | "audience" => _ |  |  |  |  |

| `b` | str_key | "b" => _ |  |  |  |  |

| `bools` | str_key | "bools" => _ |  |  |  |  |

| `bounds` | str_key | "bounds" => _ |  |  |  |  |

| `capability` | str_key | "capability" => _ |  |  |  |  |

| `consequence` | str_key | "consequence" => _ |  |  |  |  |

| `consumer` | str_key | "consumer" => _ |  |  |  |  |

| `contract` | str_key | "contract" => _ |  |  |  |  |

| `cost_physical` | str_key | "cost_physical" => _ |  |  |  |  |

| `custom` | str_key | custom: %{} |  |  |  |  |

| `dispatchState` | str_key | "dispatchState" => _ |  |  |  |  |

| `elixirDigest` | str_key | "elixirDigest" => _ |  |  |  |  |

| `elixirEventId` | str_key | "elixirEventId" => _ |  |  |  |  |

| `elixirObservationId` | str_key | "elixirObservationId" => _ |  |  |  |  |

| `elixirReceiptHash` | str_key | "elixirReceiptHash" => _ |  |  |  |  |

| `elixirStateDigest` | str_key | "elixirStateDigest" => _ |  |  |  |  |

| `empty` | str_key | "empty" => _ |  |  |  |  |

| `empty_list` | str_key | "empty_list" => _ |  |  |  |  |

| `empty_map` | str_key | "empty_map" => _ |  |  |  |  |

| `entrypoints` | str_key | entrypoints: [entrypoint(AshSurface.Fixtures.VolunteerMilestone, :read, :read)] |  |  |  |  |

| `entrypoints` | str_key | entrypoints: [ entrypoint(AshSurface.Fixtures.VolunteerMilestone, :read, :read), entrypoint(AshSurface.Fixtures.VolunteerMilestone, :record, :create) ] |  |  |  |  |

| `event` | str_key | "event" => _ |  |  |  |  |

| `eventType` | str_key | "eventType" => _ |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `facts` | str_key | "facts" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `floats` | str_key | "floats" => _ |  |  |  |  |

| `floor` | str_key | "floor" => _ |  |  |  |  |

| `gap` | str_key | "gap" => _ |  |  |  |  |

| `generator` | str_key | "generator" => _ |  |  |  |  |

| `generatorIdentity` | str_key | "generatorIdentity" => _ |  |  |  |  |

| `glyph` | str_key | "glyph" => _ |  |  |  |  |

| `glyphs` | str_key | "glyphs" => _ |  |  |  |  |

| `group` | str_key | "group" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `int32min1` | str_key | "int32min1" => _ |  |  |  |  |

| `ir` | str_key | "ir" => _ |  |  |  |  |

| `l` | str_key | "l" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `lawVersion` | str_key | "lawVersion" => _ |  |  |  |  |

| `list` | str_key | "list" => _ |  |  |  |  |

| `m` | str_key | "m" => _ |  |  |  |  |

| `manifestDigest` | str_key | "manifestDigest" => _ |  |  |  |  |

| `manifestDigest` | str_key | Map.fetch!("manifestDigest") |  |  |  |  |

| `member_id` | str_key | "member_id" => _ |  |  |  |  |

| `meta` | str_key | "meta" => _ |  |  |  |  |

| `milestone_id` | str_key | "milestone_id" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `name` | str_key | name: name |  |  |  |  |

| `negBig` | str_key | "negBig" => _ |  |  |  |  |

| `negative` | str_key | "negative" => _ |  |  |  |  |

| `nested` | str_key | "nested" => _ |  |  |  |  |

| `note` | str_key | "note" => _ |  |  |  |  |

| `nλ` | str_key | "nλ" => _ |  |  |  |  |

| `observation` | str_key | "observation" => _ |  |  |  |  |

| `observed_at` | str_key | observed_at: @fixed_time |  |  |  |  |

| `occurred_at` | str_key | occurred_at: @fixed_time |  |  |  |  |

| `ok` | str_key | "ok" => _ |  |  |  |  |

| `order` | str_key | "order" => _ |  |  |  |  |

| `payload` | str_key | payload: e1_payload |  |  |  |  |

| `payload` | str_key | payload: e2_payload |  |  |  |  |

| `payload` | str_key | payload: %{} |  |  |  |  |

| `payload` | str_key | "payload" => _ |  |  |  |  |

| `possibleRefusals` | str_key | "possibleRefusals" => _ |  |  |  |  |

| `presentation` | str_key | "presentation" => _ |  |  |  |  |

| `profile` | str_key | profile: kiosk_profile |  |  |  |  |

| `profile` | str_key | profile: profile |  |  |  |  |

| `quota` | str_key | "quota" => _ |  |  |  |  |

| `ratio` | str_key | "ratio" => _ |  |  |  |  |

| `receipt` | str_key | "receipt" => _ |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `retries` | str_key | "retries" => _ |  |  |  |  |

| `reward_spiritual` | str_key | "reward_spiritual" => _ |  |  |  |  |

| `safeCeiling` | str_key | "safeCeiling" => _ |  |  |  |  |

| `schema` | str_key | "schema" => _ |  |  |  |  |

| `score` | str_key | "score" => _ |  |  |  |  |

| `sections` | str_key | "sections" => _ |  |  |  |  |

| `seen` | str_key | "seen" => _ |  |  |  |  |

| `selectedTransport` | str_key | "selectedTransport" => _ |  |  |  |  |

| `semantic` | str_key | "semantic" => _ |  |  |  |  |

| `sequence` | str_key | "sequence" => _ |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `surface` | str_key | Map.fetch!("surface") |  |  |  |  |

| `surfaceSchemaVersion` | str_key | "surfaceSchemaVersion" => _ |  |  |  |  |

| `tables` | str_key | "tables" => _ |  |  |  |  |

| `tags` | str_key | "tags" => _ |  |  |  |  |

| `timestamp` | str_key | "timestamp" => _ |  |  |  |  |

| `type` | str_key | type: type |  |  |  |  |

| `witnesses` | str_key | "witnesses" => _ |  |  |  |  |

| `Σ🜂#capability` | str_key | "Σ🜂#capability" => _ |  |  |  |  |

| `transport` | str_key | transport: :auto |  |  |  |  |

| `AshSurface.Dsl.Projection` | struct | defstruct action, consumer, __identifier__, __spark_metadata__, transport: :auto |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `from_receipt` | function | from_receipt/2 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `eventId` | str_key | "eventId" => _ |  |  |  |  |

| `eventType` | str_key | "eventType" => _ |  |  |  |  |

| `event_id` | str_key | event_id: String.t() |  |  |  |  |

| `event_id` | str_key | event_id: event_id |  |  |  |  |

| `event_type` | str_key | event_type: String.t() |  |  |  |  |

| `event_type` | str_key | event_type: event_type |  |  |  |  |

| `evidenceRef` | str_key | "evidenceRef" => _ |  |  |  |  |

| `evidence_ref` | str_key | evidence_ref: String.t() | nil |  |  |  |  |

| `evidence_ref` | str_key | Keyword.get("evidence_ref") |  |  |  |  |

| `evidence_ref` | str_key | evidence_ref: evidence_ref |  |  |  |  |

| `occurredAt` | str_key | "occurredAt" => _ |  |  |  |  |

| `occurred_at` | str_key | occurred_at: nil |  |  |  |  |

| `occurred_at` | str_key | occurred_at: DateTime.t() |  |  |  |  |

| `occurred_at` | str_key | Keyword.get("occurred_at") |  |  |  |  |

| `occurred_at` | str_key | occurred_at: occurred_at |  |  |  |  |

| `payload` | str_key | payload: map() | nil |  |  |  |  |

| `payload` | str_key | Keyword.get("payload") |  |  |  |  |

| `payload` | str_key | payload: payload |  |  |  |  |

| `payload` | str_key | "payload" => _ |  |  |  |  |

| `receiptRef` | str_key | "receiptRef" => _ |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: String.t() | nil |  |  |  |  |

| `receipt_ref` | str_key | Keyword.get("receipt_ref") |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: receipt_ref |  |  |  |  |

| `sequence` | str_key | sequence: non_neg_integer() |  |  |  |  |

| `sequence` | str_key | sequence: sequence |  |  |  |  |

| `sequence` | str_key | "sequence" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: String.t() |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `AshSurface.Event` | struct | defstruct event_id, sequence, subject_ref, event_type, state_digest, evidence_ref, receipt_ref, payload, occurred_at: nil, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ event_id: String.t(), sequence: non_neg_integer(), subject_ref: String.t(), event_type: String.t(), state_digest: String.t(), evidence_ref: String.t() | nil, receipt_ref: String.t() | nil, payload: map() | nil, occurred_at: DateTime.t(), authority_boundary: :OBSERVE } |  |  |  |  |

| `validate_config_inclusion?` | str_key | validate_config_inclusion?: false |  |  |  |  |

| `get_port` | function | get_port/1 |  |  |  |  |

| `handle_call` | function | handle_call/3 |  |  |  |  |

| `init` | function | init/1 |  |  |  |  |

| `start_link` | function | start_link/1 |  |  |  |  |

| `stop` | function | stop/1 |  |  |  |  |

| `terminate` | function | terminate/2 |  |  |  |  |

| `acceptor_pid` | str_key | acceptor_pid: acceptor_pid |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `action` | str_key | action: :record |  |  |  |  |

| `active` | str_key | active: false |  |  |  |  |

| `body` | str_key | body: rest |  |  |  |  |

| `body` | str_key | body: new_body |  |  |  |  |

| `body` | str_key | body: body |  |  |  |  |

| `closed` | str_key | {:error, :closed} |  |  |  |  |

| `cost_physical` | str_key | "cost_physical" => _ |  |  |  |  |

| `data` | str_key | "data" => _ |  |  |  |  |

| `domain` | str_key | domain: AshSurface.Fixtures.Domain |  |  |  |  |

| `error` | str_key | "error" => _ |  |  |  |  |

| `headers` | str_key | headers: headers_part |  |  |  |  |

| `headers` | str_key | headers: headers |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `listen_socket` | str_key | listen_socket: listen_socket |  |  |  |  |

| `member_id` | str_key | "member_id" => _ |  |  |  |  |

| `milestone_id` | str_key | "milestone_id" => _ |  |  |  |  |

| `packet` | str_key | packet: :raw |  |  |  |  |

| `parts` | str_key | parts: 2 |  |  |  |  |

| `port` | str_key | port: port |  |  |  |  |

| `reuseaddr` | str_key | reuseaddr: true |  |  |  |  |

| `reward_spiritual` | str_key | "reward_spiritual" => _ |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `success` | str_key | "success" => _ |  |  |  |  |

| `AshSurface.Fixtures.VolunteerMilestone` | ash_resource |  |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: false |  |  |  |  |

| `data_layer` | str_key | data_layer: Ash.DataLayer.Ets |  |  |  |  |

| `default` | str_key | default: "completed" |  |  |  |  |

| `domain` | str_key | domain: AshSurface.Fixtures.Domain |  |  |  |  |

| `public?` | str_key | public?: true |  |  |  |  |

| `check` | function | check/0 |  |  |  |  |

| `check_surface` | function | check_surface/2 |  |  |  |  |

| `ready?` | function | ready?/0 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `algorithm` | str_key | algorithm: @digest_algorithm |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `bytes` | str_key | bytes: bytes |  |  |  |  |

| `checkedAt` | str_key | "checkedAt" => _ |  |  |  |  |

| `checked_at` | str_key | checked_at: DateTime.t() |  |  |  |  |

| `checked_at` | str_key | checked_at: DateTime.utc_now() |  |  |  |  |

| `checked_at` | str_key | checked_at: %DateTime{} = checked_at |  |  |  |  |

| `checks` | str_key | checks: [check_result()] |  |  |  |  |

| `checks` | str_key | checks: checks |  |  |  |  |

| `checks` | str_key | "checks" => _ |  |  |  |  |

| `detail` | str_key | detail: term() |  |  |  |  |

| `detail` | str_key | detail: detail |  |  |  |  |

| `detail` | str_key | "detail" => _ |  |  |  |  |

| `detail` | str_key | detail: %{required: @required_apps, missing: missing} |  |  |  |  |

| `detail` | str_key | detail: %{selected: :http} |  |  |  |  |

| `detail` | str_key | detail: %{result: inspect(other)} |  |  |  |  |

| `detail` | str_key | detail: %{loaded: loaded?, generate_1_exported: exported?} |  |  |  |  |

| `detail` | str_key | detail: %{path: path, bytes: bytes} |  |  |  |  |

| `detail` | str_key | detail: %{path: path, reason: reason} |  |  |  |  |

| `detail` | str_key | detail: %{ stored: surface.digest, recomputed: recomputed, algorithm: @digest_algorithm } |  |  |  |  |

| `generate_1_exported` | str_key | generate_1_exported: exported? |  |  |  |  |

| `loaded` | str_key | loaded: loaded? |  |  |  |  |

| `missing` | str_key | missing: missing |  |  |  |  |

| `name` | str_key | name: atom() |  |  |  |  |

| `name` | str_key | name: name |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `name` | str_key | name: :applications_started |  |  |  |  |

| `name` | str_key | name: :transport_module |  |  |  |  |

| `name` | str_key | name: :ash_manifest_module |  |  |  |  |

| `name` | str_key | name: :runtime_present |  |  |  |  |

| `name` | str_key | name: :digest_integrity |  |  |  |  |

| `path` | str_key | path: path |  |  |  |  |

| `preferred` | str_key | preferred: :http |  |  |  |  |

| `reason` | str_key | reason: term() |  |  |  |  |

| `reason` | str_key | reason: :surface_struct_required |  |  |  |  |

| `reason` | str_key | reason: {:runtime_path_must_be_binary, other} |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `recomputed` | str_key | recomputed: recomputed |  |  |  |  |

| `required` | str_key | required: @required_apps |  |  |  |  |

| `result` | str_key | result: inspect(other) |  |  |  |  |

| `runtime_path` | str_key | Keyword.get("runtime_path") |  |  |  |  |

| `runtime_path` | str_key | Keyword.fetch("runtime_path") |  |  |  |  |

| `selected` | str_key | selected: :http |  |  |  |  |

| `size` | str_key | size: bytes |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_SUBJECT |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_OPTION |  |  |  |  |

| `status` | str_key | status: :ok | :error |  |  |  |  |

| `status` | str_key | status: :ok | :degraded |  |  |  |  |

| `status` | str_key | status: surface_status() |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `status` | str_key | status: if(missing == [], do: :ok, else: :error) |  |  |  |  |

| `status` | str_key | status: :ok |  |  |  |  |

| `status` | str_key | status: :error |  |  |  |  |

| `status` | str_key | status: if(exported?, do: :ok, else: :error) |  |  |  |  |

| `status` | str_key | status: if(recomputed == surface.digest, do: :ok, else: :error) |  |  |  |  |

| `stored` | str_key | stored: surface.digest |  |  |  |  |

| `subject` | str_key | subject: String.t() |  |  |  |  |

| `subject` | str_key | subject: surface.digest |  |  |  |  |

| `subject` | str_key | subject: subject |  |  |  |  |

| `subject` | str_key | "subject" => _ |  |  |  |  |

| `check_result` | type | @type check_result :: %{ name: atom(), status: :ok | :error, detail: term() } |  |  |  |  |

| `refusal` | type | @type refusal :: %{ standing: :REFUSED_INVALID_SUBJECT | :REFUSED_INVALID_OPTION, reason: term(), authority_boundary: :OBSERVE } |  |  |  |  |

| `report` | type | @type report :: %{ status: :ok | :degraded, authority_boundary: :OBSERVE, checks: [check_result()], checked_at: DateTime.t() } |  |  |  |  |

| `surface_report` | type | @type surface_report :: %{ status: surface_status(), subject: String.t(), authority_boundary: :OBSERVE, checks: [check_result()] } |  |  |  |  |

| `surface_status` | type | @type surface_status :: :healthy | :missing_runtime | :digest_drift |  |  |  |  |

| `create` | function | create/2 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `__struct__` | str_key | __struct__: ^module |  |  |  |  |

| `areas` | str_key | areas: @areas |  |  |  |  |

| `areas` | str_key | "areas" => _ |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `bible` | str_key | Keyword.get("bible") |  |  |  |  |

| `bible` | str_key | bible: bible |  |  |  |  |

| `bible` | str_key | "bible" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `commitmentBoundaries` | str_key | "commitmentBoundaries" => _ |  |  |  |  |

| `commitmentBoundaryRefs` | str_key | "commitmentBoundaryRefs" => _ |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: [] |  |  |  |  |

| `commitment_boundaries` | str_key | Keyword.get("commitment_boundaries") |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: canonicalize(commitment_boundaries, &CommitmentBoundary.to_map/1, "boundaryId") |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: commitment_boundaries |  |  |  |  |

| `devotionalEpisodeRefs` | str_key | "devotionalEpisodeRefs" => _ |  |  |  |  |

| `devotionalEpisodes` | str_key | "devotionalEpisodes" => _ |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: [] |  |  |  |  |

| `devotional_episodes` | str_key | Keyword.get("devotional_episodes") |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: canonicalize(devotional_episodes, &DevotionalEpisode.to_map/1, "episodeId") |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: devotional_episodes |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `explanationRefs` | str_key | "explanationRefs" => _ |  |  |  |  |

| `explanations` | str_key | explanations: [] |  |  |  |  |

| `explanations` | str_key | Keyword.get("explanations") |  |  |  |  |

| `explanations` | str_key | explanations: canonicalize(explanations, &WhyThis.to_map/1, "explanationId") |  |  |  |  |

| `explanations` | str_key | explanations: explanations |  |  |  |  |

| `explanations` | str_key | "explanations" => _ |  |  |  |  |

| `grammar` | str_key | grammar: @grammar |  |  |  |  |

| `grammar` | str_key | "grammar" => _ |  |  |  |  |

| `journeyRefs` | str_key | "journeyRefs" => _ |  |  |  |  |

| `journeys` | str_key | journeys: [] |  |  |  |  |

| `journeys` | str_key | Keyword.get("journeys") |  |  |  |  |

| `journeys` | str_key | journeys: canonicalize(journeys, &Journey.to_map/1, "journeyId") |  |  |  |  |

| `journeys` | str_key | journeys: journeys |  |  |  |  |

| `journeys` | str_key | "journeys" => _ |  |  |  |  |

| `life` | str_key | Keyword.get("life") |  |  |  |  |

| `life` | str_key | life: life |  |  |  |  |

| `life` | str_key | "life" => _ |  |  |  |  |

| `manufactureTraceRefs` | str_key | "manufactureTraceRefs" => _ |  |  |  |  |

| `manufactureTraces` | str_key | "manufactureTraces" => _ |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: [] |  |  |  |  |

| `manufacture_traces` | str_key | Keyword.get("manufacture_traces") |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: canonicalize(manufacture_traces, &ManufactureTrace.to_map/1, "traceId") |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: manufacture_traces |  |  |  |  |

| `outcomeHypotheses` | str_key | "outcomeHypotheses" => _ |  |  |  |  |

| `outcomeHypothesisRefs` | str_key | "outcomeHypothesisRefs" => _ |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: [] |  |  |  |  |

| `outcome_hypotheses` | str_key | Keyword.get("outcome_hypotheses") |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: canonicalize(outcome_hypotheses, &OutcomeHypothesis.to_map/1, "hypothesisId") |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: outcome_hypotheses |  |  |  |  |

| `personalizationContextRefs` | str_key | "personalizationContextRefs" => _ |  |  |  |  |

| `personalizationContexts` | str_key | "personalizationContexts" => _ |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: [] |  |  |  |  |

| `personalization_contexts` | str_key | Keyword.get("personalization_contexts") |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: canonicalize(personalization_contexts, &PersonalizationContext.to_map/1, "contextId") |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: personalization_contexts |  |  |  |  |

| `possibilitySetRefs` | str_key | "possibilitySetRefs" => _ |  |  |  |  |

| `possibilitySets` | str_key | "possibilitySets" => _ |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: [] |  |  |  |  |

| `possibility_sets` | str_key | Keyword.get("possibility_sets") |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: canonicalize(possibility_sets, &PossibilitySet.to_map/1, "setId") |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: possibility_sets |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipt_refs) |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipt_refs |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `surfaceId` | str_key | "surfaceId" => _ |  |  |  |  |

| `surface_id` | str_key | surface_id: "hs_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `today` | str_key | Keyword.get("today") |  |  |  |  |

| `today` | str_key | today: today |  |  |  |  |

| `today` | str_key | "today" => _ |  |  |  |  |

| `you` | str_key | Keyword.get("you") |  |  |  |  |

| `you` | str_key | you: you |  |  |  |  |

| `you` | str_key | "you" => _ |  |  |  |  |

| `zoe` | str_key | Keyword.get("zoe") |  |  |  |  |

| `zoe` | str_key | zoe: zoe |  |  |  |  |

| `zoe` | str_key | "zoe" => _ |  |  |  |  |

| `AshSurface.HumanSurface` | struct | defstruct surface_id, exact_subject, state_digest, today, bible, life, zoe, you, possibility_sets: [], explanations: [], devotional_episodes: [], outcome_hypotheses: [], commitment_boundaries: [], journeys: [], personalization_contexts: [], manufacture_traces: [], evidence_refs: [], receipt_refs: [], standing: :PARTIAL_ALIVE, grammar: @grammar, areas: @areas, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `delegated` | function | delegated/2 |  |  |  |  |

| `delegated_facts` | function | delegated_facts/0 |  |  |  |  |

| `new` | function | new/1 |  |  |  |  |

| `section` | function | section/1 |  |  |  |  |

| `section` | function | section/2 |  |  |  |  |

| `sections` | function | sections/0 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action` | str_key | action: String.t() | atom() | nil |  |  |  |  |

| `action_type` | str_key | action_type: String.t() | atom() | nil |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `ash` | str_key | ash: __MODULE__.Ash.t() | nil |  |  |  |  |

| `ash` | str_key | ash: __MODULE__.Ash |  |  |  |  |

| `ash_surface` | str_key | ash_surface: section |  |  |  |  |

| `ash_surface` | str_key | "ash_surface" => _ |  |  |  |  |

| `bypass` | str_key | bypass: boolean() |  |  |  |  |

| `capability` | str_key | capability: __MODULE__.Capability.t() | nil |  |  |  |  |

| `capability` | str_key | capability: __MODULE__.Capability |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `check` | str_key | check: String.t() |  |  |  |  |

| `checks` | str_key | checks: [check()] |  |  |  |  |

| `conditions` | str_key | conditions: [condition()] |  |  |  |  |

| `custom` | str_key | custom: custom |  |  |  |  |

| `default` | str_key | default: term() |  |  |  |  |

| `digest` | str_key | digest: String.t() | nil |  |  |  |  |

| `format` | str_key | format: String.t() | nil |  |  |  |  |

| `group` | str_key | group: String.t() | nil |  |  |  |  |

| `input` | str_key | input: map() | nil |  |  |  |  |

| `inputs` | str_key | inputs: [map()] | map() | nil |  |  |  |  |

| `kind` | str_key | kind: atom() |  |  |  |  |

| `label` | str_key | label: String.t() | nil |  |  |  |  |

| `name` | str_key | name: atom() |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] | String.t() | nil |  |  |  |  |

| `opts` | str_key | opts: map() |  |  |  |  |

| `order` | str_key | order: non_neg_integer() | nil |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `outputs` | str_key | outputs: [map()] | map() | nil |  |  |  |  |

| `policies` | str_key | policies: [map()] | nil |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil |  |  |  |  |

| `presentation` | str_key | presentation: __MODULE__.Presentation.t() | nil |  |  |  |  |

| `presentation` | str_key | presentation: __MODULE__.Presentation |  |  |  |  |

| `profile` | str_key | profile: profile |  |  |  |  |

| `profile` | str_key | "profile" => _ |  |  |  |  |

| `required` | str_key | required: boolean() |  |  |  |  |

| `resource` | str_key | resource: module() | String.t() | nil |  |  |  |  |

| `returns` | str_key | returns: String.t() | nil |  |  |  |  |

| `schema` | str_key | schema: __MODULE__.Schema.t() | nil |  |  |  |  |

| `schema` | str_key | schema: __MODULE__.Schema |  |  |  |  |

| `semantic` | str_key | semantic: __MODULE__.Semantic.t() | nil |  |  |  |  |

| `semantic` | str_key | semantic: __MODULE__.Semantic |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `type` | str_key | type: String.t() |  |  |  |  |

| `version` | str_key | version: String.t() | nil |  |  |  |  |

| `widget` | str_key | widget: String.t() | atom() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() | nil |  |  |  |  |

| `AshSurface.IR` | struct | defstruct version, digest, ash, semantic, capability, presentation, schema |  |  |  |  |

| `section_name` | type | @type section_name :: :ash | :semantic | :capability | :presentation | :schema |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ version: String.t() | nil, digest: String.t() | nil, ash: __MODULE__.Ash.t() | nil, semantic: __MODULE__.Semantic.t() | nil, capability: __MODULE__.Capability.t() | nil, presentation: __MODULE__.Presentation.t() | nil, schema: __MODULE__.Schema.t() | nil } |  |  |  |  |

| `authority_required` | function | authority_required/1 |  |  |  |  |

| `authority_required` | str_key | authority_required: false |  |  |  |  |

| `authority_required` | str_key | authority_required: boolean() |  |  |  |  |

| `authority_required` | str_key | authority_required: required |  |  |  |  |

| `capability_id` | str_key | capability_id: String.t() | nil |  |  |  |  |

| `consequence_class` | str_key | consequence_class: String.t() | atom() | nil |  |  |  |  |

| `receipt_required` | str_key | receipt_required: false |  |  |  |  |

| `receipt_required` | str_key | receipt_required: boolean() |  |  |  |  |

| `AshSurface.IR.Capability` | struct | defstruct capability_id, consequence_class, authority_required: false, receipt_required: false |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ capability_id: String.t() | nil, consequence_class: String.t() | atom() | nil, authority_required: boolean(), receipt_required: boolean() } |  |  |  |  |

| `digest` | function | digest/1 |  |  |  |  |

| `from_map` | function | from_map/1 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `validate_facts` | function | validate_facts/1 |  |  |  |  |

| `ash` | str_key | "ash" => _ |  |  |  |  |

| `ash` | str_key | ash: build_section(map["ash"], IR.Ash, @ash_fields) |  |  |  |  |

| `capability` | str_key | "capability" => _ |  |  |  |  |

| `capability` | str_key | capability: build_section(map["capability"], IR.Capability, @capability_fields) |  |  |  |  |

| `digest` | str_key | digest: digest(to_map(ir)) |  |  |  |  |

| `invalid_fact` | str_key | {:error, {:invalid_fact, atom(), atom()}} |  |  |  |  |

| `invalid_fact` | str_key | {:error, {:invalid_fact, section, field}} |  |  |  |  |

| `ir_map_required` | str_key | {:error, {:ir_map_required, other}} |  |  |  |  |

| `missing_ir_sections` | str_key | {:error, {:missing_ir_sections, Enum.sort(missing)}} |  |  |  |  |

| `not_json_isomorphic` | str_key | {:error, {:not_json_isomorphic, section, value}} |  |  |  |  |

| `not_json_isomorphic` | str_key | {:error, {:not_json_isomorphic, section, k}} |  |  |  |  |

| `presentation` | str_key | "presentation" => _ |  |  |  |  |

| `presentation` | str_key | presentation: build_section(map["presentation"], IR.Presentation, @presentation_fields) |  |  |  |  |

| `schema` | str_key | "schema" => _ |  |  |  |  |

| `schema` | str_key | schema: build_section(map["schema"], IR.Schema, @schema_fields) |  |  |  |  |

| `section_must_be_map_or_nil` | str_key | {:error, {:section_must_be_map_or_nil, key, value}} |  |  |  |  |

| `semantic` | str_key | "semantic" => _ |  |  |  |  |

| `semantic` | str_key | semantic: build_section(map["semantic"], IR.Semantic, @semantic_fields) |  |  |  |  |

| `version` | str_key | "version" => _ |  |  |  |  |

| `version` | str_key | version: map["version"] |  |  |  |  |

| `version_must_be_string_or_nil` | str_key | {:error, {:version_must_be_string_or_nil, version}} |  |  |  |  |

| `from_receipt` | function | from_receipt/2 |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `consequence` | str_key | "consequence" => _ |  |  |  |  |

| `dispatchState` | str_key | "dispatchState" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `occurred_at` | str_key | occurred_at: occurred |  |  |  |  |

| `payload` | str_key | payload: fetch(receipt, [:consequence, "consequence"]) || %{} |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `reason` | str_key | reason: {:no_parseable_receipt_timestamp, raw} |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: fetch(receipt, [:receipt_hash, "receiptHash", :receipt_ref, "receiptRef"]) |  |  |  |  |

| `selectedTransport` | str_key | "selectedTransport" => _ |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_INVALID_SUBJECT |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_MISSING_TIMESTAMP |  |  |  |  |

| `standing` | str_key | standing: :REFUSED_RECEIPT_DIGEST_MISMATCH |  |  |  |  |

| `timestamp` | str_key | "timestamp" => _ |  |  |  |  |

| `ir_action` | type | @type ir_action :: %{ optional(:resource) => String.t(), optional(:action) => String.t(), optional(:semantic) => semantic(), # JSON-decoded receipts/actions arrive with string keys; every key # above is read through both spellings (see `fetch/2`). optional(String.t()) => term() } |  |  |  |  |

| `receipt` | type | @type receipt :: map() |  |  |  |  |

| `refusal` | type | @type refusal :: %{ required(:standing) => atom(), required(:reason) => term(), required(:authority_boundary) => :OBSERVE } |  |  |  |  |

| `semantic` | type | @type semantic :: %{ optional(:subject_iri) => String.t() | nil, optional(String.t()) => term() } |  |  |  |  |

| `admit` | function | admit/3 |  |  |  |  |

| `complete` | function | complete/4 |  |  |  |  |

| `derive_key` | function | derive_key/2 |  |  |  |  |

| `protocol` | function | protocol/0 |  |  |  |  |

| `request_digest` | function | request_digest/2 |  |  |  |  |

| `reserve` | function | reserve/3 |  |  |  |  |

| `valid_key?` | function | valid_key?/1 |  |  |  |  |

| `validate_key` | function | validate_key/1 |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `already_completed` | str_key | {:error, :already_completed} |  |  |  |  |

| `commandId` | str_key | "commandId" => _ |  |  |  |  |

| `digest` | str_key | digest: String.t() |  |  |  |  |

| `digest` | str_key | digest: recorded |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `digest_mismatch` | str_key | {:error, :digest_mismatch} |  |  |  |  |

| `ik_` | str_key | "ik_" => _ |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `invalid_key` | str_key | {:error, :invalid_key} |  |  |  |  |

| `invalid_utf8` | str_key | {:error, {:invalid_utf8, Enum.reverse(path)}} |  |  |  |  |

| `non_string_key` | str_key | {:error, {:non_string_key, Enum.reverse(path)}} |  |  |  |  |

| `not_a_string` | str_key | {:error, :not_a_string} |  |  |  |  |

| `not_first` | str_key | {:error, {:not_first, admission()}} |  |  |  |  |

| `not_first` | str_key | {:error, {:not_first, other}} |  |  |  |  |

| `not_portable` | str_key | {:error, {:not_portable, Enum.reverse(path)}} |  |  |  |  |

| `not_reserved` | str_key | {:error, :not_reserved} |  |  |  |  |

| `outcome` | str_key | outcome: :pending | {:done, term()} |  |  |  |  |

| `outcome` | str_key | outcome: :pending |  |  |  |  |

| `outcome` | str_key | outcome: {:done, outcome} |  |  |  |  |

| `outcome` | str_key | outcome: {:done, _} |  |  |  |  |

| `unsafe_integer` | str_key | {:error, {:unsafe_integer, Enum.reverse(path)}} |  |  |  |  |

| `admission` | type | @type admission :: :first | {:replay, term()} | {:conflict, :digest_mismatch | :in_flight} |  |  |  |  |

| `entry` | type | @type entry :: %{digest: String.t(), outcome: :pending | {:done, term()}} |  |  |  |  |

| `state` | type | @type state :: %{optional(String.t()) => entry()} |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `createdAt` | str_key | "createdAt" => _ |  |  |  |  |

| `created_at` | str_key | created_at: DateTime.t() |  |  |  |  |

| `created_at` | str_key | Keyword.get("created_at") |  |  |  |  |

| `created_at` | str_key | created_at: created_at |  |  |  |  |

| `input` | str_key | input: map() |  |  |  |  |

| `input` | str_key | input: input |  |  |  |  |

| `input` | str_key | "input" => _ |  |  |  |  |

| `intentId` | str_key | "intentId" => _ |  |  |  |  |

| `intent_id` | str_key | intent_id: String.t() |  |  |  |  |

| `intent_id` | str_key | intent_id: intent_id |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: String.t() |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `surfaceActionId` | str_key | "surfaceActionId" => _ |  |  |  |  |

| `surface_action_id` | str_key | surface_action_id: String.t() |  |  |  |  |

| `surface_action_id` | str_key | surface_action_id: surface_action_id |  |  |  |  |

| `AshSurface.Intent` | struct | defstruct surface_action_id, input, subject_ref, created_at, intent_id |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ surface_action_id: String.t(), input: map(), subject_ref: String.t(), created_at: DateTime.t(), intent_id: String.t() } |  |  |  |  |

| `to_candidate` | function | to_candidate/2 |  |  |  |  |

| `submit` | function | submit/3 |  |  |  |  |

| `REFUSED_NO_COMMAND_BUS` | str_key | {:error, :REFUSED_NO_COMMAND_BUS} |  |  |  |  |

| `REFUSED_UNKNOWN_ACTION` | str_key | {:error, :REFUSED_UNKNOWN_ACTION} |  |  |  |  |

| `action_id` | str_key | Map.get("action_id") |  |  |  |  |

| `action_id` | str_key | action_id: candidate_map.action_id |  |  |  |  |

| `admitted_action_ids` | str_key | Map.fetch("admitted_action_ids") |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, :missing_action_id}} |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, :invalid_action_id}} |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, :candidate_must_be_a_map}} |  |  |  |  |

| `invalid_context` | str_key | {:error, {:invalid_context, :admitted_action_ids_must_be_a_list_of_strings}} |  |  |  |  |

| `payload` | str_key | payload: Map.delete(candidate_map, :action_id) |  |  |  |  |

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `payload` | str_key | payload: map() |  |  |  |  |

| `AshSurface.Intent.Envelope` | struct | defstruct action_id, payload |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t(), payload: map() } |  |  |  |  |

| `create` | function | create/3 |  |  |  |  |

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `action_id` | str_key | action_id: action_id |  |  |  |  |

| `capability` | str_key | capability: section() |  |  |  |  |

| `capability` | str_key | capability: capability |  |  |  |  |

| `semantic` | str_key | semantic: section() |  |  |  |  |

| `semantic` | str_key | semantic: semantic |  |  |  |  |

| `AshSurface.Intent.IR` | struct | defstruct action_id, capability, semantic |  |  |  |  |

| `section` | type | @type section :: map() | nil |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t(), capability: section(), semantic: section() } |  |  |  |  |

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `entries` | str_key | entries: [] |  |  |  |  |

| `entries` | str_key | entries: normalized |  |  |  |  |

| `entries` | str_key | "entries" => _ |  |  |  |  |

| `entryId` | str_key | "entryId" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceRefs` | str_key | Map.get("evidenceRefs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | Map.get("evidence_refs") |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `journeyId` | str_key | "journeyId" => _ |  |  |  |  |

| `journey_id` | str_key | journey_id: "journey_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `occurredAt` | str_key | "occurredAt" => _ |  |  |  |  |

| `privacyScope` | str_key | "privacyScope" => _ |  |  |  |  |

| `privacy_scope` | str_key | privacy_scope: :SUBJECT_PRIVATE |  |  |  |  |

| `receiptRef` | str_key | Map.get("receiptRef") |  |  |  |  |

| `receiptRef` | str_key | "receiptRef" => _ |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_ref` | str_key | Map.get("receipt_ref") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipt_refs) |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipt_refs |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `standing` | str_key | Map.get("standing") |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `AshSurface.Journey` | struct | defstruct journey_id, exact_subject, state_digest, entries: [], evidence_refs: [], receipt_refs: [], privacy_scope: :SUBJECT_PRIVATE, standing: :PARTIAL_ALIVE, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `calver` | function | calver/0 |  |  |  |  |

| `compose` | function | compose/1 |  |  |  |  |

| `required_fields` | function | required_fields/0 |  |  |  |  |

| `selected_decomposition` | function | selected_decomposition/0 |  |  |  |  |

| `validate` | function | validate/1 |  |  |  |  |

| `verifier_path` | function | verifier_path/0 |  |  |  |  |

| `verify` | function | verify/2 |  |  |  |  |

| `verify_file` | function | verify_file/2 |  |  |  |  |

| `args` | str_key | args: [verifier_path(), episode_path] |  |  |  |  |

| `authority_ceiling` | str_key | "authority_ceiling" => _ |  |  |  |  |

| `calver_mismatch` | str_key | {:error, {:calver_mismatch, name, value}} |  |  |  |  |

| `compose_input_must_be_a_map` | str_key | {:error, {:compose_input_must_be_a_map, input}} |  |  |  |  |

| `consequence_id` | str_key | "consequence_id" => _ |  |  |  |  |

| `cost_score` | str_key | "cost_score" => _ |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `domain_version` | str_key | "domain_version" => _ |  |  |  |  |

| `episode_id` | str_key | "episode_id" => _ |  |  |  |  |

| `episode_must_be_a_map` | str_key | {:error, :episode_must_be_a_map} |  |  |  |  |

| `episode_must_be_a_map` | str_key | {:error, {:episode_must_be_a_map, episode}} |  |  |  |  |

| `episode_not_json_encodable` | str_key | {:error, {:episode_not_json_encodable, reason}} |  |  |  |  |

| `episode_not_json_encodable` | str_key | {:error, {:episode_not_json_encodable, error}} |  |  |  |  |

| `event_id` | str_key | "event_id" => _ |  |  |  |  |

| `fond_version` | str_key | "fond_version" => _ |  |  |  |  |

| `hddl_version` | str_key | "hddl_version" => _ |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, key, module}} |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, key, {:expected_binary, value}}} |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, :cost_score, {:expected_number, other}}} |  |  |  |  |

| `invalid_compose_input` | str_key | {:error, {:invalid_compose_input, :episode_id, {:expected_binary, other}}} |  |  |  |  |

| `invalid_standing` | str_key | {:error, {:invalid_standing, value}} |  |  |  |  |

| `invalid_standing` | str_key | {:error, {:invalid_standing, standing}} |  |  |  |  |

| `invalid_surface_digest` | str_key | {:error, {:invalid_surface_digest, digest}} |  |  |  |  |

| `invalid_verifier_timeout` | str_key | {:error, {:invalid_verifier_timeout, timeout}} |  |  |  |  |

| `marketplace_identity` | str_key | "marketplace_identity" => _ |  |  |  |  |

| `missing_compose_fields` | str_key | {:error, {:missing_compose_fields, missing}} |  |  |  |  |

| `missing_compose_fields` | str_key | {:error, {:missing_compose_fields, [key]}} |  |  |  |  |

| `missing_fields` | str_key | {:error, {:missing_fields, missing}} |  |  |  |  |

| `observed_transitions` | str_key | "observed_transitions" => _ |  |  |  |  |

| `outcome` | str_key | "outcome" => _ |  |  |  |  |

| `padding` | str_key | padding: false |  |  |  |  |

| `pattern_version` | str_key | "pattern_version" => _ |  |  |  |  |

| `planning_episode_id` | str_key | "planning_episode_id" => _ |  |  |  |  |

| `receipt_hash` | str_key | "receipt_hash" => _ |  |  |  |  |

| `resulting_standing` | str_key | "resulting_standing" => _ |  |  |  |  |

| `resulting_standing` | str_key | Map.get("resulting_standing") |  |  |  |  |

| `selected_decomposition` | str_key | "selected_decomposition" => _ |  |  |  |  |

| `state_digest` | str_key | "state_digest" => _ |  |  |  |  |

| `stderr_to_stdout` | str_key | stderr_to_stdout: true |  |  |  |  |

| `step` | str_key | "step" => _ |  |  |  |  |

| `subject_binding_violation` | str_key | {:error, {:subject_binding_violation, event.subject_ref}} |  |  |  |  |

| `subject_head` | str_key | "subject_head" => _ |  |  |  |  |

| `subject_ref` | str_key | "subject_ref" => _ |  |  |  |  |

| `subject_repo` | str_key | "subject_repo" => _ |  |  |  |  |

| `surface_digest` | str_key | "surface_digest" => _ |  |  |  |  |

| `timeout` | str_key | Keyword.get("timeout") |  |  |  |  |

| `verifier_failed` | str_key | {:error, {:verifier_failed, exit_code, output}} |  |  |  |  |

| `verifier_python_not_found` | str_key | {:error, :verifier_python_not_found} |  |  |  |  |

| `verifier_timeout` | str_key | {:error, {:verifier_timeout, timeout}} |  |  |  |  |

| `verifier_tmp_unwritable` | str_key | {:error, {:verifier_tmp_unwritable, tmp_path, reason}} |  |  |  |  |

| `verifier_unparseable` | str_key | {:error, {:verifier_unparseable, exit_code, output}} |  |  |  |  |

| `verifier_version` | str_key | "verifier_version" => _ |  |  |  |  |

| `episode` | type | @type episode :: %{optional(String.t()) => term()} |  |  |  |  |

| `verify_result` | type | @type verify_result :: {:ok, :valid} | {:error, {code :: String.t(), message :: String.t()}} | {:error, term()} |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `admittedRefs` | str_key | "admittedRefs" => _ |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: [] |  |  |  |  |

| `admitted_refs` | str_key | Keyword.get("admitted_refs") |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: admitted |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: Enum.sort(admitted) |  |  |  |  |

| `alignedRefs` | str_key | "alignedRefs" => _ |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: [] |  |  |  |  |

| `aligned_refs` | str_key | Keyword.get("aligned_refs") |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: aligned |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: Enum.sort(aligned) |  |  |  |  |

| `artifactRef` | str_key | "artifactRef" => _ |  |  |  |  |

| `artifact_ref` | str_key | artifact_ref: artifact_ref |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `boundedRefs` | str_key | "boundedRefs" => _ |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: [] |  |  |  |  |

| `bounded_refs` | str_key | Keyword.get("bounded_refs") |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: bounded |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: Enum.sort(bounded) |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `equation` | str_key | "equation" => _ |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `falsifiers` | str_key | falsifiers: [] |  |  |  |  |

| `falsifiers` | str_key | Keyword.get("falsifiers") |  |  |  |  |

| `falsifiers` | str_key | falsifiers: falsifiers |  |  |  |  |

| `falsifiers` | str_key | falsifiers: Enum.sort(falsifiers) |  |  |  |  |

| `falsifiers` | str_key | "falsifiers" => _ |  |  |  |  |

| `groundedRefs` | str_key | "groundedRefs" => _ |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: [] |  |  |  |  |

| `grounded_refs` | str_key | Keyword.get("grounded_refs") |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: grounded |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: Enum.sort(grounded) |  |  |  |  |

| `humanSummary` | str_key | "humanSummary" => _ |  |  |  |  |

| `human_summary` | str_key | human_summary: Keyword.get(opts, :human_summary) |  |  |  |  |

| `human_summary` | str_key | Keyword.get("human_summary") |  |  |  |  |

| `human_summary` | str_key | human_summary: canonical.human_summary |  |  |  |  |

| `manufacturerIdentity` | str_key | "manufacturerIdentity" => _ |  |  |  |  |

| `manufacturer_identity` | str_key | manufacturer_identity: manufacturer_identity |  |  |  |  |

| `oStarRefs` | str_key | "oStarRefs" => _ |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: [] |  |  |  |  |

| `o_star_refs` | str_key | Keyword.get("o_star_refs") |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: o_star |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: Enum.sort(o_star) |  |  |  |  |

| `observedRefs` | str_key | "observedRefs" => _ |  |  |  |  |

| `observed_refs` | str_key | observed_refs: [] |  |  |  |  |

| `observed_refs` | str_key | Keyword.get("observed_refs") |  |  |  |  |

| `observed_refs` | str_key | observed_refs: observed |  |  |  |  |

| `observed_refs` | str_key | observed_refs: Enum.sort(observed) |  |  |  |  |

| `receiptRefs` | str_key | "receiptRefs" => _ |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: [] |  |  |  |  |

| `receipt_refs` | str_key | Keyword.get("receipt_refs") |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: receipts |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: Enum.sort(receipts) |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `traceId` | str_key | "traceId" => _ |  |  |  |  |

| `trace_id` | str_key | trace_id: "mt_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `AshSurface.ManufactureTrace` | struct | defstruct trace_id, exact_subject, artifact_ref, manufacturer_identity, human_summary, state_digest, observed_refs: [], admitted_refs: [], grounded_refs: [], bounded_refs: [], aligned_refs: [], o_star_refs: [], receipt_refs: [], falsifiers: [], standing: :PARTIAL_ALIVE, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `assignedTo` | str_key | "assignedTo" => _ |  |  |  |  |

| `assigned_to` | str_key | assigned_to: String.t() | nil |  |  |  |  |

| `assigned_to` | str_key | Keyword.get("assigned_to") |  |  |  |  |

| `assigned_to` | str_key | assigned_to: assigned_to |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `capabilityId` | str_key | "capabilityId" => _ |  |  |  |  |

| `capability_id` | str_key | capability_id: String.t() |  |  |  |  |

| `capability_id` | str_key | capability_id: capability_id |  |  |  |  |

| `causeRef` | str_key | "causeRef" => _ |  |  |  |  |

| `cause_ref` | str_key | cause_ref: String.t() |  |  |  |  |

| `cause_ref` | str_key | cause_ref: cause_ref |  |  |  |  |

| `escalationPath` | str_key | "escalationPath" => _ |  |  |  |  |

| `escalation_path` | str_key | escalation_path: [] |  |  |  |  |

| `escalation_path` | str_key | escalation_path: [String.t()] |  |  |  |  |

| `escalation_path` | str_key | Keyword.get("escalation_path") |  |  |  |  |

| `escalation_path` | str_key | escalation_path: escalation_path |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [String.t()] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: String.t() |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `obligationId` | str_key | "obligationId" => _ |  |  |  |  |

| `obligation_id` | str_key | obligation_id: String.t() |  |  |  |  |

| `obligation_id` | str_key | obligation_id: "obl_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `postconditionRef` | str_key | "postconditionRef" => _ |  |  |  |  |

| `postcondition_ref` | str_key | postcondition_ref: String.t() | nil |  |  |  |  |

| `postcondition_ref` | str_key | Keyword.get("postcondition_ref") |  |  |  |  |

| `postcondition_ref` | str_key | postcondition_ref: postcondition_ref |  |  |  |  |

| `receiptRef` | str_key | "receiptRef" => _ |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: String.t() | nil |  |  |  |  |

| `receipt_ref` | str_key | Keyword.get("receipt_ref") |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: receipt_ref |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `status` | str_key | status: status() |  |  |  |  |

| `status` | str_key | Keyword.get("status") |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `AshSurface.Obligation` | struct | defstruct obligation_id, exact_subject, capability_id, cause_ref, status, state_digest, assigned_to, receipt_ref, postcondition_ref, escalation_path: [], evidence_refs: [], authority_boundary: :OBSERVE |  |  |  |  |

| `status` | type | @type status :: :open | :assigned | :acknowledged | :executing | :resolved | :blocked | :unknown |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ obligation_id: String.t(), exact_subject: String.t(), capability_id: String.t(), cause_ref: String.t(), status: status(), state_digest: String.t(), assigned_to: String.t() | nil, receipt_ref: String.t() | nil, postcondition_ref: String.t() | nil, escalation_path: [String.t()], evidence_refs: [String.t()], authority_boundary: :OBSERVE } |  |  |  |  |

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [String.t()] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: String.t() |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `facts` | str_key | facts: map() |  |  |  |  |

| `facts` | str_key | facts: facts |  |  |  |  |

| `facts` | str_key | "facts" => _ |  |  |  |  |

| `observationId` | str_key | "observationId" => _ |  |  |  |  |

| `observation_id` | str_key | observation_id: String.t() |  |  |  |  |

| `observation_id` | str_key | observation_id: observation_id |  |  |  |  |

| `observedAt` | str_key | "observedAt" => _ |  |  |  |  |

| `observed_at` | str_key | observed_at: DateTime.t() |  |  |  |  |

| `observed_at` | str_key | Keyword.get("observed_at") |  |  |  |  |

| `observed_at` | str_key | observed_at: observed_at |  |  |  |  |

| `projectionPurpose` | str_key | "projectionPurpose" => _ |  |  |  |  |

| `projection_purpose` | str_key | projection_purpose: "consumer_state_observation" |  |  |  |  |

| `projection_purpose` | str_key | projection_purpose: String.t() |  |  |  |  |

| `projection_purpose` | str_key | Keyword.get("projection_purpose") |  |  |  |  |

| `projection_purpose` | str_key | projection_purpose: purpose |  |  |  |  |

| `standing` | str_key | standing: :ALIVE |  |  |  |  |

| `standing` | str_key | standing: AshSurface.Standing.t() |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: String.t() |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `AshSurface.Observation` | struct | defstruct observation_id, exact_subject, observed_at, state_digest, facts, evidence_refs: [], standing: :ALIVE, projection_purpose: "consumer_state_observation", authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ observation_id: String.t(), exact_subject: String.t(), observed_at: DateTime.t(), state_digest: String.t(), facts: map(), evidence_refs: [String.t()], standing: AshSurface.Standing.t(), projection_purpose: String.t(), authority_boundary: :OBSERVE } |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `causalClaim` | str_key | "causalClaim" => _ |  |  |  |  |

| `causal_claim` | str_key | causal_claim: false |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceState` | str_key | "evidenceState" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_state` | str_key | evidence_state: :UNKNOWN |  |  |  |  |

| `evidence_state` | str_key | Keyword.get("evidence_state") |  |  |  |  |

| `evidence_state` | str_key | evidence_state: evidence_state |  |  |  |  |

| `falsifier` | str_key | Keyword.fetch!("falsifier") |  |  |  |  |

| `falsifier` | str_key | falsifier: falsifier |  |  |  |  |

| `falsifier` | str_key | "falsifier" => _ |  |  |  |  |

| `horizon` | str_key | horizon: Keyword.get(opts, :horizon) |  |  |  |  |

| `horizon` | str_key | Keyword.get("horizon") |  |  |  |  |

| `horizon` | str_key | horizon: canonical.horizon |  |  |  |  |

| `horizon` | str_key | "horizon" => _ |  |  |  |  |

| `hypothesisId` | str_key | "hypothesisId" => _ |  |  |  |  |

| `hypothesis_id` | str_key | hypothesis_id: "hyp_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `observationRefs` | str_key | "observationRefs" => _ |  |  |  |  |

| `observation_refs` | str_key | observation_refs: [] |  |  |  |  |

| `observation_refs` | str_key | Keyword.get("observation_refs") |  |  |  |  |

| `observation_refs` | str_key | observation_refs: Enum.sort(observation_refs) |  |  |  |  |

| `observation_refs` | str_key | observation_refs: observation_refs |  |  |  |  |

| `outcomeRef` | str_key | "outcomeRef" => _ |  |  |  |  |

| `outcome_ref` | str_key | outcome_ref: outcome_ref |  |  |  |  |

| `practiceRef` | str_key | "practiceRef" => _ |  |  |  |  |

| `practice_ref` | str_key | practice_ref: practice_ref |  |  |  |  |

| `relationship` | str_key | Keyword.get("relationship") |  |  |  |  |

| `relationship` | str_key | relationship: relationship |  |  |  |  |

| `relationship` | str_key | "relationship" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `AshSurface.OutcomeHypothesis` | struct | defstruct hypothesis_id, subject_ref, practice_ref, outcome_ref, relationship, falsifier, horizon, state_digest, evidence_state: :UNKNOWN, evidence_refs: [], observation_refs: [], causal_claim: false, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `create` | function | create/3 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `consentRef` | str_key | "consentRef" => _ |  |  |  |  |

| `consent_ref` | str_key | Keyword.get("consent_ref") |  |  |  |  |

| `consent_ref` | str_key | consent_ref: consent_ref |  |  |  |  |

| `contextId` | str_key | "contextId" => _ |  |  |  |  |

| `context_id` | str_key | context_id: "pc_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `dimension` | str_key | "dimension" => _ |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceRefs` | str_key | Map.get("evidenceRefs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | Map.get("evidence_refs") |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `facetId` | str_key | "facetId" => _ |  |  |  |  |

| `facets` | str_key | facets: [] |  |  |  |  |

| `facets` | str_key | facets: normalized |  |  |  |  |

| `facets` | str_key | "facets" => _ |  |  |  |  |

| `falsifier` | str_key | Map.get("falsifier") |  |  |  |  |

| `falsifier` | str_key | "falsifier" => _ |  |  |  |  |

| `privacyScope` | str_key | "privacyScope" => _ |  |  |  |  |

| `privacy_scope` | str_key | privacy_scope: :SUBJECT_PRIVATE |  |  |  |  |

| `shareScope` | str_key | "shareScope" => _ |  |  |  |  |

| `share_scope` | str_key | share_scope: :SUBJECT_ONLY |  |  |  |  |

| `source` | str_key | "source" => _ |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `standing` | str_key | Map.get("standing") |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `valueRef` | str_key | "valueRef" => _ |  |  |  |  |

| `AshSurface.PersonalizationContext` | struct | defstruct context_id, exact_subject, state_digest, consent_ref, facets: [], evidence_refs: [], standing: :PARTIAL_ALIVE, privacy_scope: :SUBJECT_PRIVATE, share_scope: :SUBJECT_ONLY, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `create` | function | create/2 |  |  |  |  |

| `digest` | function | digest/1 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityCeiling` | str_key | "authorityCeiling" => _ |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :SELECT |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :SELECT | :CONSTRUCT |  |  |  |  |

| `authority_ceiling` | str_key | Keyword.get("authority_ceiling") |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: ceiling |  |  |  |  |

| `candidateActions` | str_key | "candidateActions" => _ |  |  |  |  |

| `candidate_actions` | str_key | candidate_actions: [] |  |  |  |  |

| `candidate_actions` | str_key | candidate_actions: [map()] |  |  |  |  |

| `candidate_actions` | str_key | Keyword.get("candidate_actions") |  |  |  |  |

| `candidate_actions` | str_key | candidate_actions: candidates |  |  |  |  |

| `episodeId` | str_key | "episodeId" => _ |  |  |  |  |

| `episode_id` | str_key | episode_id: String.t() |  |  |  |  |

| `episode_id` | str_key | episode_id: "" |  |  |  |  |

| `episode_id` | str_key | episode_id: "ep_" <> binary_part(digest, 0, 16) |  |  |  |  |

| `plannerIdentity` | str_key | "plannerIdentity" => _ |  |  |  |  |

| `planner_identity` | str_key | planner_identity: String.t() |  |  |  |  |

| `planner_identity` | str_key | Keyword.fetch!("planner_identity") |  |  |  |  |

| `planner_identity` | str_key | planner_identity: planner |  |  |  |  |

| `policyIdentity` | str_key | "policyIdentity" => _ |  |  |  |  |

| `policyStanding` | str_key | "policyStanding" => _ |  |  |  |  |

| `policy_identity` | str_key | policy_identity: String.t() |  |  |  |  |

| `policy_identity` | str_key | Keyword.fetch!("policy_identity") |  |  |  |  |

| `policy_identity` | str_key | policy_identity: policy |  |  |  |  |

| `policy_standing` | str_key | policy_standing: :VALID_STRONG |  |  |  |  |

| `policy_standing` | str_key | policy_standing: standing() |  |  |  |  |

| `policy_standing` | str_key | Keyword.get("policy_standing") |  |  |  |  |

| `policy_standing` | str_key | policy_standing: standing |  |  |  |  |

| `taskNetworkRef` | str_key | "taskNetworkRef" => _ |  |  |  |  |

| `task_network_ref` | str_key | task_network_ref: String.t() | nil |  |  |  |  |

| `task_network_ref` | str_key | Keyword.get("task_network_ref") |  |  |  |  |

| `task_network_ref` | str_key | task_network_ref: task_network |  |  |  |  |

| `worldStateRef` | str_key | "worldStateRef" => _ |  |  |  |  |

| `world_state_ref` | str_key | world_state_ref: String.t() |  |  |  |  |

| `world_state_ref` | str_key | world_state_ref: world_state_ref |  |  |  |  |

| `AshSurface.PlanningEpisode` | struct | defstruct episode_id, world_state_ref, task_network_ref, planner_identity, policy_identity, policy_standing: :VALID_STRONG, candidate_actions: [], authority_ceiling: :SELECT |  |  |  |  |

| `standing` | type | @type standing :: :VALID_STRONG | :VALID_STRONG_CYCLIC | :REFUSED |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ episode_id: String.t(), world_state_ref: String.t(), task_network_ref: String.t() | nil, planner_identity: String.t(), policy_identity: String.t(), policy_standing: standing(), candidate_actions: [map()], authority_ceiling: :SELECT | :CONSTRUCT } |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `actionRef` | str_key | "actionRef" => _ |  |  |  |  |

| `action_ref` | str_key | Keyword.get("action_ref") |  |  |  |  |

| `action_ref` | str_key | action_ref: action_ref |  |  |  |  |

| `authorityCeiling` | str_key | "authorityCeiling" => _ |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: :SELECT |  |  |  |  |

| `authority_ceiling` | str_key | Keyword.get("authority_ceiling") |  |  |  |  |

| `authority_ceiling` | str_key | authority_ceiling: ceiling |  |  |  |  |

| `capabilityId` | str_key | "capabilityId" => _ |  |  |  |  |

| `capability_id` | str_key | capability_id: capability_id |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `consequenceSummary` | str_key | "consequenceSummary" => _ |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: Keyword.get(opts, :consequence_summary) |  |  |  |  |

| `consequence_summary` | str_key | Keyword.get("consequence_summary") |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: canonical.consequence_summary |  |  |  |  |

| `costSummary` | str_key | "costSummary" => _ |  |  |  |  |

| `cost_summary` | str_key | cost_summary: Keyword.get(opts, :cost_summary) |  |  |  |  |

| `cost_summary` | str_key | Keyword.get("cost_summary") |  |  |  |  |

| `cost_summary` | str_key | cost_summary: canonical.cost_summary |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `expiresAt` | str_key | "expiresAt" => _ |  |  |  |  |

| `expires_at` | str_key | expires_at: normalize_datetime(Keyword.get(opts, :expires_at)) |  |  |  |  |

| `expires_at` | str_key | Keyword.get("expires_at") |  |  |  |  |

| `expires_at` | str_key | expires_at: Keyword.get(opts, :expires_at) |  |  |  |  |

| `label` | str_key | label: label |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `possibilityId` | str_key | "possibilityId" => _ |  |  |  |  |

| `possibility_id` | str_key | possibility_id: "pos_" <> binary_part(identity_digest, 0, 16) |  |  |  |  |

| `requirements` | str_key | requirements: [] |  |  |  |  |

| `requirements` | str_key | Keyword.get("requirements") |  |  |  |  |

| `requirements` | str_key | requirements: Enum.sort(requirements) |  |  |  |  |

| `requirements` | str_key | requirements: requirements |  |  |  |  |

| `requirements` | str_key | "requirements" => _ |  |  |  |  |

| `reversibility` | str_key | Keyword.get("reversibility") |  |  |  |  |

| `reversibility` | str_key | reversibility: reversibility |  |  |  |  |

| `reversibility` | str_key | "reversibility" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `status` | str_key | Keyword.get("status") |  |  |  |  |

| `status` | str_key | status: status |  |  |  |  |

| `status` | str_key | "status" => _ |  |  |  |  |

| `summary` | str_key | summary: Keyword.get(opts, :summary) |  |  |  |  |

| `summary` | str_key | Keyword.get("summary") |  |  |  |  |

| `summary` | str_key | summary: canonical.summary |  |  |  |  |

| `summary` | str_key | "summary" => _ |  |  |  |  |

| `whyThisRef` | str_key | "whyThisRef" => _ |  |  |  |  |

| `why_this_ref` | str_key | Keyword.get("why_this_ref") |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: why_this_ref |  |  |  |  |

| `AshSurface.Possibility` | struct | defstruct possibility_id, exact_subject, capability_id, label, summary, action_ref, why_this_ref, status, reversibility, state_digest, cost_summary, consequence_summary, expires_at, requirements: [], evidence_refs: [], authority_ceiling: :SELECT |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `closureReason` | str_key | "closureReason" => _ |  |  |  |  |

| `closure_reason` | str_key | closure_reason: Keyword.get(opts, :closure_reason) |  |  |  |  |

| `closure_reason` | str_key | Keyword.get("closure_reason") |  |  |  |  |

| `closure_reason` | str_key | closure_reason: canonical.closure_reason |  |  |  |  |

| `constraints` | str_key | constraints: [] |  |  |  |  |

| `constraints` | str_key | Keyword.get("constraints") |  |  |  |  |

| `constraints` | str_key | constraints: constraints |  |  |  |  |

| `constraints` | str_key | constraints: Enum.sort(constraints) |  |  |  |  |

| `constraints` | str_key | "constraints" => _ |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `exactSubject` | str_key | "exactSubject" => _ |  |  |  |  |

| `exact_subject` | str_key | exact_subject: exact_subject |  |  |  |  |

| `horizon` | str_key | horizon: Keyword.get(opts, :horizon) |  |  |  |  |

| `horizon` | str_key | Keyword.get("horizon") |  |  |  |  |

| `horizon` | str_key | horizon: canonical.horizon |  |  |  |  |

| `horizon` | str_key | "horizon" => _ |  |  |  |  |

| `mode` | str_key | mode: :MAXIMAL_REVERSIBLE_FRONTIER |  |  |  |  |

| `mode` | str_key | "mode" => _ |  |  |  |  |

| `objective` | str_key | objective: objective |  |  |  |  |

| `objective` | str_key | "objective" => _ |  |  |  |  |

| `possibilities` | str_key | possibilities: [] |  |  |  |  |

| `possibilities` | str_key | possibilities: possibilities |> Enum.map(&Possibility.to_map/1) |> Enum.sort_by(& &1["possibilityId"]) |  |  |  |  |

| `possibilities` | str_key | possibilities: possibilities |  |  |  |  |

| `possibilities` | str_key | "possibilities" => _ |  |  |  |  |

| `selectionRef` | str_key | "selectionRef" => _ |  |  |  |  |

| `selection_ref` | str_key | selection_ref: Keyword.get(opts, :selection_ref) |  |  |  |  |

| `selection_ref` | str_key | Keyword.get("selection_ref") |  |  |  |  |

| `selection_ref` | str_key | selection_ref: canonical.selection_ref |  |  |  |  |

| `setId` | str_key | "setId" => _ |  |  |  |  |

| `set_id` | str_key | set_id: "ps_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `sourceEpisodeRefs` | str_key | "sourceEpisodeRefs" => _ |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: [] |  |  |  |  |

| `source_episode_refs` | str_key | Keyword.get("source_episode_refs") |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: source_episode_refs |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: Enum.sort(source_episode_refs) |  |  |  |  |

| `standing` | str_key | standing: :PARTIAL_ALIVE |  |  |  |  |

| `standing` | str_key | Keyword.get("standing") |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `standing` | str_key | "standing" => _ |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `AshSurface.PossibilitySet` | struct | defstruct set_id, exact_subject, objective, horizon, selection_ref, closure_reason, state_digest, possibilities: [], constraints: [], source_episode_refs: [], evidence_refs: [], standing: :PARTIAL_ALIVE, mode: :MAXIMAL_REVERSIBLE_FRONTIER, authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `.actions.mjs` | str_key | ".actions.mjs" => _ |  |  |  |  |

| `.events.mjs` | str_key | ".events.mjs" => _ |  |  |  |  |

| `.mjs` | str_key | ".mjs" => _ |  |  |  |  |

| `.receipts.mjs` | str_key | ".receipts.mjs" => _ |  |  |  |  |

| `.schemas.mjs` | str_key | ".schemas.mjs" => _ |  |  |  |  |

| `.tanstack.mjs` | str_key | ".tanstack.mjs" => _ |  |  |  |  |

| `action_count` | str_key | action_count: length(actions) |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `module` | str_key | "module" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `pretty` | str_key | pretty: true |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `type` | str_key | "type" => _ |  |  |  |  |

| `from_surface` | function | from_surface/1 |  |  |  |  |

| `project` | function | project/3 |  |  |  |  |

| `to_surface` | function | to_surface/1 |  |  |  |  |

| `action_ids` | str_key | action_ids: surface.action_ids |  |  |  |  |

| `action_ids` | str_key | action_ids: action_ids |  |  |  |  |

| `ash` | str_key | ash: %{ manifest: surface.manifest, contract: surface.contract, digest: surface.digest, action_ids: surface.action_ids } |  |  |  |  |

| `ash` | str_key | ash: ash |  |  |  |  |

| `contract` | str_key | contract: surface.contract |  |  |  |  |

| `contract` | str_key | contract: contract |  |  |  |  |

| `digest` | str_key | digest: surface.digest |  |  |  |  |

| `digest` | str_key | digest: digest |  |  |  |  |

| `duplicate_surface_irs` | str_key | {:error, {:duplicate_surface_irs, length(surface_irs)}} |  |  |  |  |

| `foreign_ir` | str_key | {:error, {:foreign_ir, foreign_irs}} |  |  |  |  |

| `invalid_ir` | str_key | {:error, {:invalid_ir, element}} |  |  |  |  |

| `invalid_irs` | str_key | {:error, {:invalid_irs, other}} |  |  |  |  |

| `invalid_surface_facts` | str_key | {:error, {:invalid_surface_facts, Map.keys(ash) |> Enum.sort()}} |  |  |  |  |

| `invalid_surface_facts` | str_key | {:error, {:invalid_surface_facts, []}} |  |  |  |  |

| `kind` | str_key | kind: @surface_ir_kind |  |  |  |  |

| `manifest` | str_key | manifest: surface.manifest |  |  |  |  |

| `manifest` | str_key | manifest: %Ash.Info.Manifest{} = manifest |  |  |  |  |

| `manifest` | str_key | manifest: manifest |  |  |  |  |

| `missing_surface_ir` | str_key | {:error, {:missing_surface_ir, length(rest)}} |  |  |  |  |

| `unknown_projector_kind` | str_key | {:error, {:unknown_projector_kind, projector}} |  |  |  |  |

| `unknown_projector_kind` | str_key | {:error, {:unknown_projector_kind, other}} |  |  |  |  |

| `input` | type | @type input :: ir() | AshSurface.IR.t() | [ir() | AshSurface.IR.t()] |  |  |  |  |

| `ir` | type | @type ir :: %{ required(:kind) => String.t(), required(:ash) => term(), optional(atom()) => term() } |  |  |  |  |

| `surface_facts` | type | @type surface_facts :: %{ required(:manifest) => Ash.Info.Manifest.t(), required(:contract) => map(), required(:digest) => String.t(), required(:action_ids) => [String.t()] } |  |  |  |  |

| `authority_boundary` | function | authority_boundary/1 |  |  |  |  |

| `describe` | function | describe/1 |  |  |  |  |

| `do_boundary?` | function | do_boundary?/1 |  |  |  |  |

| `entries` | function | entries/1 |  |  |  |  |

| `__struct__` | str_key | __struct__: _ |  |  |  |  |

| `action` | str_key | action: String.t() |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action_type` | str_key | action_type: String.t() | nil |  |  |  |  |

| `action_type` | str_key | action_type: ash.action_type && to_string(ash.action_type) |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: String.t() | nil |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: authority_boundary(ir) |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: boundary |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `capability_iri` | str_key | capability_iri: ir.semantic && ir.semantic.capability_iri |  |  |  |  |

| `full_resource` | str_key | full_resource: full_resource |  |  |  |  |

| `id` | str_key | id: String.t() |  |  |  |  |

| `id` | str_key | id: "#{resource}.#{action}" |  |  |  |  |

| `label` | str_key | label: String.t() | nil |  |  |  |  |

| `label` | str_key | label: presentation.label |  |  |  |  |

| `receipt_required` | str_key | receipt_required: boolean() |  |  |  |  |

| `receipt_required` | str_key | receipt_required: capability.receipt_required == true |  |  |  |  |

| `resource` | str_key | resource: String.t() |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `zod` | str_key | zod: String.t() | nil |  |  |  |  |

| `zod` | str_key | zod: schema.zod |  |  |  |  |

| `AshSurface.Projector.IREntry` | struct | defstruct id, resource, action, action_type, authority_boundary, receipt_required, capability_iri, label, zod, full_resource |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ id: String.t(), resource: String.t(), action: String.t(), action_type: String.t() | nil, authority_boundary: String.t() | nil, receipt_required: boolean(), capability_iri: String.t() | nil, label: String.t() | nil, zod: String.t() | nil } |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `voice_ir` | function | voice_ir/2 |  |  |  |  |

| `.voice.json` | str_key | ".voice.json" => _ |  |  |  |  |

| `actionId` | str_key | "actionId" => _ |  |  |  |  |

| `any value` | str_key | Map.get("any value") |  |  |  |  |

| `autoExecute` | str_key | "autoExecute" => _ |  |  |  |  |

| `boolean` | str_key | "boolean" => _ |  |  |  |  |

| `datetime` | str_key | "datetime" => _ |  |  |  |  |

| `decimal` | str_key | "decimal" => _ |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `grammar` | str_key | "grammar" => _ |  |  |  |  |

| `integer` | str_key | "integer" => _ |  |  |  |  |

| `intent_count` | str_key | intent_count: length(ir["intents"]) |  |  |  |  |

| `intents` | str_key | "intents" => _ |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `mode` | str_key | "mode" => _ |  |  |  |  |

| `module` | str_key | "module" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `pretty` | str_key | pretty: true |  |  |  |  |

| `prompt` | str_key | "prompt" => _ |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `slots` | str_key | "slots" => _ |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `surfaceDigest` | str_key | "surfaceDigest" => _ |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `utc_datetime` | str_key | "utc_datetime" => _ |  |  |  |  |

| `uuid` | str_key | "uuid" => _ |  |  |  |  |

| `contract` | function | contract/1 |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `to_json` | function | to_json/1 |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `aria-describedby` | str_key | "aria-describedby" => _ |  |  |  |  |

| `contract` | str_key | "contract" => _ |  |  |  |  |

| `emitted` | str_key | emitted: emitted |  |  |  |  |

| `group` | str_key | "group" => _ |  |  |  |  |

| `group_count` | str_key | group_count: length(contract["groups"]) |  |  |  |  |

| `groups` | str_key | "groups" => _ |  |  |  |  |

| `id` | str_key | "id" => _ |  |  |  |  |

| `inputs` | str_key | "inputs" => _ |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `live` | str_key | "live" => _ |  |  |  |  |

| `members` | str_key | "members" => _ |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, term()}} |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, other}} |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `resource` | str_key | "resource" => _ |  |  |  |  |

| `role` | str_key | "role" => _ |  |  |  |  |

| `surface_count` | str_key | surface_count: length(contract["surfaces"]) |  |  |  |  |

| `surfaces` | str_key | "surfaces" => _ |  |  |  |  |

| `tabOrder` | str_key | "tabOrder" => _ |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `version` | str_key | "version" => _ |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action_count` | str_key | action_count: length(entries) |  |  |  |  |

| `ash` | str_key | ash: %{resource: resource} |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: nil |  |  |  |  |

| `duplicate_js_member` | str_key | {:error, {:duplicate_js_member, id}} |  |  |  |  |

| `escape` | str_key | escape: :javascript_safe |  |  |  |  |

| `id` | str_key | id: "#{binding}.#{entry.action}" |  |  |  |  |

| `id` | str_key | id: id |  |  |  |  |

| `invalid_namespace_names` | str_key | {:error, {:invalid_namespace_names, names}} |  |  |  |  |

| `invalid_namespace_prefix` | str_key | {:error, {:invalid_namespace_prefix, value}} |  |  |  |  |

| `invalid_prefix` | str_key | {:error, {:invalid_prefix, prefix}} |  |  |  |  |

| `js_binding_collision` | str_key | {:error, {:js_binding_collision, name}} |  |  |  |  |

| `js_namespace_collision` | str_key | {:error, {:js_namespace_collision, short, many}} |  |  |  |  |

| `namespace_count` | str_key | namespace_count: entries |> Enum.map(& &1.resource) |> Enum.uniq() |> length() |  |  |  |  |

| `namespace_names` | str_key | Keyword.get("namespace_names") |  |  |  |  |

| `namespace_prefix` | str_key | Keyword.get("namespace_prefix") |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, other}} |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `unadmitted_field` | str_key | {:error, {:unadmitted_field, entry.id, field}} |  |  |  |  |

| `unadmitted_zod` | str_key | {:error, {:unadmitted_zod, entry.id, reason}} |  |  |  |  |

| `unsafe_js_member` | str_key | {:error, {:unsafe_js_member, id}} |  |  |  |  |

| `unsafe_js_namespace` | str_key | {:error, {:unsafe_js_namespace, v}} |  |  |  |  |

| `unsafe_js_namespace` | str_key | {:error, {:unsafe_js_namespace, bound}} |  |  |  |  |

| `zod` | str_key | zod: nil |  |  |  |  |

| `zod` | str_key | zod: zod |  |  |  |  |

| `zod` | str_key | zod: expr |  |  |  |  |

| `admit` | function | admit/1 |  |  |  |  |

| `expression` | function | expression/1 |  |  |  |  |

| `capture` | str_key | capture: :all_but_first |  |  |  |  |

| `zod_bare_z` | str_key | {:error, :zod_bare_z} |  |  |  |  |

| `zod_denied_key` | str_key | {:error, {:zod_denied_key, key}} |  |  |  |  |

| `zod_denied_member` | str_key | {:error, {:zod_denied_member, name}} |  |  |  |  |

| `zod_empty` | str_key | {:error, :zod_empty} |  |  |  |  |

| `zod_expected_member_name` | str_key | {:error, :zod_expected_member_name} |  |  |  |  |

| `zod_expected_z` | str_key | {:error, {:zod_expected_z, token}} |  |  |  |  |

| `zod_not_a_string` | str_key | {:error, {:zod_not_a_string, other}} |  |  |  |  |

| `zod_trailing_token` | str_key | {:error, {:zod_trailing_token, token}} |  |  |  |  |

| `zod_truncated` | str_key | {:error, :zod_truncated} |  |  |  |  |

| `zod_unadmitted_key` | str_key | {:error, {:zod_unadmitted_key, token}} |  |  |  |  |

| `zod_unadmitted_text` | str_key | {:error, {:zod_unadmitted_text, String.slice(text, 0, 24)}} |  |  |  |  |

| `zod_unadmitted_value` | str_key | {:error, {:zod_unadmitted_value, token}} |  |  |  |  |

| `zod_unclosed` | str_key | {:error, {:zod_unclosed, close}} |  |  |  |  |

| `zod_unexpected_token` | str_key | {:error, {:zod_unexpected_token, token}} |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `action` | str_key | "action" => _ |  |  |  |  |

| `action_count` | str_key | "action_count" => _ |  |  |  |  |

| `action_type` | str_key | "action_type" => _ |  |  |  |  |

| `actions` | str_key | "actions" => _ |  |  |  |  |

| `allow_nil?` | str_key | "allow_nil?" => _ |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: false |  |  |  |  |

| `authority_gate` | str_key | "authority_gate" => _ |  |  |  |  |

| `authority_required` | str_key | "authority_required" => _ |  |  |  |  |

| `boolean` | str_key | "boolean" => _ |  |  |  |  |

| `capability` | str_key | capability: nil |  |  |  |  |

| `capability` | str_key | capability: capability |  |  |  |  |

| `cardinality` | str_key | "cardinality" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `columns` | str_key | "columns" => _ |  |  |  |  |

| `consequence_class` | str_key | "consequence_class" => _ |  |  |  |  |

| `control` | str_key | "control" => _ |  |  |  |  |

| `date` | str_key | "date" => _ |  |  |  |  |

| `datetime` | str_key | "datetime" => _ |  |  |  |  |

| `decimal` | str_key | "decimal" => _ |  |  |  |  |

| `destination` | str_key | "destination" => _ |  |  |  |  |

| `digest` | str_key | "digest" => _ |  |  |  |  |

| `fields` | str_key | "fields" => _ |  |  |  |  |

| `float` | str_key | "float" => _ |  |  |  |  |

| `format` | str_key | "format" => _ |  |  |  |  |

| `forms` | str_key | "forms" => _ |  |  |  |  |

| `gated` | str_key | "gated" => _ |  |  |  |  |

| `group` | str_key | "group" => _ |  |  |  |  |

| `group_count` | str_key | "group_count" => _ |  |  |  |  |

| `groups` | str_key | "groups" => _ |  |  |  |  |

| `integer` | str_key | "integer" => _ |  |  |  |  |

| `intent_target` | str_key | "intent_target" => _ |  |  |  |  |

| `ir_version` | str_key | "ir_version" => _ |  |  |  |  |

| `ir_version_conflict` | str_key | {:error, {:ir_version_conflict, many}} |  |  |  |  |

| `kind` | str_key | "kind" => _ |  |  |  |  |

| `kind` | str_key | kind: kind |  |  |  |  |

| `label` | str_key | "label" => _ |  |  |  |  |

| `malformed_relationship` | str_key | {:error, {:malformed_relationship, entry}} |  |  |  |  |

| `name` | str_key | "name" => _ |  |  |  |  |

| `navigation` | str_key | "navigation" => _ |  |  |  |  |

| `not_an_ir` | str_key | {:error, {:not_an_ir, other}} |  |  |  |  |

| `not_ir_input` | str_key | {:error, {:not_ir_input, other}} |  |  |  |  |

| `order` | str_key | "order" => _ |  |  |  |  |

| `path` | str_key | "path" => _ |  |  |  |  |

| `predicates` | str_key | Map.get("predicates") |  |  |  |  |

| `presentation` | str_key | presentation: nil |  |  |  |  |

| `presentation` | str_key | presentation: presentation |  |  |  |  |

| `projector` | str_key | "projector" => _ |  |  |  |  |

| `receipt_required` | str_key | "receipt_required" => _ |  |  |  |  |

| `relationships` | str_key | "relationships" => _ |  |  |  |  |

| `relationships` | str_key | Map.get("relationships") |  |  |  |  |

| `required` | str_key | "required" => _ |  |  |  |  |

| `required` | str_key | required: required |  |  |  |  |

| `resource` | str_key | "resource" => _ |  |  |  |  |

| `resource_count` | str_key | "resource_count" => _ |  |  |  |  |

| `resources` | str_key | "resources" => _ |  |  |  |  |

| `schema` | str_key | schema: nil |  |  |  |  |

| `schema` | str_key | schema: schema |  |  |  |  |

| `semantic` | str_key | semantic: nil |  |  |  |  |

| `semantic` | str_key | semantic: semantic |  |  |  |  |

| `string` | str_key | "string" => _ |  |  |  |  |

| `surface_action_id` | str_key | "surface_action_id" => _ |  |  |  |  |

| `table` | str_key | "table" => _ |  |  |  |  |

| `text` | str_key | Map.get("text") |  |  |  |  |

| `type` | str_key | "type" => _ |  |  |  |  |

| `type` | str_key | type: %{kind: kind} |  |  |  |  |

| `type` | str_key | type: type |  |  |  |  |

| `utc_datetime` | str_key | "utc_datetime" => _ |  |  |  |  |

| `uuid` | str_key | "uuid" => _ |  |  |  |  |

| `widget` | str_key | "widget" => _ |  |  |  |  |

| `action` | str_key | action: [type: :atom, required: true, doc: "Public Ash action name this projection describes."] |  |  |  |  |

| `args` | str_key | args: [:action] |  |  |  |  |

| `consumer` | str_key | consumer: [type: :atom, required: false, doc: "Optional consumer class such as web, mobile, or internal."] |  |  |  |  |

| `default` | str_key | default: :auto |  |  |  |  |

| `describe` | str_key | describe: "Declares consumer projection intent for public Ash actions without duplicating Ash semantics." |  |  |  |  |

| `doc` | str_key | doc: "Public Ash action name this projection describes." |  |  |  |  |

| `doc` | str_key | doc: "Optional consumer class such as web, mobile, or internal." |  |  |  |  |

| `doc` | str_key | doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives." |  |  |  |  |

| `entities` | str_key | entities: [ @projection, ] |  |  |  |  |

| `identifier` | str_key | identifier: :action |  |  |  |  |

| `name` | str_key | name: :projection |  |  |  |  |

| `name` | str_key | name: :surface |  |  |  |  |

| `required` | str_key | required: true |  |  |  |  |

| `required` | str_key | required: false |  |  |  |  |

| `schema` | str_key | schema: [ action: [type: :atom, required: true, doc: "Public Ash action name this projection describes."], consumer: [type: :atom, required: false, doc: "Optional consumer class such as web, mobile, or internal."], transport: [type: {:one_of, [:auto, :http, :phoenix_channel]}, required: false, default: :auto, doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives."], ] |  |  |  |  |

| `sections` | str_key | sections: [@surface] |  |  |  |  |

| `single_extension_kinds` | str_key | single_extension_kinds: [:ash_surface] |  |  |  |  |

| `target` | str_key | target: AshSurface.Dsl.Projection |  |  |  |  |

| `transformers` | str_key | transformers: [AshSurface.Resource.Persist] |  |  |  |  |

| `transport` | str_key | transport: [type: {:one_of, [:auto, :http, :phoenix_channel]}, required: false, default: :auto, doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives."] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: {:one_of, [:auto, :http, :phoenix_channel]} |  |  |  |  |

| `verifiers` | str_key | verifiers: [AshSurface.Resource.Verify] |  |  |  |  |

| `compiled` | function | compiled/1 |  |  |  |  |

| `compiled!` | function | compiled!/1 |  |  |  |  |

| `compiled?` | function | compiled?/1 |  |  |  |  |

| `compiled_result` | function | compiled_result/1 |  |  |  |  |

| `surface` | function | surface/1 |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |

| `transform` | function | transform/1 |  |  |  |  |

| `metadata` | str_key | metadata: %{source: :ash_manifest} |  |  |  |  |

| `source` | str_key | source: :ash_manifest |  |  |  |  |

| `surface` | str_key | surface: surface_entities |  |  |  |  |

| `validate` | function | validate/1 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `code` | str_key | code: "duplicate_action_projection" |  |  |  |  |

| `code` | str_key | code: "unknown_action_projection" |  |  |  |  |

| `code` | str_key | code: code |  |  |  |  |

| `code` | str_key | code: "invalid_surface_compilation" |  |  |  |  |

| `detail` | str_key | detail: "surface projection for #{inspect(action)} is declared more than once" |  |  |  |  |

| `detail` | str_key | detail: "surface projection names #{inspect(action)}, which is not in the exact public action set " <> inspect(Enum.sort(public_actions)) |  |  |  |  |

| `detail` | str_key | detail: "surface projection for #{inspect(projection.action)} declares #{label} #{inspect(kind)}; admitted kinds are " <> inspect(admitted) |  |  |  |  |

| `detail` | str_key | detail: detail |  |  |  |  |

| `resource` | str_key | resource: resource |  |  |  |  |

| `surface` | str_key | surface: projections |  |  |  |  |

| `verify` | function | verify/1 |  |  |  |  |

| `message` | str_key | message: "ash_surface: transformer did not persist :ash_surface_compiled -- Persist must run before Verify" |  |  |  |  |

| `message` | str_key | message: Enum.map_join(refusals, "; ", &"#{&1.code}: #{&1.detail}") |  |  |  |  |

| `path` | str_key | path: [] |  |  |  |  |

| `base_standings` | function | base_standings/0 |  |  |  |  |

| `refused?` | function | refused?/1 |  |  |  |  |

| `valid?` | function | valid?/1 |  |  |  |  |

| `validate!` | function | validate!/1 |  |  |  |  |

| `base` | type | @type base :: :ALIVE | :PARTIAL_ALIVE | :BLOCKED | :BUILD_BROKEN | :UNSUPPORTED |  |  |  |  |

| `refused` | type | @type refused :: atom() |  |  |  |  |

| `t` | type | @type t :: base() | refused() |  |  |  |  |

| `events` | function | events/0 |  |  |  |  |

| `intent_dispatched` | function | intent_dispatched/2 |  |  |  |  |

| `receipt_refused` | function | receipt_refused/1 |  |  |  |  |

| `transport_selected` | function | transport_selected/1 |  |  |  |  |

| `REFUSED_NO_COMMAND_BUS` | str_key | {:error, :REFUSED_NO_COMMAND_BUS} |  |  |  |  |

| `REFUSED_UNKNOWN_ACTION` | str_key | {:error, :REFUSED_UNKNOWN_ACTION} |  |  |  |  |

| `action_id` | str_key | action_id: decision.action_id |  |  |  |  |

| `action_id` | str_key | action_id: if(is_binary(action_id), do: action_id) |  |  |  |  |

| `available` | str_key | available: decision.available |  |  |  |  |

| `available_count` | str_key | available_count: length(decision.available) |  |  |  |  |

| `count` | str_key | count: 1 |  |  |  |  |

| `declared` | str_key | declared: decision.declared |  |  |  |  |

| `dimensions` | str_key | dimensions: decision.dimensions |  |  |  |  |

| `invalid_candidate` | str_key | {:error, {:invalid_candidate, _}} |  |  |  |  |

| `invalid_context` | str_key | {:error, {:invalid_context, _}} |  |  |  |  |

| `outcome` | str_key | outcome: outcome(result) |  |  |  |  |

| `reason` | str_key | reason: decision.reason |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `reason_class` | str_key | reason_class: reason_class(reason) |  |  |  |  |

| `selected` | str_key | selected: decision.selected |  |  |  |  |

| `standing` | str_key | standing: standing |  |  |  |  |

| `build` | function | build/2 |  |  |  |  |

| `action` | str_key | action: action |  |  |  |  |

| `action_id` | str_key | action_id: context.action_id |  |  |  |  |

| `echo` | str_key | echo: context.action_id |  |  |  |  |

| `token` | str_key | token: context.discovery.token |  |  |  |  |

| `git` | function | git/2 |  |  |  |  |

| `verdict` | function | verdict/2 |  |  |  |  |

| `base` | str_key | base: claim.base |  |  |  |  |

| `base_paths` | str_key | base_paths: MapSet.size(base_paths) |  |  |  |  |

| `env` | str_key | env: [ {"GIT_CONFIG_NOSYSTEM", "1"}, {"GIT_TERMINAL_PROMPT", "0"}, {"GIT_NO_REPLACE_OBJECTS", "1"} ] |  |  |  |  |

| `head` | str_key | head: claim.head |  |  |  |  |

| `head_paths` | str_key | head_paths: MapSet.size(head_paths) |  |  |  |  |

| `head_tree` | str_key | Map.get("head_tree") |  |  |  |  |

| `head_tree` | str_key | head_tree: head_tree |  |  |  |  |

| `merge` | str_key | Map.get("merge") |  |  |  |  |

| `merge` | str_key | merge: Map.get(claim, :merge) |  |  |  |  |

| `retired` | str_key | Map.get("retired") |  |  |  |  |

| `retired` | str_key | retired: Enum.sort(retired) |  |  |  |  |

| `stderr_to_stdout` | str_key | stderr_to_stdout: true |  |  |  |  |

| `trim` | str_key | trim: true |  |  |  |  |

| `claim` | type | @type claim :: %{ required(:base) => String.t(), required(:head) => String.t(), optional(:head_tree) => String.t() | nil, optional(:merge) => String.t() | nil, optional(:retired) => [String.t()] } |  |  |  |  |

| `refusal` | type | @type refusal :: :malformed_subject | :unknown_subject | :base_not_ancestor | :vacuous_lineage | :merge_not_in_lineage | :retired_not_in_base | :head_tree_mismatch | :merge_not_found | :merge_tree_not_conserved | :retired_path_resurrected | :base_path_dropped |  |  |  |  |

| `seal` | function | seal/1 |  |  |  |  |

| `digest` | str_key | digest: AshSurface.contract_digest(surface.contract) |  |  |  |  |

| `manifest` | str_key | manifest: manifest |  |  |  |  |

| `facts_from_profile` | function | facts_from_profile/1 |  |  |  |  |

| `fallback_allowed?` | function | fallback_allowed?/1 |  |  |  |  |

| `mark_dispatched` | function | mark_dispatched/1 |  |  |  |  |

| `select` | function | select/3 |  |  |  |  |

| `action_id` | str_key | action_id: String.t() | nil |  |  |  |  |

| `action_id` | str_key | Keyword.get("action_id") |  |  |  |  |

| `action_id` | str_key | action_id: action_id |  |  |  |  |

| `available` | str_key | available: [atom()] |  |  |  |  |

| `available` | str_key | available: available |  |  |  |  |

| `available` | str_key | available: [] |  |  |  |  |

| `declared` | str_key | declared: [atom()] |  |  |  |  |

| `declared` | str_key | declared: declared |  |  |  |  |

| `dimensions` | str_key | dimensions: dimensions() |  |  |  |  |

| `dimensions` | str_key | dimensions: :undelegated |  |  |  |  |

| `dimensions` | str_key | dimensions: dimensions |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched | :dispatched |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :dispatched |  |  |  |  |

| `duplicate_transport` | str_key | {:error, {:duplicate_transport, duplicates |> Enum.map(&elem(&1, 0)) |> Enum.sort()}} |  |  |  |  |

| `facts` | str_key | Keyword.get("facts") |  |  |  |  |

| `facts_must_be_a_map` | str_key | {:error, :facts_must_be_a_map} |  |  |  |  |

| `fallback` | str_key | fallback: :pre_dispatch_only |  |  |  |  |

| `frontier` | str_key | frontier: [atom()] |  |  |  |  |

| `frontier` | str_key | frontier: [] |  |  |  |  |

| `frontier` | str_key | frontier: frontier |  |  |  |  |

| `preferred` | str_key | preferred: atom() |  |  |  |  |

| `preferred` | str_key | Keyword.get("preferred") |  |  |  |  |

| `preferred` | str_key | preferred: preferred |  |  |  |  |

| `profile_must_be_a_map` | str_key | {:error, :profile_must_be_a_map} |  |  |  |  |

| `reason` | str_key | reason: atom() |  |  |  |  |

| `reason` | str_key | reason: reason |  |  |  |  |

| `selected` | str_key | selected: atom() |  |  |  |  |

| `selected` | str_key | selected: selected |  |  |  |  |

| `transportFacts` | str_key | Map.get("transportFacts") |  |  |  |  |

| `transport_facts_must_be_a_map` | str_key | {:error, :transport_facts_must_be_a_map} |  |  |  |  |

| `transports_must_be_a_list` | str_key | {:error, :transports_must_be_a_list} |  |  |  |  |

| `unadmitted_transport` | str_key | {:error, {:unadmitted_transport, unadmitted}} |  |  |  |  |

| `unknown_dimension` | str_key | {:error, {:unknown_dimension, {transport, other}}} |  |  |  |  |

| `unknown_dimension_class` | str_key | {:error, {:unknown_dimension_class, {transport, dimension, other}}} |  |  |  |  |

| `unknown_transport` | str_key | {:error, {:unknown_transport, [other]}} |  |  |  |  |

| `unknown_transport` | str_key | {:error, {:unknown_transport, preferred}} |  |  |  |  |

| `unknown_transport` | str_key | {:error, {:unknown_transport, unknown}} |  |  |  |  |

| `unsupported_transport` | str_key | {:error, {:unsupported_transport, %{preferred: preferred, available: []}}} |  |  |  |  |

| `base_standings` | function | base_standings/0 |  |  |  |  |

| `digest?` | function | digest?/1 |  |  |  |  |

| `digest_hex_length` | function | digest_hex_length/0 |  |  |  |  |

| `digest_shape?` | function | digest_shape?/1 |  |  |  |  |

| `dimension_classes` | function | dimension_classes/0 |  |  |  |  |

| `dimension_priority` | function | dimension_priority/0 |  |  |  |  |

| `dimensions` | function | dimensions/0 |  |  |  |  |

| `dispatch_outcomes` | function | dispatch_outcomes/0 |  |  |  |  |

| `dispatch_states` | function | dispatch_states/0 |  |  |  |  |

| `idempotency_protocol` | function | idempotency_protocol/0 |  |  |  |  |

| `known_transports` | function | known_transports/0 |  |  |  |  |

| `reconcile_statuses` | function | reconcile_statuses/0 |  |  |  |  |

| `refusal_atom?` | function | refusal_atom?/1 |  |  |  |  |

| `refusal_code?` | function | refusal_code?/1 |  |  |  |  |

| `refusal_prefix` | function | refusal_prefix/0 |  |  |  |  |

| `to_map` | function | to_map/0 |  |  |  |  |

| `digestHexLength` | str_key | "digestHexLength" => _ |  |  |  |  |

| `dimensionClasses` | str_key | "dimensionClasses" => _ |  |  |  |  |

| `dimensions` | str_key | "dimensions" => _ |  |  |  |  |

| `dispatchOutcomes` | str_key | "dispatchOutcomes" => _ |  |  |  |  |

| `dispatchStates` | str_key | "dispatchStates" => _ |  |  |  |  |

| `idempotencyProtocol` | str_key | "idempotencyProtocol" => _ |  |  |  |  |

| `knownTransports` | str_key | "knownTransports" => _ |  |  |  |  |

| `reconcileStatuses` | str_key | "reconcileStatuses" => _ |  |  |  |  |

| `refusalPrefix` | str_key | "refusalPrefix" => _ |  |  |  |  |

| `standingValues` | str_key | "standingValues" => _ |  |  |  |  |

| `create` | function | create/4 |  |  |  |  |

| `to_map` | function | to_map/1 |  |  |  |  |

| `authorityBoundary` | str_key | "authorityBoundary" => _ |  |  |  |  |

| `authority_boundary` | str_key | authority_boundary: :OBSERVE |  |  |  |  |

| `basis` | str_key | basis: [] |  |  |  |  |

| `basis` | str_key | Keyword.get("basis") |  |  |  |  |

| `basis` | str_key | basis: basis |  |  |  |  |

| `basis` | str_key | basis: Enum.sort(basis) |  |  |  |  |

| `basis` | str_key | "basis" => _ |  |  |  |  |

| `case` | str_key | case: :lower |  |  |  |  |

| `caveats` | str_key | caveats: [] |  |  |  |  |

| `caveats` | str_key | Keyword.get("caveats") |  |  |  |  |

| `caveats` | str_key | caveats: caveats |  |  |  |  |

| `caveats` | str_key | caveats: Enum.sort(caveats) |  |  |  |  |

| `caveats` | str_key | "caveats" => _ |  |  |  |  |

| `claimKind` | str_key | "claimKind" => _ |  |  |  |  |

| `claim_kind` | str_key | Keyword.get("claim_kind") |  |  |  |  |

| `claim_kind` | str_key | claim_kind: claim_kind |  |  |  |  |

| `doAuthority` | str_key | "doAuthority" => _ |  |  |  |  |

| `evidenceRefs` | str_key | "evidenceRefs" => _ |  |  |  |  |

| `evidenceState` | str_key | "evidenceState" => _ |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: [] |  |  |  |  |

| `evidence_refs` | str_key | Keyword.get("evidence_refs") |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: evidence_refs |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: Enum.sort(evidence_refs) |  |  |  |  |

| `evidence_state` | str_key | Keyword.get("evidence_state") |  |  |  |  |

| `evidence_state` | str_key | evidence_state: evidence_state |  |  |  |  |

| `explanationId` | str_key | "explanationId" => _ |  |  |  |  |

| `explanation_id` | str_key | explanation_id: "why_" <> binary_part(state_digest, 0, 16) |  |  |  |  |

| `falsifier` | str_key | Keyword.get("falsifier") |  |  |  |  |

| `falsifier` | str_key | falsifier: falsifier |  |  |  |  |

| `falsifier` | str_key | "falsifier" => _ |  |  |  |  |

| `hypothesisRefs` | str_key | "hypothesisRefs" => _ |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: [] |  |  |  |  |

| `hypothesis_refs` | str_key | Keyword.get("hypothesis_refs") |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: hypothesis_refs |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: Enum.sort(hypothesis_refs) |  |  |  |  |

| `profileRefs` | str_key | "profileRefs" => _ |  |  |  |  |

| `profile_refs` | str_key | profile_refs: [] |  |  |  |  |

| `profile_refs` | str_key | Keyword.get("profile_refs") |  |  |  |  |

| `profile_refs` | str_key | profile_refs: profile_refs |  |  |  |  |

| `profile_refs` | str_key | profile_refs: Enum.sort(profile_refs) |  |  |  |  |

| `stateDigest` | str_key | "stateDigest" => _ |  |  |  |  |

| `state_digest` | str_key | state_digest: state_digest |  |  |  |  |

| `subjectRef` | str_key | "subjectRef" => _ |  |  |  |  |

| `subject_ref` | str_key | subject_ref: subject_ref |  |  |  |  |

| `summary` | str_key | summary: summary |  |  |  |  |

| `summary` | str_key | "summary" => _ |  |  |  |  |

| `title` | str_key | title: title |  |  |  |  |

| `title` | str_key | "title" => _ |  |  |  |  |

| `AshSurface.WhyThis` | struct | defstruct explanation_id, subject_ref, title, summary, claim_kind, evidence_state, falsifier, state_digest, basis: [], caveats: [], profile_refs: [], evidence_refs: [], hypothesis_refs: [], authority_boundary: :OBSERVE |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{} |  |  |  |  |

| `acceptance` | function | acceptance/0 |  |  |  |  |

| `map` | function | map/0 |  |  |  |  |

| `surface` | function | surface/0 |  |  |  |  |

| `action_ref` | str_key | action_ref: "Zoela.Devotional |  |  |  |  |

| `action_ref` | str_key | action_ref: "Zoela.Service |  |  |  |  |

| `admitted_refs` | str_key | admitted_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `aligned_refs` | str_key | aligned_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `asOf` | str_key | "asOf" => _ |  |  |  |  |

| `audio_ref` | str_key | audio_ref: "demo-audio:James.1.2-8" |  |  |  |  |

| `audio_ref` | str_key | audio_ref: "demo-audio:Romans.5.1-5" |  |  |  |  |

| `audio_ref` | str_key | audio_ref: "demo-audio:reflection:perseverance" |  |  |  |  |

| `basis` | str_key | basis: [ "demo profile selects consistency as an outcome", "devotional passage theme is perseverance" ] |  |  |  |  |

| `bible` | str_key | bible: %{ "headline" => "Bible", "devotionalEpisodeRefs" => [devotional.episode_id], "continuousPlayAvailable" => true } |  |  |  |  |

| `bounded_refs` | str_key | bounded_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `causalClaimsAdmitted` | str_key | "causalClaimsAdmitted" => _ |  |  |  |  |

| `caveats` | str_key | caveats: [ "synthetic demo profile", "candidate relevance only", "no causal effect has been admitted" ] |  |  |  |  |

| `claim_kind` | str_key | claim_kind: :HYPOTHESIS |  |  |  |  |

| `commitmentBoundaryRefs` | str_key | "commitmentBoundaryRefs" => _ |  |  |  |  |

| `commitmentStopsBeforeDo` | str_key | "commitmentStopsBeforeDo" => _ |  |  |  |  |

| `commitment_boundaries` | str_key | commitment_boundaries: [service_boundary] |  |  |  |  |

| `confirmation_state` | str_key | confirmation_state: :UNCONFIRMED |  |  |  |  |

| `consent_ref` | str_key | consent_ref: "demo-consent:subject-only" |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "Begins client playback; no external organizational mutation." |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "Opens local reading surface; no external mutation." |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "No roster or team notification occurs during exploration." |  |  |  |  |

| `consequence_summary` | str_key | consequence_summary: "No new consequence." |  |  |  |  |

| `continuousDevotional` | str_key | "continuousDevotional" => _ |  |  |  |  |

| `continuousPlayAvailable` | str_key | "continuousPlayAvailable" => _ |  |  |  |  |

| `cost_summary` | str_key | cost_summary: "About 7 minutes" |  |  |  |  |

| `cost_summary` | str_key | cost_summary: "Self-paced" |  |  |  |  |

| `devotionalEpisodeRefs` | str_key | "devotionalEpisodeRefs" => _ |  |  |  |  |

| `devotional_episodes` | str_key | devotional_episodes: [devotional] |  |  |  |  |

| `dimension` | str_key | dimension: "life:outcome" |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 180 |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 5 |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 140 |  |  |  |  |

| `duration_seconds` | str_key | duration_seconds: 120 |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: ["demo-evidence:synthetic-profile"] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: manufacture_trace.receipt_refs |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: ["demo-evidence:synthetic-only"] |  |  |  |  |

| `evidence_refs` | str_key | evidence_refs: ["demo-evidence:reflection:001"] |  |  |  |  |

| `evidence_state` | str_key | evidence_state: :UNKNOWN |  |  |  |  |

| `explanationRefs` | str_key | "explanationRefs" => _ |  |  |  |  |

| `explanations` | str_key | explanations: [why] |  |  |  |  |

| `external_effects` | str_key | external_effects: [ "team notification after authorized DO", "roster mutation after authorized DO" ] |  |  |  |  |

| `falsifier` | str_key | falsifier: "Across repeated observations, devotional completion does not precede improvement in the member-selected consistency measure." |  |  |  |  |

| `falsifier` | str_key | falsifier: "No repeated association appears between this practice and the selected outcome." |  |  |  |  |

| `falsifiers` | str_key | falsifiers: [ "The profile facet is withdrawn or no longer admitted.", "The devotional semantics no longer include the mapped perseverance concept." ] |  |  |  |  |

| `grounded_refs` | str_key | grounded_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `headline` | str_key | "headline" => _ |  |  |  |  |

| `horizon` | str_key | horizon: "7d" |  |  |  |  |

| `horizon` | str_key | horizon: "today" |  |  |  |  |

| `humanAreas` | str_key | "humanAreas" => _ |  |  |  |  |

| `human_summary` | str_key | human_summary: "The candidate was manufactured from the admitted demo goal and devotional semantics." |  |  |  |  |

| `hypothesis_refs` | str_key | hypothesis_refs: [hypothesis.hypothesis_id] |  |  |  |  |

| `journeyPrivate` | str_key | "journeyPrivate" => _ |  |  |  |  |

| `journeyRefs` | str_key | "journeyRefs" => _ |  |  |  |  |

| `journeys` | str_key | journeys: [journey] |  |  |  |  |

| `kind` | str_key | kind: :SCRIPTURE |  |  |  |  |

| `kind` | str_key | kind: :TRANSITION |  |  |  |  |

| `kind` | str_key | kind: :REFLECTION |  |  |  |  |

| `kind` | str_key | kind: :ATTENDANCE |  |  |  |  |

| `kind` | str_key | kind: :PRACTICE |  |  |  |  |

| `label` | str_key | label: "James 1:2-8" |  |  |  |  |

| `label` | str_key | label: "Continue" |  |  |  |  |

| `label` | str_key | label: "Romans 5:1-5" |  |  |  |  |

| `label` | str_key | label: "Reflection" |  |  |  |  |

| `label` | str_key | label: "Sunday service attendance — demo receipt" |  |  |  |  |

| `label` | str_key | label: "Prior devotional — demo receipt" |  |  |  |  |

| `label` | str_key | label: "Reflection saved — demo evidence" |  |  |  |  |

| `life` | str_key | life: %{ "headline" => "Life", "selectedOutcomeRefs" => ["life:outcome:consistency"], "outcomeHypothesisRefs" => [hypothesis.hypothesis_id], "personalizationContextRefs" => [personalization.context_id], "manufactureTraceRefs" => [manufacture_trace.trace_id], "causalClaimsAdmitted" => false } |  |  |  |  |

| `liveProviderReads` | str_key | "liveProviderReads" => _ |  |  |  |  |

| `manufactureReceipted` | str_key | "manufactureReceipted" => _ |  |  |  |  |

| `manufactureTraceRefs` | str_key | "manufactureTraceRefs" => _ |  |  |  |  |

| `manufacture_traces` | str_key | manufacture_traces: [manufacture_trace] |  |  |  |  |

| `o_star_refs` | str_key | o_star_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `observed_refs` | str_key | observed_refs: ["demo-o:consistency-perseverance"] |  |  |  |  |

| `occurred_at` | str_key | occurred_at: "2026-09-20T12:00:00-07:00" |  |  |  |  |

| `occurred_at` | str_key | occurred_at: "2026-09-21T08:00:00-07:00" |  |  |  |  |

| `occurred_at` | str_key | occurred_at: "2026-09-21T08:08:00-07:00" |  |  |  |  |

| `outcomeHypothesisNonCausal` | str_key | "outcomeHypothesisNonCausal" => _ |  |  |  |  |

| `outcomeHypothesisRefs` | str_key | "outcomeHypothesisRefs" => _ |  |  |  |  |

| `outcome_hypotheses` | str_key | outcome_hypotheses: [hypothesis] |  |  |  |  |

| `personalizationBounded` | str_key | "personalizationBounded" => _ |  |  |  |  |

| `personalizationContextRefs` | str_key | "personalizationContextRefs" => _ |  |  |  |  |

| `personalization_contexts` | str_key | personalization_contexts: [personalization] |  |  |  |  |

| `pluralDfcmFrontier` | str_key | "pluralDfcmFrontier" => _ |  |  |  |  |

| `possibilities` | str_key | Map.fetch!("possibilities") |  |  |  |  |

| `possibilitySetRefs` | str_key | "possibilitySetRefs" => _ |  |  |  |  |

| `possibility_sets` | str_key | possibility_sets: [frontier] |  |  |  |  |

| `privacyScope` | str_key | "privacyScope" => _ |  |  |  |  |

| `profile_refs` | str_key | profile_refs: [personalization.context_id] |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: "demo-receipt:attendance:001" |  |  |  |  |

| `receipt_ref` | str_key | receipt_ref: "demo-receipt:devotional:001" |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: ["demo-receipt:manufacture:001"] |  |  |  |  |

| `receipt_refs` | str_key | receipt_refs: ["demo-receipt:attendance:001", "demo-receipt:devotional:001"] |  |  |  |  |

| `ref` | str_key | ref: "bible:James.1.2-8" |  |  |  |  |

| `ref` | str_key | ref: "transition:james-romans" |  |  |  |  |

| `ref` | str_key | ref: "bible:Romans.5.1-5" |  |  |  |  |

| `ref` | str_key | ref: "reflection:perseverance" |  |  |  |  |

| `relationship` | str_key | relationship: :MAY_SUPPORT |  |  |  |  |

| `requirements` | str_key | requirements: ["audio-capable client"] |  |  |  |  |

| `reversibility` | str_key | reversibility: :REVERSIBLE |  |  |  |  |

| `reversibility` | str_key | reversibility: :CONDITIONAL |  |  |  |  |

| `selectedOutcomeRefs` | str_key | "selectedOutcomeRefs" => _ |  |  |  |  |

| `source` | str_key | source: :USER_STATED |  |  |  |  |

| `source_episode_refs` | str_key | source_episode_refs: ["demo-planner:episode:2026-09-23"] |  |  |  |  |

| `source_refs` | str_key | source_refs: ["demo-source:bible-content"] |  |  |  |  |

| `standing` | str_key | standing: :ALIVE |  |  |  |  |

| `subject_ref` | str_key | subject_ref: "zoe:service:demo-sunday" |  |  |  |  |

| `subject_ref` | str_key | subject_ref: "practice:devotional:demo-prior" |  |  |  |  |

| `subject_ref` | str_key | subject_ref: "reflection:demo-prior" |  |  |  |  |

| `subtitle` | str_key | subtitle: "7 minutes · straight through" |  |  |  |  |

| `summary` | str_key | summary: "Play all readings and reflection in one uninterrupted episode." |  |  |  |  |

| `summary` | str_key | summary: "Open the same episode as an ordered reading sequence." |  |  |  |  |

| `summary` | str_key | summary: "See currently admitted service possibilities without joining a roster." |  |  |  |  |

| `summary` | str_key | summary: "Preserve the option to make no new commitment today." |  |  |  |  |

| `syntheticOnly` | str_key | "syntheticOnly" => _ |  |  |  |  |

| `today` | str_key | today: %{ "headline" => "Today", "asOf" => @demo_time, "possibilitySetRefs" => [frontier.set_id], "explanationRefs" => [why.explanation_id], "devotionalEpisodeRefs" => [devotional.episode_id] } |  |  |  |  |

| `value_ref` | str_key | value_ref: "life:outcome:consistency" |  |  |  |  |

| `whyThisPresent` | str_key | "whyThisPresent" => _ |  |  |  |  |

| `why_this_ref` | str_key | why_this_ref: why.explanation_id |  |  |  |  |

| `you` | str_key | you: %{ "headline" => "You", "journeyRefs" => [journey.journey_id], "privacyScope" => "SUBJECT_PRIVATE" } |  |  |  |  |

| `zoe` | str_key | zoe: %{ "headline" => "ZOE", "possibilitySetRefs" => [frontier.set_id], "commitmentBoundaryRefs" => [service_boundary.boundary_id], "liveProviderReads" => false } |  |  |  |  |

| `runtime_path` | function | runtime_path/0 |  |  |  |  |

| `runtime_source` | function | runtime_source/0 |  |  |  |  |

| `validate_config_inclusion?` | str_key | validate_config_inclusion?: false |  |  |  |  |

| `AshSurfaceZoe.Fixtures.VolunteerMilestone` | ash_resource |  |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: false |  |  |  |  |

| `data_layer` | str_key | data_layer: Ash.DataLayer.Ets |  |  |  |  |

| `default` | str_key | default: "completed" |  |  |  |  |

| `domain` | str_key | domain: AshSurfaceZoe.Fixtures.Domain |  |  |  |  |

| `public?` | str_key | public?: true |  |  |  |  |

| `project_ir` | function | project_ir/2 |  |  |  |  |

| `.demo.mjs` | str_key | ".demo.mjs" => _ |  |  |  |  |

| `.human.mjs` | str_key | ".human.mjs" => _ |  |  |  |  |

| `human_surface` | str_key | human_surface: true |  |  |  |  |

| `prefix` | str_key | Keyword.get("prefix") |  |  |  |  |

| `prefix` | str_key | prefix: prefix |  |  |  |  |

| `target_dir` | str_key | Keyword.get("target_dir") |  |  |  |  |

| `aria` | str_key | aria: map() |  |  |  |  |

| `input` | str_key | input: %{optional(String.t()) => map()} |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() |  |  |  |  |

| `Boundary` | struct | defstruct input, output, zod, aria |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ input: %{optional(String.t()) => map()}, output: map() | nil, zod: String.t(), aria: map() } |  |  |  |  |

| `args` | str_key | args: [:name] |  |  |  |  |

| `describe` | str_key | describe: "Specimen extension A section" |  |  |  |  |

| `doc` | str_key | doc: "Singleton entity name (positional arg and identifier)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen weight" |  |  |  |  |

| `doc` | str_key | doc: "Specimen A label" |  |  |  |  |

| `entities` | str_key | entities: [ @entity ] |  |  |  |  |

| `identifier` | str_key | identifier: :name |  |  |  |  |

| `label` | str_key | label: [type: :string, doc: "Specimen A label"] |  |  |  |  |

| `name` | str_key | name: :entity |  |  |  |  |

| `name` | str_key | name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"] |  |  |  |  |

| `name` | str_key | name: :alpha |  |  |  |  |

| `schema` | str_key | schema: [ name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"], weight: [type: :integer, doc: "Specimen weight"] ] |  |  |  |  |

| `schema` | str_key | schema: [ label: [type: :string, doc: "Specimen A label"] ] |  |  |  |  |

| `sections` | str_key | sections: [@alpha] |  |  |  |  |

| `singleton_entity_keys` | str_key | singleton_entity_keys: [:entity] |  |  |  |  |

| `target` | str_key | target: CompositionSpecimens.Alpha.Entity |  |  |  |  |

| `transformers` | str_key | transformers: [CompositionSpecimens.Alpha.Persist] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: :integer |  |  |  |  |

| `type` | str_key | type: :string |  |  |  |  |

| `verifiers` | str_key | verifiers: [] |  |  |  |  |

| `weight` | str_key | weight: [type: :integer, doc: "Specimen weight"] |  |  |  |  |

| `__spark_metadata__` | str_key | __spark_metadata__: nil |  |  |  |  |

| `CompositionSpecimens.Alpha.Entity` | struct | defstruct name, weight, __identifier__, __spark_metadata__: nil |  |  |  |  |

| `alpha` | function | alpha/1 |  |  |  |  |

| `compiled` | function | compiled/1 |  |  |  |  |

| `compiled?` | function | compiled?/1 |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |

| `transform` | function | transform/1 |  |  |  |  |

| `alpha` | str_key | alpha: alpha_entities |  |  |  |  |

| `alpha_label` | str_key | alpha_label: Spark.Dsl.Transformer.get_option(dsl_state, [:alpha], :label) |  |  |  |  |

| `args` | str_key | args: [:name] |  |  |  |  |

| `describe` | str_key | describe: "Specimen extension A' (clash mutant) section" |  |  |  |  |

| `doc` | str_key | doc: "Singleton entity name (positional arg and identifier)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen weight (clash mutant)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen A' label" |  |  |  |  |

| `entities` | str_key | entities: [ @entity ] |  |  |  |  |

| `identifier` | str_key | identifier: :name |  |  |  |  |

| `label` | str_key | label: [type: :string, doc: "Specimen A' label"] |  |  |  |  |

| `name` | str_key | name: :entity |  |  |  |  |

| `name` | str_key | name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"] |  |  |  |  |

| `name` | str_key | name: :alpha |  |  |  |  |

| `schema` | str_key | schema: [ name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"], weight: [type: :integer, doc: "Specimen weight (clash mutant)"] ] |  |  |  |  |

| `schema` | str_key | schema: [ label: [type: :string, doc: "Specimen A' label"] ] |  |  |  |  |

| `sections` | str_key | sections: [@alpha] |  |  |  |  |

| `singleton_entity_keys` | str_key | singleton_entity_keys: [:entity] |  |  |  |  |

| `target` | str_key | target: CompositionSpecimens.AlphaClash.Entity |  |  |  |  |

| `transformers` | str_key | transformers: [CompositionSpecimens.AlphaClash.Persist] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: :integer |  |  |  |  |

| `type` | str_key | type: :string |  |  |  |  |

| `verifiers` | str_key | verifiers: [] |  |  |  |  |

| `weight` | str_key | weight: [type: :integer, doc: "Specimen weight (clash mutant)"] |  |  |  |  |

| `__spark_metadata__` | str_key | __spark_metadata__: nil |  |  |  |  |

| `CompositionSpecimens.AlphaClash.Entity` | struct | defstruct name, weight, __identifier__, __spark_metadata__: nil |  |  |  |  |

| `transform` | function | transform/1 |  |  |  |  |

| `alpha` | str_key | alpha: alpha_entities |  |  |  |  |

| `alpha_label` | str_key | alpha_label: Spark.Dsl.Transformer.get_option(dsl_state, [:alpha], :label) |  |  |  |  |

| `args` | str_key | args: [:name] |  |  |  |  |

| `count` | str_key | count: [type: :integer, doc: "Specimen count"] |  |  |  |  |

| `describe` | str_key | describe: "Specimen extension B section" |  |  |  |  |

| `doc` | str_key | doc: "Singleton entity name (positional arg and identifier)" |  |  |  |  |

| `doc` | str_key | doc: "Specimen count" |  |  |  |  |

| `doc` | str_key | doc: "Specimen B label" |  |  |  |  |

| `entities` | str_key | entities: [ @entity ] |  |  |  |  |

| `identifier` | str_key | identifier: :name |  |  |  |  |

| `label` | str_key | label: [type: :string, doc: "Specimen B label"] |  |  |  |  |

| `name` | str_key | name: :entity |  |  |  |  |

| `name` | str_key | name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"] |  |  |  |  |

| `name` | str_key | name: :beta |  |  |  |  |

| `schema` | str_key | schema: [ name: [type: :atom, doc: "Singleton entity name (positional arg and identifier)"], count: [type: :integer, doc: "Specimen count"] ] |  |  |  |  |

| `schema` | str_key | schema: [ label: [type: :string, doc: "Specimen B label"] ] |  |  |  |  |

| `sections` | str_key | sections: [@beta] |  |  |  |  |

| `singleton_entity_keys` | str_key | singleton_entity_keys: [:entity] |  |  |  |  |

| `target` | str_key | target: CompositionSpecimens.Beta.Entity |  |  |  |  |

| `transformers` | str_key | transformers: [CompositionSpecimens.Beta.Persist] |  |  |  |  |

| `type` | str_key | type: :atom |  |  |  |  |

| `type` | str_key | type: :integer |  |  |  |  |

| `type` | str_key | type: :string |  |  |  |  |

| `verifiers` | str_key | verifiers: [] |  |  |  |  |

| `__spark_metadata__` | str_key | __spark_metadata__: nil |  |  |  |  |

| `CompositionSpecimens.Beta.Entity` | struct | defstruct name, count, __identifier__, __spark_metadata__: nil |  |  |  |  |

| `beta` | function | beta/1 |  |  |  |  |

| `compiled` | function | compiled/1 |  |  |  |  |

| `compiled?` | function | compiled?/1 |  |  |  |  |

| `not_compiled` | str_key | {:error, :not_compiled} |  |  |  |  |

| `transform` | function | transform/1 |  |  |  |  |

| `beta` | str_key | beta: beta_entities |  |  |  |  |

| `beta_label` | str_key | beta_label: Spark.Dsl.Transformer.get_option(dsl_state, [:beta], :label) |  |  |  |  |

| `record` | function | record/1 |  |  |  |  |

| `recorded` | function | recorded/0 |  |  |  |  |

| `reset` | function | reset/0 |  |  |  |  |

| `table` | function | table/0 |  |  |  |  |

| `read_concurrency` | str_key | read_concurrency: true |  |  |  |  |

| `after?` | function | after?/1 |  |  |  |  |

| `transform` | function | transform/1 |  |  |  |  |

| `mode` | str_key | mode: hidden |  |  |  |  |

| `name` | str_key | name: &1.name |  |  |  |  |

| `steps` | str_key | steps: steps |  |  |  |  |

| `via` | str_key | via: &1.via |  |  |  |  |

| `action_id` | str_key | action_id: String.t() | nil |  |  |  |  |

| `available` | str_key | available: [atom()] |  |  |  |  |

| `declared` | str_key | declared: [atom()] |  |  |  |  |

| `dimensions` | str_key | dimensions: dimensions() |  |  |  |  |

| `dimensions` | str_key | dimensions: :undelegated |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched | :dispatched |  |  |  |  |

| `dispatch_state` | str_key | dispatch_state: :not_dispatched |  |  |  |  |

| `fallback` | str_key | fallback: :pre_dispatch_only |  |  |  |  |

| `frontier` | str_key | frontier: [atom()] |  |  |  |  |

| `frontier` | str_key | frontier: [] |  |  |  |  |

| `preferred` | str_key | preferred: atom() |  |  |  |  |

| `reason` | str_key | reason: atom() |  |  |  |  |

| `selected` | str_key | selected: atom() |  |  |  |  |

| `Decision` | struct | defstruct action_id, declared, available, selected, preferred, reason, dispatch_state: :not_dispatched, fallback: :pre_dispatch_only, dimensions: :undelegated, frontier: [] |  |  |  |  |

| `dimensions` | type | @type dimensions :: :undelegated | :declared |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t() | nil, declared: [atom()], available: [atom()], selected: atom(), preferred: atom(), reason: atom(), dispatch_state: :not_dispatched | :dispatched, fallback: :pre_dispatch_only, dimensions: dimensions(), frontier: [atom()] } |  |  |  |  |

| `allow_nil?` | str_key | allow_nil?: boolean() |  |  |  |  |

| `description` | str_key | description: String.t() | nil |  |  |  |  |

| `name` | str_key | name: atom() | String.t() |  |  |  |  |

| `type` | str_key | type: Ash.Info.Manifest.Type.t() | atom() | nil |  |  |  |  |

| `Input` | struct | defstruct name, type, allow_nil?, description |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ name: atom() | String.t(), type: Ash.Info.Manifest.Type.t() | atom() | nil, allow_nil?: boolean(), description: String.t() | nil } |  |  |  |  |

| `default` | str_key | default: term() |  |  |  |  |

| `name` | str_key | name: atom() |  |  |  |  |

| `required` | str_key | required: boolean() |  |  |  |  |

| `type` | str_key | type: String.t() |  |  |  |  |

| `Input` | struct | defstruct name, type, required, default |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ name: atom(), type: String.t(), required: boolean(), default: term() } |  |  |  |  |

| `igniter` | function | igniter/1 |  |  |  |  |

| `info` | function | info/2 |  |  |  |  |

| `example` | str_key | example: "mix ash_surface.install --target MyApp.SomeResource" |  |  |  |  |

| `group` | str_key | group: :ash_surface |  |  |  |  |

| `placement` | str_key | placement: :after |  |  |  |  |

| `positional` | str_key | positional: [] |  |  |  |  |

| `required` | str_key | required: [] |  |  |  |  |

| `schema` | str_key | schema: [target: :string] |  |  |  |  |

| `target` | str_key | target: :string |  |  |  |  |

| `returns` | str_key | returns: String.t() | nil |  |  |  |  |

| `Output` | struct | defstruct returns |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{returns: String.t() | nil} |  |  |  |  |

| `bypass` | str_key | bypass: boolean() |  |  |  |  |

| `check` | str_key | check: String.t() |  |  |  |  |

| `checks` | str_key | checks: [check()] |  |  |  |  |

| `conditions` | str_key | conditions: [condition()] |  |  |  |  |

| `kind` | str_key | kind: atom() |  |  |  |  |

| `opts` | str_key | opts: map() |  |  |  |  |

| `Policy` | struct | defstruct bypass, conditions, checks |  |  |  |  |

| `check` | type | @type check :: %{check: String.t(), kind: atom()} |  |  |  |  |

| `condition` | type | @type condition :: %{check: String.t(), opts: map()} |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ bypass: boolean(), conditions: [condition()], checks: [check()] } |  |  |  |  |

| `format` | str_key | format: String.t() | nil |  |  |  |  |

| `group` | str_key | group: String.t() | nil |  |  |  |  |

| `label` | str_key | label: String.t() | nil |  |  |  |  |

| `order` | str_key | order: non_neg_integer() | nil |  |  |  |  |

| `widget` | str_key | widget: String.t() | atom() | nil |  |  |  |  |

| `Presentation` | struct | defstruct label, group, order, widget, format |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ label: String.t() | nil, group: String.t() | nil, order: non_neg_integer() | nil, widget: String.t() | atom() | nil, format: String.t() | nil } |  |  |  |  |

| `action_id` | str_key | action_id: String.t() |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `inputs` | str_key | inputs: [Input.t()] |  |  |  |  |

| `presentation` | str_key | presentation: map() | nil |  |  |  |  |

| `Schema` | struct | defstruct action_id, inputs, presentation, aria |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ action_id: String.t(), inputs: [Input.t()], presentation: map() | nil, aria: map() | nil } |  |  |  |  |

| `aria` | str_key | aria: map() | nil |  |  |  |  |

| `input` | str_key | input: map() | nil |  |  |  |  |

| `output` | str_key | output: map() | nil |  |  |  |  |

| `zod` | str_key | zod: String.t() | nil |  |  |  |  |

| `Schema` | struct | defstruct input, output, zod, aria |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ input: map() | nil, output: map() | nil, zod: String.t() | nil, aria: map() | nil } |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `Semantic` | struct | defstruct subject_iri, capability_iri, predicates, shape_id, ontology |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ subject_iri: String.t() | nil, capability_iri: String.t() | nil, predicates: [String.t()], shape_id: String.t() | nil, ontology: [String.t()] } |  |  |  |  |

| `capability_iri` | str_key | capability_iri: String.t() | nil |  |  |  |  |

| `ontology` | str_key | ontology: [String.t()] | String.t() | nil |  |  |  |  |

| `predicates` | str_key | predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil |  |  |  |  |

| `shape_id` | str_key | shape_id: String.t() | nil |  |  |  |  |

| `subject_iri` | str_key | subject_iri: String.t() | nil |  |  |  |  |

| `Semantic` | struct | defstruct subject_iri, capability_iri, predicates, shape_id, ontology |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ subject_iri: String.t() | nil, capability_iri: String.t() | nil, predicates: [String.t()] | %{optional(String.t() | atom()) => term()} | nil, shape_id: String.t() | nil, ontology: [String.t()] | String.t() | nil } |  |  |  |  |

| `SparkClosureConsumer.Example.Post` | ash_resource |  |  |  |  |  |

| `data_layer` | str_key | data_layer: Ash.DataLayer.Ets |  |  |  |  |

| `domain` | str_key | domain: SparkClosureConsumer.Example |  |  |  |  |

| `action_ids` | str_key | action_ids: [String.t()] |  |  |  |  |

| `contract` | str_key | contract: map() |  |  |  |  |

| `digest` | str_key | digest: String.t() |  |  |  |  |

| `manifest` | str_key | manifest: Ash.Info.Manifest.t() |  |  |  |  |

| `Surface` | struct | defstruct manifest, contract, digest, action_ids |  |  |  |  |

| `t` | type | @type t :: %__MODULE__{ manifest: Ash.Info.Manifest.t(), contract: map(), digest: String.t(), action_ids: [String.t()] } |  |  |  |  |

| `check` | script | node --check priv/static/ash_surface_runtime.mjs && node --check priv/static/ash_surface_playwright.mjs |  |  |  |  |

| `test` | script | node --test test/js/*.test.mjs |  |  |  |  |

| `test:coverage` | script | node --experimental-test-coverage --test test/js/*.test.mjs |  |  |  |  |

| `check` | script | node --check priv/static/ash_surface_zoe.mjs |  |  |  |  |

| `pretest` | script | node scripts/link_core_runtime.mjs |  |  |  |  |

| `test` | script | node --test test/js/*.test.mjs |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
