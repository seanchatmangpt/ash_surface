defmodule AshSurface.Section do
  @moduledoc """
  Behaviour for truth sections: named projections of IR nodes that carry only
  witnessed facts.

  A section is the unit a consumer surface composes. Implementations must
  surface only facts witnessed on the IR node. Presentation (labels,
  placeholders, widgets, ordering) and semantic guesses (inferred formats,
  examples, domain meaning the resource never declared) are fabrications: a
  section that carries them is not a truth section.
  """

  @doc """
  Renders the truth section for one compiled IR node.

  Returns `{:ok, section}` where `section` is a plain map whose `"section"`
  (or `:section`) fact names the projection, plus only admitted facts for that
  section kind, or `{:error, reason}` when the node cannot be witnessed.
  """
  @callback section(node :: struct(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
end
