# Claim-vs-code correction (gapfix-test-surface-015): this header previously
# claimed this file declares, locally, the canonical compiler-section
# behaviour and the canonical compiler IR. Both claims were stale and are
# RETRACTED: the Section behaviour lives in lib/ash_surface/compiler.ex
# (lib/ash_surface/compiler/section.ex never existed — correction detail per
# gapfix-docs-truth-013) and the canonical IR slices (including IR.Boundary,
# this section's output shape) in lib/ash_surface/compiler/ir.ex. This file's
# local duplicates were dropped at integration; it declares only
# `AshSurface.Compiler.Schema`.

defmodule AshSurface.Compiler.Schema do
  @moduledoc """
  The schema section: shared-manufacture of input/output descriptions and
  their zod projection (AshTypescript pattern).

  `build/2` consumes the SAME discovery the ash section produces — action
  argument and return descriptions — as given. It performs no discovery of
  its own: no Ash resource introspection, no manifest regeneration — so
  upstream semantics enter this section exactly once (the no-second-discovery
  contract is enforced by a source scan in this section's test).

  Discovery shape (string-keyed, matching the serialized manifest idioms):

      %{
        "actions" => [
          %{
            "id" => "Resource#action",
            "arguments" => [
              %{"name" => "f", "type" => %{"kind" => "string"}, "allow_nil?" => false}
            ],
            "returns" => %{"type" => %{"kind" => "uuid"}} | nil
          }
        ]
      }

  Returns `{:ok, ir, meta}` where `ir` maps each action id to an
  `AshSurface.Compiler.IR.Boundary` (claimed as `IR.Schema` before the v50
  rename — corrected in gapfix-test-surface-015) and `meta` carries the
  section counts.
  """

  # The established zod mapping table. This mirrors
  # AshSurface.Projector.Expo.map_zod_type/1 exactly; drift between the two
  # is a contract break, not a local choice.
  @zod_kinds %{
    "string" => "z.string()",
    "integer" => "z.number().int()",
    "boolean" => "z.boolean()",
    "uuid" => "z.string().uuid()",
    "float" => "z.number()",
    "decimal" => "z.number()",
    "utc_datetime" => "z.string()",
    "datetime" => "z.string()",
    "map" => "z.record(z.string(), z.unknown())",
    "array" => "z.array(z.unknown())"
  }

  @spec build(term(), term()) ::
          {:ok, %{optional(String.t()) => AshSurface.Compiler.IR.Boundary.t()},
           %{action_count: non_neg_integer(), argument_count: non_neg_integer()}}
          | {:error, term()}
  def build(discovery, _opts \\ [])

  def build(discovery, _opts) when is_map(discovery) do
    with {:ok, actions} <- actions_from(discovery) do
      compile(actions)
    end
  end

  def build(_discovery, _opts), do: {:error, :discovery_must_be_a_map}

  defp actions_from(discovery) do
    case Map.get(discovery, "actions", []) do
      actions when is_list(actions) ->
        Enum.reduce_while(actions, {:ok, []}, fn action, {:ok, acc} ->
          case action do
            %{"id" => id} when is_binary(id) ->
              {:cont, {:ok, [action | acc]}}

            other ->
              {:halt, {:error, {:action_without_id, other}}}
          end
        end)
        |> case do
          {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
          error -> error
        end

      other ->
        {:error, {:actions_must_be_a_list, other}}
    end
  end

  defp compile(actions) do
    actions
    |> Enum.sort_by(& &1["id"])
    |> Enum.reduce_while({:ok, %{}, 0}, fn action, {:ok, ir, arg_count} ->
      case schema_ir(action) do
        {:ok, id, slice, count} ->
          {:cont, {:ok, Map.put(ir, id, slice), arg_count + count}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, ir, arg_count} ->
        {:ok, ir, %{action_count: map_size(ir), argument_count: arg_count}}

      error ->
        error
    end
  end

  defp schema_ir(action) do
    id = action["id"]
    args = Map.get(action, "arguments", [])
    returns = Map.get(action, "returns")

    with :ok <- validate_arguments(id, args),
         :ok <- validate_returns(id, returns) do
      input = Map.new(args, fn arg -> {arg["name"], Map.delete(arg, "name")} end)

      # Dead-code ledger (gapfix-test-surface-015): the Boundary slice is the
      # canonical v07 shape (compiler/ir.ex), exercised field-complete by
      # test/ash_surface/compiler/schema_section_test.exs, but it has no
      # PRODUCTION reader yet — the intended reader is the orchestrator-facing
      # `AshSurface.Compiler.Section.Schema` adapter (compiler.ex's default
      # binding) that will mount these slices into compiled IRs. The pending
      # state is pinned, not silent:
      # test/ash_surface/compiler/boundary_ledger_test.exs fails when that
      # adapter lands, forcing this ledger row to be re-pointed.
      slice = %AshSurface.Compiler.IR.Boundary{
        input: input,
        output: returns,
        zod: render_zod(id, args, returns),
        aria: render_aria(id, args)
      }

      {:ok, id, slice, length(args)}
    end
  end

  defp validate_arguments(id, args) when is_list(args) do
    if Enum.all?(args, &valid_argument?/1) do
      :ok
    else
      {:error, {:argument_without_name, id}}
    end
  end

  defp validate_arguments(id, other), do: {:error, {:arguments_must_be_a_list, id, other}}

  defp valid_argument?(%{"name" => name}) when is_binary(name), do: true
  defp valid_argument?(_), do: false

  defp validate_returns(_id, nil), do: :ok
  defp validate_returns(_id, returns) when is_map(returns), do: :ok
  defp validate_returns(id, other), do: {:error, {:invalid_returns, id, other}}

  # Mirrors AshSurface.Projector.Expo's emission: sanitized identifiers,
  # z.object({ ... }).passthrough() input blocks with two-space-indented
  # `name: fragment` lines, paired with an output schema binding.
  defp render_zod(id, args, returns) do
    safe_name = sanitize_identifier(id)

    input_fields =
      Enum.map_join(args, ",\n", fn arg ->
        "  #{arg["name"]}: #{zod_fragment(arg)}"
      end)

    """
    export const #{safe_name}_inputSchema = z.object({
    #{input_fields}
    }).passthrough();

    export const #{safe_name}_outputSchema = #{output_fragment(returns)};
    """
  end

  defp output_fragment(nil), do: "z.undefined()"

  defp output_fragment(returns), do: zod_fragment(returns)

  # Byte-mirror of AshSurface.Projector.Expo.map_zod_type/1.
  defp zod_fragment(%{"type" => %{"kind" => kind}} = definition) do
    base = Map.get(@zod_kinds, kind, "z.unknown()")

    if definition["allow_nil?"] == true do
      "#{base}.optional().nullable()"
    else
      base
    end
  end

  defp zod_fragment(_), do: "z.unknown().optional()"

  defp render_aria(id, args) do
    %{
      "actionId" => id,
      "label" => humanize(id),
      "fields" =>
        Enum.map(args, fn arg ->
          %{
            "name" => arg["name"],
            "label" => humanize(arg["name"]),
            "required" => arg["allow_nil?"] != true
          }
        end)
    }
  end

  defp humanize(value) do
    value
    |> String.replace(~r/[^a-zA-Z0-9]+/, " ")
    |> String.trim()
    |> String.capitalize()
  end

  defp sanitize_identifier(id) do
    String.replace(id, ~r/[^a-zA-Z0-9_]/, "_")
  end
end
