defmodule AshSurface.ErrorRuntimeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshSurface.{ErrorFormatter, ErrorHandler, Errors}

  defmodule Redact do
    @behaviour AshSurface.ErrorHandler
    def handle_error(error, _ctx), do: Map.put(error, :redacted, true)
  end

  defmodule Dropper do
    @behaviour AshSurface.ErrorHandler
    def handle_error(_error, _ctx), do: nil
  end

  defmodule Boom do
    def handle_error(_error, _ctx), do: raise("boom")
  end

  defp invalid(field), do: Ash.Error.Changes.Required.exception(field: field, type: :attribute)

  test "formatter renames keys and placeholders together, leaves vars values" do
    out =
      ErrorFormatter.format(
        %{message: "RPC %{action_name} bad", vars: %{action_name: "my_action"}},
        :camel_case
      )

    assert out == %{
             "message" => "RPC %{actionName} bad",
             "vars" => %{"actionName" => "my_action"}
           }
  end

  test "formatter pascal, snake, custom, non-map" do
    assert ErrorFormatter.format(%{a_b: 1}, :pascal_case) == %{"AB" => 1}
    assert ErrorFormatter.format(%{a_b: 1}, :snake_case) == %{"a_b" => 1}
    assert ErrorFormatter.format(%{a_b: 1}, &String.upcase/1) == %{"A_B" => 1}
    assert ErrorFormatter.format("x", :camel_case) == "x"
  end

  test "handler chain: identity default, resource then domain, nil drops" do
    assert ErrorHandler.chain(%{a: 1}, %{}, []) == %{a: 1}
    assert ErrorHandler.chain(%{a: 1}, %{}, [Redact, nil]) == %{a: 1, redacted: true}
    assert ErrorHandler.chain(%{a: 1}, %{}, [Dropper, Redact]) == nil
  end

  test "to_errors converts Ash errors and formats keys" do
    [e] = Errors.to_errors(invalid(:first_name))
    assert e["type"] == "required"
    assert e["fields"] == ["first_name"] or e["fields"] == ["firstName"]
    assert is_binary(e["message"])
  end

  test "handlers applied and nil filtered" do
    [e] = Errors.to_errors(invalid(:x), resource_handler: Redact, formatter: :snake_case)
    assert e["redacted"] == true
    assert Errors.to_errors(invalid(:x), domain_handler: Dropper) == []
  end

  test "failing handler fails closed with UUID" do
    log =
      capture_log(fn ->
        [e] = Errors.to_errors(invalid(:x), domain_handler: Boom, formatter: :snake_case)
        assert e["type"] == "unknown_error"
        assert e["message"] =~ e["details"]["error_id"]
        refute inspect(e) =~ "required"
      end)

    assert log =~ "Error handler failed"
  end

  test "unhandled non-Ash term logs uuid, client gets only the id" do
    log =
      capture_log(fn ->
        [e] = Errors.to_errors(%{secret: "s3cr3t"}, formatter: :snake_case)
        assert e["type"] == "unknown_error"
        refute inspect(e) =~ "s3cr3t"
        send(self(), {:id, e["details"]["error_id"]})
      end)

    assert_received {:id, id}
    assert log =~ id
  end

  test "show_raised_errors exposes raised exception message" do
    [hidden] = capture_log_result(fn -> Errors.to_errors(RuntimeError.exception("leak")) end)
    refute inspect(hidden) =~ "leak"
    [shown] = Errors.to_errors(RuntimeError.exception("leak"), show_raised_errors: true)
    assert shown["message"] =~ "leak"
  end

  defp capture_log_result(fun) do
    me = self()
    capture_log(fn -> send(me, {:r, fun.()}) end)
    assert_received {:r, r}
    r
  end
end
