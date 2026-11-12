# The ash TRUTH section (v29): per-action compilation into `AshSurface.IR.Ash`
# with the read-only section renderer. THE one canon for the ash section since
# gapfix-adapters-001 (the resource-enumerating `Compiler.Ash` rival — an
# `AshSurface.IR.Ash` @type violation — is retired; the default pipeline
# bridges here through `AshSurface.Compiler.Section.Ash`). Paired with the
# `AshSurface.Section` behaviour in section.ex.
defmodule AshSurface.Compiler.AshTruth do
  @moduledoc """
  Compiles one public Ash action into `AshSurface.IR.Ash` truth and renders the
  read-only `ash` section.

  Every fact is witnessed on the compiled resource through public introspection:
  admission from `Ash.Resource.Info.public_actions/1`, typed inputs from the
  action's `arguments` (`allow_nil?` becomes required-vs-optional, declared
  defaults are surfaced verbatim), outputs from the action's declared `returns`
  (`nil` for action types that declare none), and policies read-only from
  `Ash.Policy.Info.policies/1`. Presentation facts and semantic guesses are not
  omitted by convention: the section's fact vocabulary is an admitted key set,
  and any key outside it is refused as a fabrication before the section is
  returned.
  """

  @behaviour AshSurface.Section

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.IR

  @section "ash"

  @admitted_section_keys [
    :action,
    :action_type,
    :inputs,
    :outputs,
    :policies,
    :resource,
    :section
  ]
  # Constraint intake law (L01): only these Ash constraint keys are admitted;
  # anything else on the argument is dropped, never guessed.
  @admitted_input_keys [
    :constraints,
    :default,
    :name,
    :required,
    :subtype_constraints,
    :subtype_of,
    :type
  ]

  # The four pre-L01 keys are always present; the three L01 keys are admitted
  # additions (subset law) so bare inputs from other constructors stay lawful.
  @required_input_keys [:default, :name, :required, :type]
  @admitted_output_keys [:returns]
  @admitted_policy_keys [:bypass, :checks, :conditions]

  @doc "Builds the truth IR for one public action of a compiled Ash resource."
  @spec build(module(), atom()) :: {:ok, IR.Ash.t()} | {:error, term()}
  def build(resource, action) when is_atom(resource) and is_atom(action) do
    if Ash.Resource.Info.resource?(resource) do
      public = Ash.Resource.Info.public_actions(resource)

      case Enum.find(public, &(&1.name == action)) do
        nil ->
          {:error, {:unknown_public_action, action, public |> Enum.map(& &1.name) |> Enum.sort()}}

        act ->
          {:ok,
           %IR.Ash{
             resource: resource,
             action: act.name,
             action_type: act.type,
             inputs: inputs(act),
             outputs: outputs(act),
             policies: policies(resource)
           }}
      end
    else
      {:error, {:not_an_ash_resource, resource}}
    end
  end

  def build(resource, _action), do: {:error, {:not_an_ash_resource, resource}}

  @doc """
  Renders the `ash` truth section for a compiled `AshSurface.IR.Ash` node.

  Refuses with `{:error, {:fabricated_fact, kind, keys}}` if any fact outside
  the admitted vocabulary for its kind is present.
  """
  @impl AshSurface.Section
  def section(%IR.Ash{} = node, _opts \\ []) do
    section = %{
      section: @section,
      resource: inspect(node.resource),
      action: node.action,
      action_type: node.action_type,
      inputs: Enum.map(node.inputs, &input_fact/1),
      outputs: output_fact(node.outputs),
      policies: Enum.map(node.policies, &policy_fact/1)
    }

    case verify_truth(section) do
      :ok -> {:ok, section}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  The admitted fact keys of the `ash` section, per nesting level.

  Shared law for compilers and consumers: a key outside these sets is a
  presentation fact or a semantic guess, not truth.
  """
  @spec admitted_keys() :: %{
          section: [atom()],
          input: [atom()],
          output: [atom()],
          policy: [atom()],
          constraint: [atom()]
        }
  def admitted_keys do
    %{
      section: @admitted_section_keys,
      input: @admitted_input_keys,
      output: @admitted_output_keys,
      policy: @admitted_policy_keys,
      constraint: TypeFacts.admitted_constraint_keys()
    }
  end

  defp inputs(act) do
    Enum.map(act.arguments, fn argument ->
      input = %IR.Input{
        name: argument.name,
        type: type_name(argument.type),
        required: not argument.allow_nil?,
        default: argument.default
      }

      # The IR.Input struct extension (constraints/subtype_of/subtype_
      # constraints fields) is owned by a concurrent lane; attach the facts
      # directly once it lands, and until then only when there is real data,
      # so unconstrained inputs stay byte-identical to the v29 emission.
      constraints = admitted_constraints(argument.constraints)
      {subtype_of, subtype_constraints} = subtype_facts(argument.type)

      if Map.has_key?(input, :constraints) or constraints != %{} or subtype_of != nil or
           subtype_constraints != %{} do
        Map.merge(input, %{
          constraints: constraints,
          subtype_of: subtype_of,
          subtype_constraints: subtype_constraints
        })
      else
        input
      end
    end)
  end

  # Fail closed: only admitted constraint keys survive (TypeFacts owns the
  # shared vocabulary: regexes normalized to source + match_flags, nested
  # `items` constraints recursed); nil normalizes to %{}.
  defp admitted_constraints(constraints), do: TypeFacts.constraints(constraints)

  # NewType unwrapping: a non-NewType argument carries no subtype facts. A
  # NewType's own subtype constraints (declared on the type, not the argument)
  # are read through the module introspection NewType compiles in.
  defp subtype_facts(type) do
    if Ash.Type.NewType.new_type?(type) do
      base = Ash.Type.NewType.subtype_of(type)

      own = admitted_constraints(type.constraints())
      declared = admitted_constraints(type.subtype_constraints())

      subtype_constraints = Map.merge(own, declared, fn _k, _own, decl -> decl end)

      {type_name(base), subtype_constraints}
    else
      {nil, %{}}
    end
  end

  defp outputs(act) do
    case Map.get(act, :returns) do
      nil -> nil
      type -> %IR.Output{returns: type_name(type)}
    end
  end

  defp policies(resource) do
    authorizers = Ash.Resource.Info.authorizers(resource)

    if Ash.Policy.Authorizer in authorizers do
      Ash.Policy.Info.policies(resource)
      |> Enum.map(fn policy ->
        %IR.Policy{
          bypass: policy.bypass? == true,
          conditions: Enum.map(policy.condition, &condition_fact/1),
          checks: Enum.map(policy.policies, &check_fact/1)
        }
      end)
    else
      []
    end
  end

  defp condition_fact({module, opts}) do
    %{check: inspect(module), opts: authored_opts(opts)}
  end

  # The authorizer compiler injects an :access_type execution hint into
  # condition opts; it is evaluation machinery, not an authored policy fact.
  defp authored_opts(opts), do: opts |> Keyword.delete(:access_type) |> Map.new()

  defp check_fact(check), do: %{check: inspect(check.check_module), kind: check.type}

  defp type_name(type), do: TypeFacts.type_name(type)

  defp input_fact(%IR.Input{} = input) do
    %{
      name: input.name,
      type: input.type,
      required: input.required,
      default: input.default,
      constraints: Map.get(input, :constraints) || %{},
      subtype_of: Map.get(input, :subtype_of),
      subtype_constraints: Map.get(input, :subtype_constraints) || %{}
    }
  end

  defp output_fact(nil), do: nil

  defp output_fact(%IR.Output{} = output), do: %{returns: output.returns}

  defp policy_fact(%IR.Policy{} = policy) do
    %{bypass: policy.bypass, checks: policy.checks, conditions: policy.conditions}
  end

  defp verify_truth(section) do
    checks = [
      exact_keys(section, @admitted_section_keys, :section),
      input_keys(section.inputs),
      verify_output(section.outputs),
      all_keys(section.policies, @admitted_policy_keys, :policy),
      policy_children(section.policies)
    ]

    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  # Input law (L01): the four v29 keys are required; the three constraint
  # keys are admitted additions (older inputs and mid-migration constructors
  # legitimately omit them); any other key is still a fabrication.
  defp input_keys(inputs) do
    Enum.find_value(inputs, :ok, fn input ->
      actual = input |> Map.keys() |> MapSet.new()
      admitted = MapSet.new(@admitted_input_keys)
      missing = @required_input_keys |> MapSet.new() |> MapSet.difference(actual)
      extra = MapSet.difference(actual, admitted)

      cond do
        MapSet.size(missing) > 0 ->
          {:error, {:fabricated_fact, :input, Enum.sort(missing)}}

        MapSet.size(extra) > 0 ->
          {:error, {:fabricated_fact, :input, Enum.sort(extra)}}

        true ->
          nil
      end
    end)
  end

  defp verify_output(nil), do: :ok
  defp verify_output(output), do: exact_keys(output, @admitted_output_keys, :output)

  defp all_keys(maps, admitted, kind) do
    Enum.find_value(maps, :ok, fn map ->
      case exact_keys(map, admitted, kind) do
        :ok -> nil
        {:error, _reason} = error -> error
      end
    end)
  end

  defp policy_children(policies) do
    checks =
      Enum.flat_map(policies, fn policy ->
        [
          all_keys(policy.conditions, [:check, :opts], :condition),
          all_keys(policy.checks, [:check, :kind], :check)
        ]
      end)

    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp exact_keys(map, admitted, kind) do
    actual = map |> Map.keys() |> Enum.sort()

    if actual == Enum.sort(admitted) do
      :ok
    else
      {:error, {:fabricated_fact, kind, actual}}
    end
  end
end
