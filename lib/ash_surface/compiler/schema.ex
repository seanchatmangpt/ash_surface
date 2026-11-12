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

  alias AshSurface.Compiler.{EmbeddedSchema, ZodType}

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
    resources = Map.get(action, "embedded_resources") || %{}

    with :ok <- validate_arguments(id, args),
         :ok <- validate_returns(id, returns),
         {:ok, zod} <- render_zod(id, args, returns, resources) do
      input = Map.new(args, fn arg -> {arg["name"], Map.delete(arg, "name")} end)

      # Reader-pinned (retired dead-code ledger, gapfix-test-surface-015):
      # the Boundary slice is the canonical v07 shape (compiler/ir.ex),
      # exercised field-complete by
      # test/ash_surface/compiler/schema_section_test.exs. The intended
      # production reader has landed: the orchestrator-facing
      # `AshSurface.Compiler.Section.Schema` adapter (compiler.ex's default
      # binding) mounts these slices into compiled IRs
      # (lib/ash_surface/compiler/section/schema.ex). Retirement is pinned,
      # not silent: test/ash_surface/compiler/boundary_ledger_test.exs fails
      # if that reader disappears.
      slice = %AshSurface.Compiler.IR.Boundary{
        input: input,
        output: returns,
        zod: zod,
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
  defp render_zod(id, args, returns, resources) do
    safe_name = sanitize_identifier(id)

    with {:ok, lines, in_decls} <- input_lines(args, resources),
         {:ok, output, out_decls} <- output_fragment(returns, resources),
         {:ok, decls} <- merge_declarations(in_decls ++ out_decls) do
      {:ok,
       Enum.map_join(decls, "", fn {name, expr} -> "const #{name} = #{expr};\n" end) <>
         """
         export const #{safe_name}_inputSchema = z.object({
         #{Enum.join(lines, ",\n")}
         }).passthrough();

         export const #{safe_name}_outputSchema = #{output};
         """}
    end
  end

  # One named declaration per identifier. The same identifier with a different body (a
  # resource named in one argument's plan but shaped differently in another) is refused
  # typed, never silently shadowed.
  defp merge_declarations(decls) do
    decls
    |> Enum.reduce_while({:ok, %{}}, fn {name, expr}, {:ok, acc} ->
      case Map.fetch(acc, name) do
        {:ok, ^expr} -> {:cont, {:ok, acc}}
        {:ok, _other} -> {:halt, {:error, {:declaration_conflict, name}}}
        :error -> {:cont, {:ok, Map.put(acc, name, expr)}}
      end
    end)
    |> case do
      {:ok, map} -> {:ok, Enum.sort(map)}
      error -> error
    end
  end

  defp input_lines(args, resources) do
    args
    |> Enum.reduce_while({:ok, [], []}, fn arg, {:ok, acc, decls} ->
      case zod_fragment(arg, resources) do
        {:ok, fragment, d} ->
          {:cont, {:ok, ["  #{zod_key(arg["name"])}: #{fragment}" | acc], decls ++ d}}

        {:error, reason} ->
          {:halt, {:error, {:schema_build_failed, arg["name"], reason}}}
      end
    end)
    |> case do
      {:ok, lines, decls} -> {:ok, Enum.reverse(lines), decls}
      error -> error
    end
  end

  defp output_fragment(nil, _resources), do: {:ok, "z.undefined()", []}
  defp output_fragment(returns, resources), do: zod_fragment(returns, resources)

  # Structured containers (embedded resources, typed structs/maps, unions,
  # arrays of containers) route to EmbeddedSchema.render_program (exact named
  # recursion, F1-refs/KD-02); scalars use the shared ZodType table. A renderer
  # refusal (cyclic_schema, union depth, invalid member) is returned typed -
  # never a silent z.unknown.
  defp zod_fragment(definition, resources) do
    if EmbeddedSchema.container?(definition) do
      with {:ok, %{declarations: decls, expression: expr}} <-
             EmbeddedSchema.render_program(definition, resources: resources),
           do: {:ok, expr, decls}
    else
      {:ok, ZodType.fragment(definition), []}
    end
  end

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

  # An input field named like an Elixir predicate (`default?`) is not a bare
  # JS identifier, so it is emitted as a quoted object key — the ZodGuard
  # admits `key := name | string`.
  defp zod_key(name) do
    if Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, name),
      do: name,
      else: Jason.encode!(name)
  end

  defp sanitize_identifier(id) do
    String.replace(id, ~r/[^a-zA-Z0-9_]/, "_")
  end
end
