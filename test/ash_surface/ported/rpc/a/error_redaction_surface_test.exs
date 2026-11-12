defmodule AshSurface.Ported.Rpc.A.ErrorRedactionSurfaceTest do
  @moduledoc """
  Non-actuating port of `error_redaction_test.exs`. Divergences (asserted lawfully):
  ash_surface's redaction envelope has `type: "unknown_error"` with the id under
  `details.error_id` (reference: `type: "internal_error"` with top-level `error_id`), and a
  keyword list is redacted per element. The struct-typed-argument cast error is raised by Ash
  action input casting (data layer) and stays in the gap file.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.Rpc
  alias AshSurface.RuntimeParity.Rpc.Pipeline
  alias AshSurface.RuntimeParity.Rpc.ErrorBuilder

  @secret "sk_live_123"

  describe "unrecognised error terms" do
    for {label, term} <- [
          {"atom-tagged 2-tuple", {:internal_state, %{api_key: "sk_live_123"}}},
          {"untagged tuple", {:a, :b, %{api_key: "sk_live_123"}}},
          {"binary", "sk_live_123"},
          {"keyword list", [message: "is invalid", value: "sk_live_123"]}
        ] do
      test "#{label} is redacted from the client and logged with an error id" do
        {responses, log} =
          with_log(fn -> ErrorBuilder.build_error_response(unquote(Macro.escape(term))) end)

        responses = List.wrap(responses)
        assert responses != []

        for response <- responses do
          refute inspect(response) =~ @secret
          assert response.type == "unknown_error"
          error_id = response.details.error_id
          assert is_binary(error_id)
          assert response.message =~ error_id
          assert log =~ error_id
        end

        assert log =~ @secret
      end
    end
  end

  describe "primitive return types" do
    test "field selection on a primitive return reports the type name, not the type struct" do
      result =
        Rpc.error(%{"action" => "get_publication_date", "fields" => ["x"], "input" => %{}})

      assert result["success"] == false
      assert [%{"type" => "invalid_field_selection", "vars" => vars}] = result["errors"]
      assert vars["returnType"] == "Date"
      refute inspect(result) =~ "Ash.Info.Manifest"
    end
  end

  describe "invalid struct-typed arguments" do
    test "produce a proper argument error instead of inspected cast-error terms" do
      input = %{"assignee" => %{"id" => "not-a-uuid", "name" => "x", "email" => "e"}}

      assert {:ok, _request} =
               Rpc.parse(%{
                 "action" => "assign_to_user_todo",
                 "fields" => ["assigneeId"],
                 "input" => input
               })

      errors =
        Ash.ActionInput.for_action(P.Todo, :assign_to_user, %{assignee: input["assignee"]}).errors

      result = Pipeline.error_response(errors)
      assert result["success"] == false
      assert result["errors"] != []

      for error <- result["errors"] do
        refute error["type"] in ["field_validation_error", "unknown_error", "internal_error"]
        refute Map.has_key?(error["details"] || %{}, "error")
      end

      assert [%{"type" => "invalid_argument", "path" => ["assignee"], "fields" => ["id"]}] =
               result["errors"]
    end
  end

  describe "redaction envelope shape and known-error passthrough" do
    test "the client envelope for an unrecognised term is exactly the generic redaction map" do
      {result, log} =
        with_log(fn -> Pipeline.error_response({:unknown_thing, %{api_key: @secret}}) end)

      assert %{"success" => false, "errors" => [error]} = result
      id = error["details"]["errorId"]
      assert {:ok, _} = Ecto.UUID.cast(id)

      assert error == %{
               "type" => "unknown_error",
               "shortMessage" => "Unknown error",
               "message" => "Something went wrong. Unique error id: " <> id,
               "vars" => %{},
               "fields" => [],
               "path" => [],
               "details" => %{"errorId" => id}
             }

      assert log =~ id
      refute inspect(result) =~ @secret
    end

    test "each redacted error gets its own error id" do
      {[a], _} = with_log(fn -> List.wrap(Pipeline.error_response({:x, 1})["errors"]) end)
      {[b], _} = with_log(fn -> List.wrap(Pipeline.error_response({:x, 1})["errors"]) end)
      refute a["details"]["errorId"] == b["details"]["errorId"]
    end

    test "an unexposed Ash UnknownError is redacted rather than leaking its payload" do
      error = Ash.Error.Unknown.UnknownError.exception(error: @secret)

      {result, log} = with_log(fn -> Pipeline.error_response(error) end)

      assert [%{"type" => "unknown_error", "vars" => %{}} = e] = result["errors"]
      refute inspect(result) =~ @secret
      assert log =~ e["details"]["errorId"]
    end

    test "a recognised Ash error is NOT redacted: it keeps its own type, message and vars" do
      error = Ash.Error.Query.NotFound.exception(primary_key: %{id: 1}, resource: P.Todo)

      {result, log} = with_log(fn -> Pipeline.error_response(error) end)

      assert [e] = result["errors"]
      assert e["type"] == "not_found"
      assert e["shortMessage"] == "Not found"
      assert e["message"] == "record with id: 1 not found"
      assert e["vars"] == %{"resource" => "Todo"}
      refute Map.has_key?(e["details"], "errorId")
      assert log == ""
    end
  end

  describe "short-message and type table entries are pinned exactly" do
    for {label, error, type, short} <- [
          {"Policy", Ash.Error.Forbidden.Policy.exception([]), "forbidden", "Forbidden"},
          {"TenantRequired", Ash.Error.Invalid.TenantRequired.exception(resource: P.Todo),
           "tenant_required", "Tenant required"},
          {"Changes.Required",
           Ash.Error.Changes.Required.exception(
             field: :title,
             type: :attribute,
             resource: P.Todo
           ), "required", "Required field"},
          {"ReadActionRequiresActor", Ash.Error.Query.ReadActionRequiresActor.exception([]),
           "forbidden", "Authentication required"}
        ] do
      test "#{label} classifies to exactly {#{type}, #{short}} on the wire" do
        assert [e] = Pipeline.error_response(unquote(Macro.escape(error)))["errors"]
        assert e["type"] == unquote(type)
        assert e["shortMessage"] == unquote(short)

        assert AshSurface.Errors.classify(unquote(Macro.escape(error))) ==
                 {unquote(type), unquote(short)}
      end
    end

    test "an exposed raised UnknownError carries short message 'Unknown error' and its message" do
      error = Ash.Error.Unknown.UnknownError.exception(error: "boom")

      assert [e] = AshSurface.Errors.to_errors(error, show_raised_errors: true)
      assert e["shortMessage"] == "Unknown error"
      assert e["type"] == "unknown_error"
      assert e["message"] == "boom"
    end
  end
end
