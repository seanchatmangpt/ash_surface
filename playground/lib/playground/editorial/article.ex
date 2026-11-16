defmodule Playground.Editorial.Article do
  @moduledoc """
  Editorial article: AshPaperTrail version history, AshArchival soft delete (ETS supports the
  soft-destroy update, so no data-layer substitution is needed) and an AshStateMachine
  draft -> review -> published -> retired lifecycle.
  """
  use Ash.Resource,
    domain: Playground.Editorial,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPaperTrail.Resource, AshArchival.Resource, AshStateMachine]

  ets do
    private? false
  end

  paper_trail do
    change_tracking_mode :full_diff
    store_action_name? true
    ignore_attributes [:inserted_at, :updated_at]
    # public relationship = the admin's capability signal for the History tab
    relationship_opts public?: true
    public_timestamps? true
    belongs_to_actor :author, Playground.Blog.Author, domain: Playground.Blog
  end

  archive do
    exclude_read_actions [:with_archived]
  end

  state_machine do
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :submit, from: :draft, to: :review
      transition :publish, from: :review, to: :published
      transition :reject, from: :review, to: :draft
      transition :retire, from: :published, to: :retired
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, public?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy, create: [:title, :body]]

    update :update do
      primary? true
      accept [:title, :body]
      require_atomic? false
    end

    read :with_archived do
      description "Reads every article, including archived ones."
    end

    update :submit do
      require_atomic? false
      change transition_state(:review)
    end

    update :publish do
      require_atomic? false
      change transition_state(:published)
    end

    update :reject do
      require_atomic? false
      change transition_state(:draft)
    end

    update :retire do
      require_atomic? false
      change transition_state(:retired)
    end

    update :restore do
      description "Un-archives an article."
      require_atomic? false
      change set_attribute(:archived_at, nil)
    end
  end
end
