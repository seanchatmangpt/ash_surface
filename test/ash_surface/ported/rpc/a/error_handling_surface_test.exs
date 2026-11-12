defmodule AshSurface.Ported.Rpc.A.ErrorHandlingSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `error_handling_test.exs`. Failures are driven through the real
  request parser (`Rpc.parse/Rpc.error`), `RuntimeParity.Rpc.ErrorBuilder` and
  `AshSurface.Errors`; no action runs.

  Divergences (ash_surface lawful behaviour asserted): no protocol dispatch, so protocol-less
  errors surface as `unknown_error` (closed type enum) with the id under `details.error_id`;
  handlers are per-call opts / `handle_surface_error/2`, not domain DSL entities.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Errors
  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.Rpc
  alias AshSurface.RuntimeParity.Rpc.ErrorBuilder

  defp to_errors(error, opts \\ []),
    do: error |> Errors.to_errors(Keyword.put_new(opts, :formatter, :snake_case)) |> sym()

  defp sym(%{} = m) when not is_struct(m),
    do: Map.new(m, fn {k, v} -> {if(is_binary(k), do: String.to_atom(k), else: k), sym(v)} end)

  defp sym(l) when is_list(l), do: Enum.map(l, &sym/1)
  defp sym(v), do: v

  defp build(error), do: error |> ErrorBuilder.build_error_response() |> sym()

  describe "comprehensive error message generation" do
    test "action not found error provides clear guidance" do
      response = build({:action_not_found, "nonexistent_action"})

      assert response.type == "action_not_found"
      assert response.message == "RPC action %{action_name} not found"
      assert response.short_message == "Action not found"
      assert response.vars.action_name == "nonexistent_action"
      assert String.contains?(response.details.suggestion, "rpc block")
    end

    test "invalid pagination error shows expected format" do
      response = build({:invalid_pagination, "invalid_value"})

      assert response.type == "invalid_pagination"
      assert response.message == "Invalid pagination parameter format"
      assert response.short_message == "Invalid pagination"
      assert response.vars.received == "\"invalid_value\""
      assert String.contains?(response.details.expected, "Map")
    end
  end

  describe "field validation error messages" do
    test "unknown field error provides debugging context" do
      response =
        build({:invalid_fields, {:unknown_field, :nonexistent, P.Todo, []}})

      assert response.type == "unknown_field"
      assert response.message == "Unknown field %{field} for resource %{resource}"
      assert response.short_message == "Unknown field"
      assert response.vars.field == "nonexistent"
      assert response.vars.resource == inspect(P.Todo)
      assert response.fields == ["nonexistent"]
      assert String.contains?(response.details.suggestion, "public attribute")
    end

    test "unsupported field combination error shows all context" do
      response =
        build(
          {:invalid_fields,
           {:unsupported_field_combination, :relationship, :user, "invalid_spec", []}}
        )

      assert response.type == "unsupported_field_combination"

      assert response.message ==
               "Unsupported combination of field type and specification for %{field}"

      assert response.short_message == "Unsupported field combination"
      assert response.vars.field == "user"
      assert response.vars.field_type == "relationship"
      assert response.fields == ["user"]
      assert response.details.field_spec == "\"invalid_spec\""
      assert String.contains?(response.details.suggestion, "documentation")
    end
  end

  describe "ash framework error handling" do
    test "ash exception error preserves framework details" do
      ash_error = %Ash.Error.Invalid{
        class: :invalid,
        errors: [%Ash.Error.Changes.InvalidAttribute{field: :title, message: "is required"}],
        path: [:data, :attributes]
      }

      assert [response] = build(ash_error)
      assert response.type == "invalid_attribute"
      assert is_binary(response.message)
      assert response.fields == ["title"]
      assert response.path == []
    end

    test "generic ash error fallback" do
      assert [response] = build(%{unexpected: "error format"})
      assert response.type == "unknown_error"
      assert is_binary(response.message)
    end
  end

  describe "error response structure consistency" do
    @errors [
      {:action_not_found, "test"},
      {:invalid_pagination, "invalid"},
      {:invalid_fields, {:unknown_field, :test, P.Todo, []}}
    ]

    test "all errors have required fields" do
      for error <- @errors do
        response = build(error)

        assert Map.has_key?(response, :type)
        assert Map.has_key?(response, :message)
        assert Map.has_key?(response, :details)
        assert is_binary(response.type) and response.type != ""
        assert is_binary(response.message) and response.message != ""
        assert is_map(response.details)
      end
    end

    test "error messages are user-friendly" do
      response =
        build({:invalid_fields, {:unknown_field, :nonexistent, P.Todo, []}})

      refute String.contains?(response.message, "atom")
      refute String.contains?(response.message, "module")
      refute String.contains?(response.message, "struct")
      assert String.contains?(response.message, "%{field}")
      assert String.contains?(response.message, "%{resource}")
      refute String.contains?(response.vars.field, "atom")
      refute String.contains?(response.vars.resource, "module")
    end

    test "suggestions are actionable" do
      action_words = ["check", "add", "remove", "ensure", "use", "configure"]

      for error <- [Enum.at(@errors, 0), Enum.at(@errors, 2)] do
        response = build(error)
        assert %{suggestion: suggestion} = response.details

        assert Enum.any?(action_words, &String.contains?(String.downcase(suggestion), &1)),
               "Suggestion should contain actionable advice: #{suggestion}"
      end
    end
  end

  describe "list error handling (bulk operation errors)" do
    test "processes a list of Ash errors" do
      errors = [
        %Ash.Error.Invalid{class: :invalid, errors: [%Ash.Error.Changes.Required{field: :title}]},
        %Ash.Error.Invalid{
          class: :invalid,
          errors: [%Ash.Error.Changes.InvalidAttribute{field: :age}]
        }
      ]

      result = build(errors)
      assert length(result) == 2
      types = Enum.map(result, & &1.type)
      assert "required" in types
      assert "invalid_attribute" in types
    end

    test "processes a list with a single error" do
      errors = [
        %Ash.Error.Invalid{class: :invalid, errors: [%Ash.Error.Changes.Required{field: :email}]}
      ]

      assert [error] = build(errors)
      assert error.type == "required"
      assert error.fields == ["email"]
    end

    test "flattens nested lists from errors with multiple sub-errors" do
      errors = [
        %Ash.Error.Invalid{
          class: :invalid,
          errors: [
            %Ash.Error.Changes.Required{field: :title},
            %Ash.Error.Changes.InvalidAttribute{field: :age}
          ]
        }
      ]

      result = build(errors)
      assert length(result) == 2
      types = Enum.map(result, & &1.type)
      assert "required" in types
      assert "invalid_attribute" in types
    end

    test "handles empty list" do
      assert build([]) == []
    end

    test "handles list with mixed error types" do
      errors = [
        %Ash.Error.Invalid{class: :invalid, errors: [%Ash.Error.Changes.Required{field: :title}]},
        %Ash.Error.Query.NotFound{}
      ]

      result = build(errors)
      assert length(result) == 2
      types = Enum.map(result, & &1.type)
      assert "required" in types
      assert "not_found" in types
    end
  end

  describe "end-to-end error handling in pipeline" do
    test "pipeline returns properly structured error responses" do
      assert {:error, {:action_not_found, "nonexistent_action"}} =
               Rpc.parse(%{"action" => "nonexistent_action", "fields" => ["id"]})
    end

    test "field validation errors flow through pipeline correctly" do
      assert {:error, {:unknown_field, :unknown_field, P.Todo, []}} =
               Rpc.parse(%{"action" => "list_todos", "fields" => ["id", "unknown_field"]})
    end

    test "nested field validation errors are preserved" do
      assert {:error, {:unknown_field, :unknown_user_field, P.User, [:user]}} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => [%{"user" => ["id", "unknown_user_field"]}]
               })
    end

    test "a refused request renders a failure envelope end to end" do
      assert %{"success" => false, "errors" => [error]} =
               Rpc.error(%{"action" => "nonexistent_action", "fields" => ["id"]})

      assert error["type"] == "action_not_found"
      assert error["vars"]["actionName"] == "nonexistent_action"
    end
  end

  describe "invalid_field_format error" do
    test "invalid_field_format with path builds a proper client error" do
      response =
        build({:invalid_field_format, %{"self" => %{"args" => %{}}}, [:user]})

      assert response.type == "invalid_field_format"
      assert is_binary(response.message)
      assert response.path == ["user"]
      assert Map.has_key?(response.details, :hint)
    end
  end

  describe "typed_query_not_found error" do
    test "builds a proper client error" do
      response = build({:typed_query_not_found, "missing_query"})

      assert response.type == "typed_query_not_found"
      assert response.vars.typed_query_name == "missing_query"
      assert String.contains?(response.details.suggestion, "typed_queries")
    end
  end

  describe "fallback error shape" do
    defmodule NoImplError do
      use Splode.Error, fields: [:foo], class: :invalid

      def message(_), do: "no protocol implementation for this one"
    end

    @tag capture_log: true
    test "errors without a known shape surface a `type` key" do
      [response] = to_errors(NoImplError.exception(foo: :bar))

      assert response.type == "unknown_error"
      assert response.short_message == "Unknown error"
      assert is_binary(response.details.error_id)
      refute Map.has_key?(response, :code)
      refute String.contains?(response.message, "no protocol implementation")
    end

    @tag capture_log: true
    test "the generic error id reaches the client inside the message" do
      [response] = to_errors(NoImplError.exception(foo: :bar))

      assert String.contains?(response.message, response.details.error_id)
    end

    test "show_raised_errors exposes the exception with a `type` key" do
      [response] = to_errors(NoImplError.exception(foo: :bar), show_raised_errors: true)

      assert response.type == "unknown_error"
      assert response.message == "no protocol implementation for this one"
      refute Map.has_key?(response, :code)
    end

    test "missing tenant surfaces as tenant_required, not unknown_error" do
      error = Ash.Error.Invalid.TenantRequired.exception(resource: P.Todo)

      [response] = to_errors(error)

      assert response.type == "tenant_required"
      assert response.short_message == "Tenant required"
      assert String.contains?(response.message, "tenant")
    end
  end

  describe "error payload serialization" do
    defmodule InternalConfig do
      defstruct [:name, :db_host, :api_key]
    end

    defp serialized_vars(vars) do
      error =
        Ash.Error.Changes.InvalidChanges.exception(fields: [:amount], message: "bad", vars: vars)

      [response] = to_errors(error)
      response.vars
    end

    @tag capture_log: true
    test "unknown structs are reduced to their module name, not unwrapped" do
      config = %InternalConfig{
        name: "standard",
        db_host: "postgres://admin@10.0.0.5:5432/prod",
        api_key: "sk_live_SUPER_SECRET"
      }

      vars = serialized_vars(rule: config)

      assert vars.rule ==
               "#AshSurface.Ported.Rpc.A.ErrorHandlingSurfaceTest.InternalConfig<>"

      refute String.contains?(Jason.encode!(vars), "sk_live_SUPER_SECRET")
      refute String.contains?(Jason.encode!(vars), "10.0.0.5")
    end

    @tag capture_log: true
    test "Ash.ForbiddenField keeps its original_value hidden" do
      forbidden = %Ash.ForbiddenField{
        field: :ssn,
        type: :attribute,
        original_value: "123-45-6789"
      }

      vars = serialized_vars(value: forbidden)

      refute String.contains?(Jason.encode!(vars), "123-45-6789")
    end

    test "value structs serialize to their natural representation" do
      vars = serialized_vars(max: Decimal.new("100.5"), name: Ash.CiString.new("Fred"))

      assert vars.max == "100.5"
      assert vars.name == "Fred"
    end

    @tag capture_log: true
    test "pids, references and functions do not leak identifiers" do
      vars = serialized_vars(pid: self(), ref: make_ref(), fun: &Enum.count/1)

      assert vars.pid == "#PID<>"
      assert vars.ref == "#Reference<>"
      assert vars.fun == "#Function<>"
    end
  end

  describe "error handler failures fail closed" do
    defmodule PartialErrorHandler do
      @moduledoc "Pattern matches only the shapes the developer anticipated."
      def handle_error(%{type: "invalid_attribute"} = error, _context) do
        %{error | message: "Invalid value.", short_message: "Invalid value", vars: %{}}
      end

      def throw_error(_error, _context), do: throw(:nope)
    end

    @secret "search backend unreachable at es.internal:9200 (token=S3cr3t-Pr0d-Pw)"

    test "an error class the handler matches is redacted" do
      error = Ash.Error.Changes.InvalidAttribute.exception(field: :email, message: @secret)

      [response] = to_errors(error, domain_handler: PartialErrorHandler)

      assert response.message == "Invalid value."
      refute String.contains?(response.message, "S3cr3t-Pr0d-Pw")
    end

    @tag capture_log: true
    test "an error class the handler raises on returns a generic error, not the raw one" do
      error = Ash.Error.Query.InvalidArgument.exception(field: :filter, message: @secret)

      [response] = to_errors(error, domain_handler: PartialErrorHandler)

      assert response.type == "unknown_error"
      assert response.short_message == "Unknown error"
      assert is_binary(response.details.error_id)
      assert response.vars == %{}
      assert response.fields == []
      refute String.contains?(response.message, "S3cr3t-Pr0d-Pw")
      refute String.contains?(response.message, "es.internal")
    end

    @tag capture_log: true
    test "a handler that throws is treated the same as one that raises" do
      error = Ash.Error.Query.InvalidArgument.exception(field: :filter, message: @secret)

      [response] =
        to_errors(error, domain_handler: {PartialErrorHandler, :throw_error, []})

      assert response.type == "unknown_error"
      refute String.contains?(response.message, "S3cr3t-Pr0d-Pw")
    end
  end

  describe "Reactor.Error.Invalid.RunStepError handling" do
    test "delegates to inner Ash error" do
      inner_error = Ash.Error.Changes.InvalidChanges.exception(message: "bad input")

      run_step_error =
        Reactor.Error.Invalid.RunStepError.exception(
          error: inner_error,
          step: %Reactor.Step{name: :test_step}
        )

      assert [error] = build(run_step_error)
      assert error.type == "invalid_changes"
      assert error.message == "bad input"
    end

    test "delegates to inner Ash error class wrapper" do
      inner_error =
        Ash.Error.Changes.InvalidChanges.exception(message: "wrapped error")
        |> Ash.Error.to_error_class()

      run_step_error =
        Reactor.Error.Invalid.RunStepError.exception(
          error: inner_error,
          step: %Reactor.Step{name: :test_step}
        )

      assert [error] = build(run_step_error)
      assert error.type == "invalid_changes"
      assert error.message == "wrapped error"
    end

    @tag capture_log: true
    test "falls back to generic error for unknown inner errors" do
      run_step_error =
        Reactor.Error.Invalid.RunStepError.exception(
          error: RuntimeError.exception("something unexpected"),
          step: %Reactor.Step{name: :test_step}
        )

      assert [error] = build(run_step_error)
      assert error.type == "unknown_error"
    end
  end
end
