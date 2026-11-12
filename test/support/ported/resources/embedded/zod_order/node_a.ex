# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.ZodOrder.NodeA do
  @moduledoc "Root node. Depends on NodeB and NodeC (diamond top)."
  use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

  surface do
    type_name("ZodOrderNodeA")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:left, AshSurface.Ported.ZodOrder.NodeB, public?: true, allow_nil?: true)
    attribute(:right, AshSurface.Ported.ZodOrder.NodeC, public?: true, allow_nil?: true)
  end
end
