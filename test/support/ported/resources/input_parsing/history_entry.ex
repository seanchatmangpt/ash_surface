# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSurface.Ported.InputParsing.HistoryEntry do
  @moduledoc """
  Embedded resource for testing arrays of embedded resources in input parsing.

  Used to verify that arrays of embedded resources correctly apply
  field name mappings during input formatting.
  """
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshSurface.Resource]

  surface do
    type_name("InputParsingHistoryEntry")
    # String values are the exact TypeScript names (no additional formatting)
    field_names(change_count_1: "changeCount1", was_reverted?: "wasReverted")
  end

  attributes do
    attribute :action_name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :timestamp, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    attribute :change_count_1, :integer do
      default(1)
      public?(true)
    end

    attribute :was_reverted?, :boolean do
      default(false)
      public?(true)
    end

    attribute :details, :map do
      allow_nil?(true)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end
end
