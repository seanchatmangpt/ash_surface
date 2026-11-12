defmodule AshSurface.Ported.Rpc.Rao.Badge do
  @moduledoc "Lane RAO embedded resource: mapped names differ from computed spelling."
  use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

  surface do
    type_name("RaoBadge")
    field_names(is_gold?: "gold", level_1: "lvl")
  end

  attributes do
    attribute(:is_gold?, :boolean, public?: true)
    attribute(:level_1, :integer, public?: true)
    attribute(:plain_name, :string, public?: true)
  end
end

defmodule AshSurface.Ported.Rpc.Rao.TextBlock do
  @moduledoc "Lane RAO union member (embedded resource)."
  use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

  surface do
    type_name("RaoTextBlock")
    field_names(word_count_1: "wc")
  end

  attributes do
    attribute(:word_count_1, :integer, public?: true)
    attribute(:body_text, :string, public?: true)
  end
end

defmodule AshSurface.Ported.Rpc.Rao.Owner do
  @moduledoc "Lane RAO relationship destination with mapped names."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rao.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RaoOwner")
    field_names(owner_name_1: "who", is_vip?: "vip")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:owner_name_1, :string, public?: true)
    attribute(:is_vip?, :boolean, public?: true)
    attribute(:home_city, :string, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.Rao.Item do
  @moduledoc "Lane RAO root: relationship, embedded, union and calculation, all nested-mapped."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rao.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RaoItem")
    field_names(item_label_1: "tag")

    typed_query :rao_items, :read do
      fields_const_name("raoItems")
      result_type_name("RaoItemsResult")

      fields([
        :id,
        :item_label_1,
        owner: [:id, :owner_name_1, :is_vip?, :home_city],
        badge: [:is_gold?, :level_1, :plain_name],
        badge_copy: [:is_gold?, :level_1],
        content: [text: [:word_count_1, :body_text]]
      ])
    end
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:item_label_1, :string, public?: true)
    attribute(:badge, AshSurface.Ported.Rpc.Rao.Badge, public?: true)

    attribute :content, :union do
      public?(true)

      constraints(
        types: [
          text: [
            type: AshSurface.Ported.Rpc.Rao.TextBlock,
            tag: :kind,
            tag_value: "text"
          ],
          note: [type: :string]
        ],
        storage: :type_and_value
      )
    end
  end

  relationships do
    belongs_to :owner, AshSurface.Ported.Rpc.Rao.Owner do
      public?(true)
      attribute_type(:uuid)
    end
  end

  calculations do
    calculate :badge_copy, AshSurface.Ported.Rpc.Rao.Badge, fn records, _ ->
      Enum.map(records, & &1.badge)
    end do
      public?(true)
    end
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Rpc.Rao.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rao.Item)
    resource(AshSurface.Ported.Rpc.Rao.Owner)
  end
end

defmodule AshSurface.Ported.Rpc.Rao.NestedMappedNamesTest do
  @moduledoc """
  Lane RAO. Nested typed-query levels (relationship, embedded, calculation-with-nested-fields,
  union member) must resolve each field through the DESTINATION resource's mapping, formatted
  exactly once. Every mapped spelling here differs from the computed camelCase one.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc.Rao.{Badge, Item, Owner, TextBlock}
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support, TypedQuery}

  @otp_app :ash_surface_ported_rao
  @id "33333333-3333-3333-3333-333333333333"

  defp install do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rao.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Support.install(Compat.prepare(manifest), [Pipeline.entry(:list_items, Item, :read)])
  end

  defp item do
    badge = struct(Badge, %{is_gold?: true, level_1: 7, plain_name: "p"})

    struct(Item, %{
      id: @id,
      item_label_1: "L",
      owner: struct(Owner, %{id: @id, owner_name_1: "Ann", is_vip?: true, home_city: "Oslo"}),
      badge: badge,
      badge_copy: badge,
      content: %Ash.Union{
        type: :text,
        value: struct(TextBlock, %{word_count_1: 3, body_text: "hi"})
      }
    })
  end

  test "typed query request spells every nested level through the destination mapping" do
    install()
    {:ok, request} = TypedQuery.parse(:rao_items, %{}, [])

    assert {:owner, [:id, :owner_name_1, :is_vip?, :home_city]} in request.extraction_template
    assert {:badge, [:is_gold?, :level_1, :plain_name]} in request.extraction_template
    assert {:badge_copy, [:is_gold?, :level_1]} in request.extraction_template
    assert {:content, [text: [:word_count_1, :body_text]]} in request.extraction_template
  end

  test "typed query rows carry mapped keys at every nested level, none computed" do
    install()
    assert %{"success" => true, "data" => [row]} = TypedQuery.run(:rao_items, %{}, [item()], [])

    assert row["tag"] == "L"
    assert row["owner"] == %{"id" => @id, "who" => "Ann", "vip" => true, "homeCity" => "Oslo"}
    assert row["badge"] == %{"gold" => true, "lvl" => 7, "plainName" => "p"}
    assert row["badgeCopy"] == %{"gold" => true, "lvl" => 7}
    assert row["content"] == %{"text" => %{"wc" => 3, "bodyText" => "hi"}}

    refute Map.has_key?(row, "itemLabel1")
    refute Map.has_key?(row["owner"], "ownerName1")
    refute Map.has_key?(row["badge"], "isGold")
    refute Map.has_key?(row["badge"], "level1")
    refute Map.has_key?(row["content"]["text"], "wordCount1")
  end

  describe "typed query survivors (wave3 skmutf T1-T5)" do
    defp install_entries(entries) do
      Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rao.Domain])
      {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
      Support.install(Compat.prepare(manifest), entries)
    end

    test "T1: with several entries for one action the alphabetically first name is chosen" do
      install_entries([
        Pipeline.entry(:zeta_items, Item, :read),
        Pipeline.entry(:alpha_items, Item, :read),
        Pipeline.entry(:mid_items, Item, :read)
      ])

      assert {:ok, request} = TypedQuery.parse(:rao_items, %{}, [])
      assert request.rpc_action.name == :alpha_items
    end

    test "T3: action_not_found carries the typed query's action atom" do
      install_entries([])

      assert {:error, {:action_not_found, :read}} =
               TypedQuery.parse(:rao_items, %{}, resources: [Item])
    end

    test "T4: every declared top-level field reaches the request, in order" do
      install()
      {:ok, request} = TypedQuery.parse(:rao_items, %{}, [])

      assert Enum.map(request.extraction_template, fn
               {k, _} -> k
               k -> k
             end) == [:id, :item_label_1, :owner, :badge, :badge_copy, :content]
    end

    test "T5: client_fields without the resource argument cannot spell mapped names" do
      assert TypedQuery.client_fields([:item_label_1], Item) == ["tag"]
      assert TypedQuery.client_fields([:item_label_1]) == ["itemLabel1"]

      assert TypedQuery.client_fields([owner: [:owner_name_1]], Item) == [%{"owner" => ["who"]}]
    end

    test "format_field_for_client atom-resource path emits the mapping (RAN survivor 4)" do
      alias AshSurface.RuntimeParity.Rpc.FieldFormatter
      assert FieldFormatter.format_field_for_client(:is_gold?, Badge, :camel_case) == "gold"
      assert FieldFormatter.format_field_for_client(:level_1, Badge, :camel_case) == "lvl"

      assert FieldFormatter.format_field_for_client(:plain_name, Badge, :camel_case) ==
               "plainName"

      assert AshSurface.FieldName.format_field_for_client(:is_gold?, Badge, :snake_case) == "gold"
    end
  end
end
