defmodule Playground.Jobs.Digest do
  @moduledoc "Digest records; stale drafts are archived by an AshOban trigger, heartbeats are scheduled."
  use Ash.Resource,
    domain: Playground.Jobs,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshOban]

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :status, :atom, constraints: [one_of: [:draft, :archived]], default: :draft, public?: true
    attribute :age_days, :integer, default: 0, public?: true, constraints: [min: 0]
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:title, :status, :age_days]
    end

    update :update do
      primary? true
      accept [:title, :status, :age_days]
    end

    update :archive do
      accept []
      require_atomic? false
      change set_attribute(:status, :archived)
    end

    action :heartbeat, :struct do
      constraints instance_of: __MODULE__

      run fn _input, _ctx ->
        Ash.create(__MODULE__, %{title: "heartbeat"}, authorize?: false)
      end
    end
  end

  oban do
    triggers do
      trigger :archive_stale do
        action :archive
        where expr(status == :draft and age_days > 30)
        queue :default
        scheduler_cron "*/5 * * * *"
        worker_module_name Playground.Jobs.Digest.AshOban.Worker.ArchiveStale
        scheduler_module_name Playground.Jobs.Digest.AshOban.Scheduler.ArchiveStale
      end
    end

    scheduled_actions do
      schedule :heartbeat, "0 * * * *" do
        action :heartbeat
        queue :default
        worker_module_name Playground.Jobs.Digest.AshOban.ActionWorker.Heartbeat
      end
    end
  end
end
