# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.EmptyResource do
  @moduledoc """
  Test resource with minimal configuration.
  """
  use Ash.Resource,
    domain: AshSurface.Ported.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  surface do
    type_name("EmptyResource")
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: false)
  end

  actions do
    defaults([:read])
  end
end
