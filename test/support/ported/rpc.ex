defmodule AshSurface.Ported.Rpc do
  @moduledoc """
  Test entry for the ported non-actuating RPC pipeline (`AshSurface.RuntimeParity.Rpc.Pipeline`).

  Installs the prepared manifest of `AshSurface.Ported.Domain` plus the RPC entry table
  (counterpart of the reference domain `typescript_rpc` block) and exposes:

    * `run(params, result)` - parse the request, process an already-materialized `result`
      term through the result processor and format the client envelope (no action runs)
    * `parse(params)` - stage 1 only (`{:ok, %Request{}} | {:error, term}`)
    * `error(params)` - the failure envelope for a request that is refused at parse time
  """

  alias AshSurface.Ported, as: P
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support}
  alias AshSurface.Ported.RFP

  @key {__MODULE__, :installed}

  def install do
    case :persistent_term.get(@key, nil) do
      nil ->
        Support.install(RFP.manifest(), entries())
        :persistent_term.put(@key, true)

      _ ->
        # another test process may have replaced the global table; re-assert ours
        Support.install(RFP.manifest(), entries())
    end

    :ok
  end

  def run(params, result, opts \\ []) do
    install()
    Pipeline.run_with_result(params, result, [], opts)
  end

  def parse(params, opts \\ []) do
    install()
    Pipeline.parse_request(params, opts)
  end

  @doc "Failure envelope for a request that must be refused before any action would run."
  def error(params, opts \\ []) do
    install()

    case Pipeline.parse_request(params, opts) do
      {:error, reason} -> Pipeline.error_response(reason)
      {:ok, request} -> {:unexpected_ok, request}
    end
  end

  def entries do
    alias AshSurface.RuntimeParity.Rpc.Pipeline, as: E

    [
      E.entry(:list_todos, P.Todo, :read),
      E.entry(:get_todo, P.Todo, :get_by_id),
      E.entry(:get_todo_by_id, P.Todo, :get_by_id),
      E.entry(:list_todos_with_custom_description, P.Todo, :read),
      E.entry(:list_todos_deprecated, P.Todo, :read),
      E.entry(:list_todos_deprecated_simple, P.Todo, :read),
      E.entry(:list_todos_with_see, P.Todo, :read),
      E.entry(:get_single_todo, P.Todo, :read, get?: true),
      E.entry(:get_single_todo_nullable, P.Todo, :read, get?: true, not_found_error?: false),
      E.entry(:get_todo_by_user_and_status, P.Todo, :read, get_by: [:user_id, :status]),
      E.entry(:create_todo, P.Todo, :create),
      E.entry(:update_todo, P.Todo, :update),
      E.entry(:update_todo_scoped, P.Todo, :update),
      E.entry(:complete_todo, P.Todo, :complete),
      E.entry(:set_priority_todo, P.Todo, :set_priority),
      E.entry(:update_todo_with_untyped_data, P.Todo, :update_with_untyped_data),
      E.entry(:bulk_complete_todo, P.Todo, :bulk_complete),
      E.entry(:ping_todo, P.Todo, :ping),
      E.entry(:get_statistics_todo, P.Todo, :get_statistics),
      E.entry(:search_todos, P.Todo, :search),
      E.entry(:search_paginated_todos, P.Todo, :search_paginated),
      E.entry(:list_recent_todos, P.Todo, :list_recent),
      E.entry(:list_high_priority_todos, P.Todo, :list_high_priority),
      E.entry(:list_todos_no_filter, P.Todo, :read, enable_filter?: false),
      E.entry(:list_todos_no_sort, P.Todo, :read, enable_sort?: false),
      E.entry(:list_todos_no_filter_no_sort, P.Todo, :read,
        enable_filter?: false,
        enable_sort?: false
      ),
      E.entry(:list_todos_allow_only_user, P.Todo, :read, allowed_loads: [:user]),
      E.entry(:list_todos_allow_nested, P.Todo, :read, allowed_loads: [:user, comments: [:todo]]),
      E.entry(:list_todos_deny_user, P.Todo, :read, denied_loads: [:user]),
      E.entry(:list_todos_deny_nested, P.Todo, :read, denied_loads: [comments: [:todo]]),
      E.entry(:list_todos_allow_nested_calc, P.Todo, :read,
        allowed_loads: [comments: [:weighted_score]]
      ),
      E.entry(:list_todos_deny_nested_calc, P.Todo, :read,
        denied_loads: [comments: [:weighted_score]]
      ),
      E.entry(:list_todos_deny_mapped_calc, P.Todo, :read, denied_loads: [user: [:is_active?]]),
      E.entry(:list_todos_deny_history_calc, P.Todo, :read,
        denied_loads: [metadata_history: [:display_category]]
      ),
      E.entry(:get_keyword_options_todo, P.Todo, :get_keyword_options),
      E.entry(:get_coordinates_info_todo, P.Todo, :get_coordinates_info),
      E.entry(:get_custom_data_todo, P.Todo, :get_custom_data),
      E.entry(:get_custom_data_list_todo, P.Todo, :get_custom_data_list),
      E.entry(:get_underscored_document_todo, P.Todo, :get_underscored_document),
      E.entry(:destroy_todo, P.Todo, :destroy),
      E.entry(:assign_to_user_todo, P.Todo, :assign_to_user),
      E.entry(:assign_to_users_todo, P.Todo, :assign_to_users),
      E.entry(:process_metadata_todo, P.Todo, :process_metadata),
      E.entry(:process_metadata_batch_todo, P.Todo, :process_metadata_batch),
      E.entry(:list_todo_comments, P.TodoComment, :read),
      E.entry(:list_todo_comments_keyset, P.TodoComment, :read_keyset_only),
      E.entry(:create_todo_comment, P.TodoComment, :create),
      E.entry(:update_todo_comment, P.TodoComment, :update),
      E.entry(:destroy_todo_comment, P.TodoComment, :destroy),
      E.entry(:list_users, P.User, :read),
      E.entry(:read_with_invalid_arg, P.User, :read_with_invalid_arg),
      E.entry(:list_users_deny_mapped_calc, P.User, :read, denied_loads: [:is_active?]),
      E.entry(:get_by_id, P.User, :get_by_id),
      E.entry(:create_user, P.User, :create),
      E.entry(:update_user, P.User, :update),
      E.entry(:destroy_user, P.User, :destroy),
      E.entry(:get_user_by_email, P.User, :read, get_by: [:email]),
      E.entry(:get_user_by_email_nullable, P.User, :read,
        get_by: [:email],
        not_found_error?: false
      ),
      E.entry(:get_user_by_email_error, P.User, :read, get_by: [:email], not_found_error?: true),
      E.entry(:update_me, P.User, :update_me, identities: []),
      E.entry(:destroy_me, P.User, :destroy_me, identities: []),
      E.entry(:update_user_by_identity, P.User, :update,
        identities: [:_primary_key, :unique_email]
      ),
      E.entry(:update_user_by_email, P.User, :update, identities: [:unique_email]),
      E.entry(:list_user_settings, P.UserSettings, :read),
      E.entry(:get_user_settings, P.UserSettings, :get_by_user),
      E.entry(:create_user_settings, P.UserSettings, :create),
      E.entry(:update_user_settings, P.UserSettings, :update),
      E.entry(:destroy_user_settings, P.UserSettings, :destroy),
      E.entry(:admin_list_user_settings, P.UserSettings, :read),
      E.entry(:list_org_todos, P.OrgTodo, :read),
      E.entry(:get_org_todo, P.OrgTodo, :get_by_id),
      E.entry(:create_org_todo, P.OrgTodo, :create),
      E.entry(:update_org_todo, P.OrgTodo, :update),
      E.entry(:complete_org_todo, P.OrgTodo, :complete),
      E.entry(:set_priority_org_todo, P.OrgTodo, :set_priority),
      E.entry(:bulk_complete_org_todo, P.OrgTodo, :bulk_complete),
      E.entry(:validate_array_constraints_org_todo, P.OrgTodo, :validate_array_constraints),
      E.entry(:get_statistics_org_todo, P.OrgTodo, :get_statistics),
      E.entry(:search_org_todos, P.OrgTodo, :search),
      E.entry(:destroy_org_todo, P.OrgTodo, :destroy),
      E.entry(:list_org_comments, P.OrgComment, :read),
      E.entry(:create_org_comment, P.OrgComment, :create),
      E.entry(:list_tasks, P.Task, :read),
      E.entry(:read_tasks_with_metadata, P.Task, :read_with_metadata),
      E.entry(:create_task, P.Task, :create),
      E.entry(:update_task, P.Task, :update),
      E.entry(:mark_completed_task, P.Task, :mark_completed),
      E.entry(:destroy_task, P.Task, :destroy),
      E.entry(:get_task_stats, P.Task, :get_task_stats),
      E.entry(:list_task_stats, P.Task, :list_task_stats),
      E.entry(:get_suggestion, P.Task, :get_suggestion),
      E.entry(:list_suggestions, P.Task, :list_suggestions),
      E.entry(:read_tasks_with_mapped_metadata, P.Task, :read_with_invalid_metadata_names,
        show_metadata: [:meta_1, :is_valid?, :field_2],
        metadata_names: [meta_1: "meta1", is_valid?: "isValid", field_2: "field2"]
      ),
      E.entry(:read_tasks_with_metadata_all, P.Task, :read_with_metadata, show_metadata: nil),
      E.entry(:read_tasks_with_metadata_false, P.Task, :read_with_metadata, show_metadata: false),
      E.entry(:read_tasks_with_metadata_empty, P.Task, :read_with_metadata, show_metadata: []),
      E.entry(:read_tasks_with_metadata_one, P.Task, :read_with_metadata,
        show_metadata: [:some_string]
      ),
      E.entry(:read_tasks_with_metadata_two, P.Task, :read_with_metadata,
        show_metadata: [:some_string, :some_number]
      ),
      E.entry(:create_task_metadata_all, P.Task, :create, show_metadata: nil),
      E.entry(:create_task_metadata_false, P.Task, :create, show_metadata: false),
      E.entry(:create_task_metadata_empty, P.Task, :create, show_metadata: []),
      E.entry(:create_task_metadata_one, P.Task, :create, show_metadata: [:some_string]),
      E.entry(:create_task_metadata_two, P.Task, :create,
        show_metadata: [:some_string, :some_number]
      ),
      E.entry(:update_task_metadata_all, P.Task, :update, show_metadata: nil),
      E.entry(:update_task_metadata_false, P.Task, :update, show_metadata: false),
      E.entry(:update_task_metadata_empty, P.Task, :update, show_metadata: []),
      E.entry(:update_task_metadata_one, P.Task, :update, show_metadata: [:some_string]),
      E.entry(:update_task_metadata_two, P.Task, :update,
        show_metadata: [:some_string, :some_number]
      ),
      E.entry(:destroy_task_metadata_all, P.Task, :destroy, show_metadata: nil),
      E.entry(:destroy_task_metadata_false, P.Task, :destroy, show_metadata: false),
      E.entry(:destroy_task_metadata_empty, P.Task, :destroy, show_metadata: []),
      E.entry(:destroy_task_metadata_one, P.Task, :destroy, show_metadata: [:some_string]),
      E.entry(:destroy_task_metadata_two, P.Task, :destroy,
        show_metadata: [:some_string, :some_number]
      ),
      E.entry(:read_tasks_with_typed_map_metadata, P.Task, :read_with_typed_map_metadata,
        show_metadata: nil
      ),
      E.entry(:read_no_relationships, P.NoRelationshipsResource, :read),
      E.entry(:list_content, P.Content, :read),
      E.entry(:get_content, P.Content, :get_by_id),
      E.entry(:create_content, P.Content, :create),
      E.entry(:update_content, P.Content, :update),
      E.entry(:destroy_content, P.Content, :destroy),
      E.entry(:get_important_dates, P.Article, :get_important_dates),
      E.entry(:get_publication_date, P.Article, :get_publication_date),
      E.entry(
        :create_article_with_optional_hero_image,
        P.Article,
        :create_with_optional_hero_image
      ),
      E.entry(:list_subscriptions, P.Subscription, :read),
      E.entry(:create_subscription, P.Subscription, :create),
      E.entry(:update_subscription, P.Subscription, :update),
      E.entry(:destroy_subscription, P.Subscription, :destroy),
      E.entry(:update_subscription_by_user_status, P.Subscription, :update,
        identities: [:by_user_and_status]
      ),
      E.entry(:update_subscription_by_identity, P.Subscription, :update,
        identities: [:_primary_key, :by_user_and_status]
      ),
      E.entry(:destroy_subscription_by_user_status, P.Subscription, :destroy,
        identities: [:by_user_and_status]
      ),
      E.entry(:list_tenant_settings, P.TenantSetting, :read),
      E.entry(:create_tenant_setting, P.TenantSetting, :create),
      E.entry(:update_tenant_setting, P.TenantSetting, :update),
      E.entry(:destroy_tenant_setting, P.TenantSetting, :destroy),
      E.entry(:list_input_parsing, P.InputParsing.Resource, :read),
      E.entry(:get_input_parsing, P.InputParsing.Resource, :get_by_id),
      E.entry(:create_input_parsing, P.InputParsing.Resource, :create),
      E.entry(:create_input_parsing_with_args, P.InputParsing.Resource, :create_with_args),
      E.entry(:update_input_parsing, P.InputParsing.Resource, :update),
      E.entry(:destroy_input_parsing, P.InputParsing.Resource, :destroy),
      E.entry(:search_input_parsing, P.InputParsing.Resource, :search),
      E.entry(:process_data_input_parsing, P.InputParsing.Resource, :process_data),
      E.entry(:process_profile_input_parsing, P.InputParsing.Resource, :process_profile),
      E.entry(:list_users_map, P.NestedMapResource, :list_users_map),
      E.entry(:get_metrics, P.NestedMapResource, :get_metrics),
      E.entry(:get_nested_stats, P.NestedMapResource, :get_nested_stats),
      E.entry(:get_metadata_report, P.NestedMapResource, :get_metadata_report)
    ]
  end
end
