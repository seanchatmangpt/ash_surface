defmodule AshSurface.ErrorsConfigTest do
  use ExUnit.Case, async: false

  alias AshSurface.{ErrorFormatter, Errors}

  defmodule CfgHandler do
    def handle_error(error, _ctx), do: Map.put(error, :via, "config")
  end

  defmodule ResHandler do
    def handle_error(error, _ctx), do: Map.put(error, :via, "resource")
  end

  defmodule Res do
    def handle_surface_error(error, _ctx), do: Map.put(error, :via, "resource")
  end

  defmodule Out do
    def format_error(error), do: Map.put(error, "formatted", true)
    def tag(error, tag), do: Map.put(error, "tag", tag)
  end

  setup do
    keys = [
      :show_raised_errors,
      :show_policy_breakdowns,
      :error_handler,
      :error_output_formatter,
      :output_field_formatter
    ]

    saved = for k <- keys, do: {k, Application.fetch_env(:ash_surface, k)}

    on_exit(fn ->
      for {k, v} <- saved do
        case v do
          {:ok, val} -> Application.put_env(:ash_surface, k, val)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)
  end

  defp required(field), do: Ash.Error.Changes.Required.exception(field: field, type: :attribute)

  defp policy,
    do: %Ash.Error.Forbidden.Policy{policies: [], facts: %{}, resource: nil, action: :read}

  test "defaults: camel keys, policy redacted, raised hidden" do
    [e] = Errors.to_errors(required(:first_name))
    assert e["shortMessage"] == "Required field"
    [p] = Errors.to_errors(policy())
    assert p["message"] == "forbidden"
    [r] = Errors.to_errors(RuntimeError.exception("secret"))
    refute r["message"] =~ "secret"
  end

  test "show_raised_errors from Config, explicit opt wins" do
    Application.put_env(:ash_surface, :show_raised_errors, true)
    [r] = Errors.to_errors(RuntimeError.exception("secret"))
    assert r["message"] =~ "secret"
    [h] = Errors.to_errors(RuntimeError.exception("secret"), show_raised_errors: false)
    refute h["message"] =~ "secret"
  end

  test "show_policy_breakdowns from Config, explicit opt wins" do
    Application.put_env(:ash_surface, :show_policy_breakdowns, true)
    [p] = Errors.to_errors(policy())
    refute p["message"] == "forbidden"
    [q] = Errors.to_errors(policy(), show_policy_breakdowns: false)
    assert q["message"] == "forbidden"
  end

  test "output_field_formatter from Config, explicit formatter wins" do
    Application.put_env(:ash_surface, :output_field_formatter, :snake_case)
    [e] = Errors.to_errors(required(:x))
    assert e["short_message"] == "Required field"
    [f] = Errors.to_errors(required(:x), formatter: :pascal_case)
    assert f["ShortMessage"] == "Required field"
  end

  test "error_handler from Config runs after resource handler, module and mfa" do
    Application.put_env(:ash_surface, :error_handler, CfgHandler)
    [e] = Errors.to_errors(required(:x))
    assert e["via"] == "config"
    [r] = Errors.to_errors(required(:x), resource: Res)
    assert r["via"] == "config"

    Application.put_env(:ash_surface, :error_handler, {CfgHandler, :handle_error, []})
    [m] = Errors.to_errors(required(:x))
    assert m["via"] == "config"
  end

  test "error_output_formatter module and mfa" do
    Application.put_env(:ash_surface, :error_output_formatter, Out)
    [e] = Errors.to_errors(required(:x))
    assert e["formatted"] == true
    Application.put_env(:ash_surface, :error_output_formatter, {Out, :tag, ["t"]})
    [t] = Errors.to_errors(required(:x))
    assert t["tag"] == "t"
    [o] = Errors.to_errors(required(:x), error_output_formatter: nil)
    refute Map.has_key?(o, "tag")
  end

  test "apply_field_names is pure and mapping wins over formatter" do
    err = %{fields: [:first_name, :other_one], path: [:a_b, 0], vars: %{field: :first_name, n: 1}}
    out = ErrorFormatter.apply_field_names(err, %{first_name: "fname"}, :camel_case)
    assert out == %{fields: ["fname", "otherOne"], path: ["aB", 0], vars: %{field: "fname", n: 1}}

    p =
      ErrorFormatter.apply_field_names(
        %{path: [:first_name, 0]},
        %{first_name: "fname"},
        :camel_case
      )

    assert p == %{path: ["fname", 0]}

    s =
      ErrorFormatter.apply_field_names(
        %{"fields" => ["first_name"]},
        [first_name: :fn],
        :snake_case
      )

    assert s == %{"fields" => ["fn"]}

    assert ErrorFormatter.apply_field_names(err, nil, :snake_case).fields == [
             "first_name",
             "other_one"
           ]

    assert ErrorFormatter.apply_field_names("x", %{}, :camel_case) == "x"
  end
end
