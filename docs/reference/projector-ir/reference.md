#  reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### AshSurface.Projector.IR

| `from_surface` | function | from_surface/1 |  |  |  |  |

| `project` | function | project/3 |  |  |  |  |

| `to_surface` | function | to_surface/1 |  |  |  |  |

| `input` | type | @type input :: ir() | AshSurface.IR.t() | [ir() | AshSurface.IR.t()] |  |  |  |  |

| `ir` | type | @type ir :: %{ required(:kind) => String.t(), required(:ash) => term(), optional(atom()) => term() } |  |  |  |  |

| `surface_facts` | type | @type surface_facts :: %{ required(:manifest) => Ash.Info.Manifest.t(), required(:contract) => map(), required(:digest) => String.t(), required(:action_ids) => [String.t()] } |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `from_surface` | function | from_surface/1 |  |  |  |  |

| `project` | function | project/3 |  |  |  |  |

| `to_surface` | function | to_surface/1 |  |  |  |  |

| `input` | type | @type input :: ir() | AshSurface.IR.t() | [ir() | AshSurface.IR.t()] |  |  |  |  |

| `ir` | type | @type ir :: %{ required(:kind) => String.t(), required(:ash) => term(), optional(atom()) => term() } |  |  |  |  |

| `surface_facts` | type | @type surface_facts :: %{ required(:manifest) => Ash.Info.Manifest.t(), required(:contract) => map(), required(:digest) => String.t(), required(:action_ids) => [String.t()] } |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
