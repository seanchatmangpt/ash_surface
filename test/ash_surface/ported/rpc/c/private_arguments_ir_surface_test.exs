defmodule AshSurface.Ported.Rpc.C.PrivateArgumentsIrSurfaceTest do
  @moduledoc """
  Adaptation of the reference private_arguments tests that assert private (`public?: false`)
  action arguments are excluded from generated TypeScript text. ash_surface generates no `.ts`;
  the counterpart surfaces are the compiled IR of the real `OrgTodo` fixture:

    * TypeScript input type  -> `ir.schema.input` (argument map keyed by snake_case name)
    * Zod schema             -> `ir.schema.zod` (input schema source)
    * validation error type  -> `ir.schema.validation_error` (camelCase client keys)

  Each case asserts the private argument is absent and a public argument of the same action is
  present (so the absence is not vacuous). Real manifest + real compiler, no mocks.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.OrgTodo

  # The validation error schema keys follow the output formatter in force at compile time, so the
  # public names are asserted per formatter (the `irs` above are the identity-formatter pin).
  @formatters %{
    camel: :camel_case,
    snake: :snake_case,
    pascal: :pascal_case,
    custom: {__MODULE__.Upcase, :fmt}
  }

  defmodule Upcase do
    def fmt(name), do: "X_" <> String.upcase(to_string(name))
  end

  setup_all do
    Application.put_env(:ash_surface_gu10, :ash_domains, [AshSurface.Ported.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_gu10)

    {:ok, irs} =
      AshSurface.Ported.AshNames.with_verbatim(fn -> AshSurface.Compiler.compile(manifest) end)

    irs = if is_map(irs), do: Map.values(irs), else: irs

    compile_with = fn formatter ->
      {:ok, out} =
        AshSurface.FieldName.with_formatter(formatter, fn ->
          AshSurface.Compiler.compile(manifest)
        end)

      if is_map(out), do: Map.values(out), else: out
    end

    by_formatter =
      Map.new(@formatters, fn {name, formatter} -> {name, compile_with.(formatter)} end)

    %{irs: irs, by_formatter: by_formatter}
  end

  defp schema(irs, action) do
    ir = Enum.find(irs, &(&1.ash.resource == OrgTodo and &1.ash.action == action))
    assert ir, "no IR for OrgTodo #{action}"
    ir.schema
  end

  defp camel(snake) do
    [first | rest] = String.split(snake, "_")
    first <> Enum.map_join(rest, &String.capitalize/1)
  end

  # {action, private argument, public arguments}
  @cases [
    create: {"internal_tracking_id", ["auto_complete", "user_id"]},
    read: {"internal_audit_mode", ["filter_completed"]},
    set_priority: {"bypass_validation", ["priority"]},
    search: {"debug_mode", ["query"]}
  ]

  @labels %{
    create: "create",
    read: "read",
    set_priority: "update",
    search: "generic"
  }

  for {action, {private, publics}} <- @cases do
    label = @labels[action]

    test "#{label} action private argument is excluded from input type", %{irs: irs} do
      input = schema(irs, unquote(action)).input
      refute Map.has_key?(input, unquote(private))

      for pub <- unquote(publics), do: assert(Map.has_key?(input, pub))
    end

    test "#{label} action private argument is excluded from Zod schema", %{irs: irs} do
      zod = schema(irs, unquote(action)).zod
      refute zod =~ unquote(private)

      for pub <- unquote(publics), do: assert(zod =~ pub)
    end
  end

  for action <- [:create, :read, :search], {fname, _} <- @formatters do
    {private, publics} = Keyword.fetch!(@cases, action)
    label = @labels[action]

    test "#{label} action private argument is excluded from validation error schema (#{fname})",
         %{by_formatter: by_formatter} do
      formatter = Map.fetch!(@formatters, unquote(fname))

      error_schema =
        schema(Map.fetch!(by_formatter, unquote(fname)), unquote(action)).validation_error

      private_name = AshSurface.FieldName.compute(unquote(private), formatter)

      # the formatted private name, the snake name and the camel name are all absent
      refute error_schema =~ private_name
      refute error_schema =~ unquote(private)
      refute error_schema =~ camel(unquote(private))

      for pub <- unquote(publics) do
        formatted = AshSurface.FieldName.compute(pub, formatter)
        assert error_schema =~ formatted <> ": z.array(z.string()).optional()"
      end
    end
  end

  test "validation error keys are the exact formatted public names (camel vs snake vs pascal)",
       %{by_formatter: bf} do
    assert schema(bf.camel, :read).validation_error =~ "filterCompleted: z.array"
    assert schema(bf.snake, :read).validation_error =~ "filter_completed: z.array"
    assert schema(bf.pascal, :read).validation_error =~ "FilterCompleted: z.array"
    assert schema(bf.custom, :read).validation_error =~ "X_FILTER_COMPLETED: z.array"
    refute schema(bf.camel, :read).validation_error =~ "filter_completed"
    refute schema(bf.pascal, :read).validation_error =~ "filterCompleted"
  end
end
