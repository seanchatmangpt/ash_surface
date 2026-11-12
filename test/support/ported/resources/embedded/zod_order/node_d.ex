# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.ZodOrder.NodeD do
  @moduledoc "Depends on NodeE (direct + array). Used by NodeB and NodeC (diamond)."
  use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

  surface do
    type_name("ZodOrderNodeD")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:label, :string, public?: true, allow_nil?: false)
    attribute(:detail, AshSurface.Ported.ZodOrder.NodeE, public?: true, allow_nil?: true)
    attribute(:items, {:array, AshSurface.Ported.ZodOrder.NodeE}, public?: true, default: [])
  end
end
