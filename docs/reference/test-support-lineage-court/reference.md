#  reference

<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-BEGIN: reference body is RIGID                -->
<!-- Every row below is rendered from queries/ast_extract.rq.      -->
<!-- Agents MUST NOT add, edit, reorder, or remove any row or      -->
<!-- table cell. Prose outside the fenced slot below is refused    -->
<!-- by the doc_quality court.                                     -->
<!-- ============================================================= -->

## Modules


### AshSurface.TestSupport.LineageCourt

| `git` | function | git/2 |  |  |  |  |

| `verdict` | function | verdict/2 |  |  |  |  |

| `claim` | type | @type claim :: %{ required(:base) => String.t(), required(:head) => String.t(), optional(:head_tree) => String.t() | nil, optional(:merge) => String.t() | nil, optional(:retired) => [String.t()] } |  |  |  |  |

| `refusal` | type | @type refusal :: :malformed_subject | :unknown_subject | :base_not_ancestor | :vacuous_lineage | :merge_not_in_lineage | :retired_not_in_base | :head_tree_mismatch | :merge_not_found | :merge_tree_not_conserved | :retired_path_resurrected | :base_path_dropped |  |  |  |  |



<!-- AGENT-FORBIDDEN-END -->

## Signature/type/default/errors table

<!-- RIGID table: header order is fixed; rows come only from the query. -->

| Item | Type | Signature | Params | Defaults | Errors | Invariants |
|------|------|-----------|--------|----------|--------|------------|

| `git` | function | git/2 |  |  |  |  |

| `verdict` | function | verdict/2 |  |  |  |  |

| `claim` | type | @type claim :: %{ required(:base) => String.t(), required(:head) => String.t(), optional(:head_tree) => String.t() | nil, optional(:merge) => String.t() | nil, optional(:retired) => [String.t()] } |  |  |  |  |

| `refusal` | type | @type refusal :: :malformed_subject | :unknown_subject | :base_not_ancestor | :vacuous_lineage | :merge_not_in_lineage | :retired_not_in_base | :head_tree_mismatch | :merge_not_found | :merge_tree_not_conserved | :retired_path_resurrected | :base_path_dropped |  |  |  |  |


<!-- ============================================================= -->
<!-- AGENT-FORBIDDEN-END: nothing below this line may describe     -->
<!-- code behavior.                                                -->
<!-- ============================================================= -->
