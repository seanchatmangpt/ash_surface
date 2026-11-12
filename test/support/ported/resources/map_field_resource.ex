# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.MapFieldResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  surface do
    type_name("MapFieldResource")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :metadata, AshSurface.Ported.CustomMetadata do
      public?(true)
    end
  end

  actions do
    default_accept(:*)
    defaults([:read, :destroy, create: :*, update: :*])
  end
end
