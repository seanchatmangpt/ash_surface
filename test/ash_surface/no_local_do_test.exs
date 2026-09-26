defmodule AshSurface.NoLocalDoTest do
  @moduledoc """
  CHICAGO ADVERSARIAL tripwires for the v26.9.16 invariant, as executable law:

      "AshSurface does not determine whether it may DO."

  The surface (lib/ash_surface/**/*.ex) is a read/observe/select/construct
  layer. Whether a DO may happen is NEVER decided here: it is a delegated
  fact (v26.9.16) read through `AshSurface.IR.Capability.authority_required`,
  never re-derived locally (the v10 `do_authority` derivation is dead law),
  and the surface never executes resource actions itself — no direct Ash
  create/update/destroy/calculate on resources, no Process/Task execution of
  actions.

  METHOD: every file under lib/ash_surface/**/*.ex plus the root
  lib/ash_surface.ex envelope is walked in-test via File.read!/1 +
  Code.string_to_quoted!/1 (raw source AND AST), so the invariant is checked
  against the tree as it is, not a cached list. Each
  test below is a falsifier that survived adversarial construction; each
  surviving falsifier is kept as a permanent tripwire, and its comment names
  the invariant clause it guards.

  ALLOWLIST (per the invariant's contract): the intent dispatch's injected
  bus, test fixtures (AshSurface.Fixtures.*), IR.Capability reads, and the
  surface's own in-memory projection constructors (AshSurface.Event /
  Observation / PlanningEpisode — structs, never resource mutations).

  SCOPE: the walk is lib/ash_surface/**/*.ex PLUS the root lib/ash_surface.ex
  envelope, pinned explicitly (the recursive glob cannot reach lib/). The
  envelope is delegation-clean at HEAD: c6744cb (v26.9.16 delegated facts) is
  an ancestor of it, and `surface_envelope/2` reads semanticId,
  authorityBoundary, doAuthority, and receiptRequired through
  `AshSurface.IR.delegated/2` — nil when not delegated, never re-derived. An
  earlier revision of this note excused the envelope as "travelling on the
  v26.9.16 branch (c6744cb)"; that exclusion was stale and is removed. The
  envelope is law under this walk like any other surface file.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  # The root envelope lives in lib/, not lib/ash_surface/, so the recursive
  # glob cannot reach it; it is pinned explicitly and sorted into the walk.
  @root_envelope Path.join(@repo_root, "lib/ash_surface.ex")

  @files Enum.sort([
           @root_envelope | Path.wildcard(Path.join(@repo_root, "lib/ash_surface/**/*.ex"))
         ])

  # INVARIANT 1 — direct Ash mutation/authority calls. These function names on
  # a non-allowlisted module mean "executed (or asked Ash to bless) a
  # resource action".
  @action_funs [
    :create,
    :update,
    :destroy,
    :calculate,
    :bulk_create,
    :bulk_update,
    :bulk_destroy,
    :run_action,
    :execute_action
  ]

  # v26.9.16 delegated facts: an absent key == "not delegated" == null. A
  # local default for any of them is a re-derivation of authority, not a read.
  @delegated_fact_keys ["semanticId", "authorityBoundary", "doAuthority", "receiptRequired"]

  # INVARIANT 3 — the v10 `do_authority` local binding/derivation must never
  # reappear; DO-ness is read, never computed, on the surface.
  @do_authority_identifier :do_authority

  # INVARIANT 4 — capability gating is owned by IR.Capability; these gate
  # names defined anywhere on the surface are local authority determinations.
  # finish-tripwires-024 closed the ?-suffix hole: the list pinned only the
  # bare owner name `authority_required`, so a surface file could define the
  # predicate twin `authority_required?/1` and escape (witnessed near-miss:
  # Projector.VoiceKiosk defined a local `authority_required?/1` at
  # voice_kiosk.ex:62). Every bare gate name now also pins its ?-suffixed
  # twin; `?` is not a spelling escape hatch.
  @gate_fun_names [
    :can_do?,
    :may_do?,
    :authorized?,
    :authorised?,
    :has_do_authority?,
    :capability?,
    :gate_authority,
    :gate_authority?,
    :authority_required,
    :authority_required?
  ]

  # INVARIANT 2 — process execution of actions: Task.* wholesale, and the
  # Process/Kernel/:erlang spawn-and-signal family.
  @process_funs [
    :spawn,
    :spawn_link,
    :spawn_monitor,
    :spawn_opt,
    :send,
    :send_after,
    :exit,
    :hibernate
  ]

  # Surface-owned in-memory projection constructors: these build structs, they
  # never touch an Ash resource. Lawful targets for create/2,4 etc.
  @projection_constructors [
    [:AshSurface, :Event],
    [:AshSurface, :Observation],
    [:AshSurface, :PlanningEpisode],
    # v26.9.21 ZOE human-surface family (ASF-26922-04): plain in-memory struct
    # constructors (def create/2..4 returning %__MODULE__{}), never resource
    # mutations — the same admitted class as Event/Observation/PlanningEpisode.
    [:AshSurface, :HumanSurface],
    [:AshSurface, :PersonalizationContext],
    [:AshSurface, :Possibility],
    [:AshSurface, :PossibilitySet],
    [:AshSurface, :CommitmentBoundary],
    [:AshSurface, :DevotionalEpisode],
    [:AshSurface, :Journey],
    [:AshSurface, :ManufactureTrace],
    [:AshSurface, :OutcomeHypothesis],
    [:AshSurface, :WhyThis],
    # zoe_demo.ex aliases these AshSurface.* modules to bare names; the walk's
    # resolve_module/1 does not expand aliases, so admit the bare forms too.
    [:HumanSurface],
    [:PersonalizationContext],
    [:Possibility],
    [:PossibilitySet],
    [:CommitmentBoundary],
    [:DevotionalEpisode],
    [:Journey],
    [:ManufactureTrace],
    [:OutcomeHypothesis],
    [:WhyThis],
    [:Event],
    [:Observation],
    [:PlanningEpisode]
  ]

  # -------------------------------------------------------------------------
  # AST plumbing. remote_calls/1 yields {module, fun, args} for every remote
  # call (dot-form and legacy form) and {module, fun, arity} for captures;
  # bare_calls/1 yields {fun, args} for module-less Kernel-style calls.
  # -------------------------------------------------------------------------

  defp resolve_module({:__aliases__, _, parts}), do: Enum.map(parts, &unwrap_alias/1)
  defp resolve_module(atom) when is_atom(atom) and not is_nil(atom), do: [atom]
  defp resolve_module({name, _, nil}) when is_atom(name), do: {:var, name}
  defp resolve_module(_), do: :unresolvable

  defp unwrap_alias({:__aliases__, _, parts}), do: Enum.map(parts, &unwrap_alias/1)
  defp unwrap_alias(atom) when is_atom(atom), do: atom
  defp unwrap_alias(other), do: other

  defp remote_calls(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        # Captures first: &Mod.fun/arity must be recorded before the generic
        # call clause can swallow the {:&, _, [{:/, ...}]} node.
        {:&, _, [{:/, _, [mod, fun]}]} = node, acc when is_atom(fun) ->
          {node, [{resolve_module(mod), fun, :capture} | acc]}

        {{:., _, [mod, fun]}, _meta, args} = node, acc when is_atom(fun) and is_list(args) ->
          {node, [{resolve_module(mod), fun, args} | acc]}

        {fun, _meta, [mod | args]} = node, acc when is_atom(fun) ->
          case mod do
            {:__aliases__, _, _} -> {node, [{resolve_module(mod), fun, args} | acc]}
            m when is_atom(m) -> {node, [{resolve_module(m), fun, args} | acc]}
            _ -> {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(acc)
  end

  defp bare_calls(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {fun, _meta, args} = node, acc when is_atom(fun) and is_list(args) ->
          {node, [{fun, args} | acc]}

        node, acc ->
          {node, acc}
      end)

    acc
  end

  defp module_label({:var, name}), do: "variable #{inspect(name)}"
  defp module_label(:unresolvable), do: "unresolvable module"
  defp module_label(parts) when is_list(parts), do: Enum.map_join(parts, ".", &to_string/1)

  defp bus_allowed?({:var, name}), do: String.contains?(to_string(name), "bus")

  defp bus_allowed?(parts) when is_list(parts) do
    Enum.any?(parts, fn part ->
      String.contains?(to_string(part), ["Bus", "bus"])
    end)
  end

  defp bus_allowed?(_), do: false

  defp fixtures_allowed?(parts) when is_list(parts), do: :Fixtures in parts
  defp fixtures_allowed?(_), do: false

  defp ir_capability_read?(parts) when is_list(parts) do
    parts |> Enum.reverse() |> Enum.take(2) == [:Capability, :IR]
  end

  defp ir_capability_read?(_), do: false

  defp projection_constructor?(parts) when is_list(parts), do: parts in @projection_constructors
  defp projection_constructor?(_), do: false

  defp ash_framework_call?(mod, fun) do
    case mod do
      [:Ash] ->
        fun in @action_funs or fun in [:can, :can?, :authorize, :authorize?]

      [:Ash | rest] ->
        (rest == [:Changeset] and fun in [:for_action, :for_create, :for_update, :for_destroy]) or
          (rest == [:Query] and fun in [:for_read, :calculate, :calculate_filter]) or
          rest == [:Actions]

      _ ->
        false
    end
  end

  defp action_call_allowed?(mod, _fun) do
    data_structure_module?(mod) or bus_allowed?(mod) or fixtures_allowed?(mod) or
      ir_capability_read?(mod) or projection_constructor?(mod)
  end

  # Stdlib data-structure modules: `Keyword.update/3` mutates a keyword list,
  # never an Ash resource — an Ash Api/Domain cannot be aliased onto these.
  defp data_structure_module?(mod) when is_list(mod),
    do: mod in [[:Keyword], [:Map], [:MapSet], [:Access]]

  defp data_structure_module?(_), do: false

  defp read_sources! do
    for path <- @files do
      source = File.read!(path)
      ast = Code.string_to_quoted!(source)
      {path, source, ast}
    end
  end

  defp rel(path), do: Path.relative_to(path, @repo_root)

  # -------------------------------------------------------------------------
  # TRIPWIRES — every test's comment names the invariant clause it guards.
  # -------------------------------------------------------------------------

  test "walk is real: lib/ash_surface/**/*.ex is non-empty and every file parses" do
    # GUARDS THE METHOD: a walk over an empty or stale glob is a silently
    # disabled invariant; truncation is evidence, never permission.
    assert length(@files) >= 8,
           "surface walk shrank to #{length(@files)} files — invariant unenforced"

    # The root envelope must be under the walk: a stale exclusion note once
    # kept it outside; that exclusion was falsified (c6744cb is an ancestor of
    # HEAD) and must never silently reappear.
    assert @root_envelope in @files and File.regular?(@root_envelope),
           "root envelope lib/ash_surface.ex is missing from the walk — " <>
             "the invariant is unenforced over the envelope"

    for {path, _source, ast} <- read_sources!() do
      assert is_tuple(ast), "#{rel(path)} did not produce an AST"
    end
  end

  test "TRIPWIRE no-local-DO: no module calls Ash create/update/destroy/calculate directly on resources" do
    # INVARIANT v26.9.16 (first half): AshSurface does not determine whether it
    # may DO. Any action-named call to a non-allowlisted module (allowlist:
    # intent dispatch's injected bus, test fixtures, IR.Capability reads,
    # surface projection constructors) is the surface acting, not describing.
    # Ash framework action/authorization entry points (Ash.create, Ash.can?,
    # Ash.Changeset.for_create, Ash.Query.for_read, Ash.Actions.*) trip
    # unconditionally — no allowlist can bless them.
    violations =
      for {path, _source, ast} <- read_sources!(),
          {mod, fun, _args} <- remote_calls(ast),
          ash_framework_call?(mod, fun) or
            (fun in @action_funs and not action_call_allowed?(mod, fun)) do
        "#{rel(path)}: #{module_label(mod)}.#{fun} — action-named call outside the allowlist"
      end
      |> Enum.uniq()

    assert violations == [],
           """
           AshSurface executed (or reached for) a resource action directly.
           Falsifiers survived:
           #{Enum.map_join(violations, "\n", &"  - #{&1}")}
           """
  end

  test "TRIPWIRE no Process/Task execution of actions anywhere on the surface" do
    # INVARIANT: the surface may describe a DO, never become one by laundering
    # it through a process or dynamic dispatch. Task.* wholesale;
    # Process/Kernel/:erlang spawn, signal and exit family; bare Kernel
    # spawn/send calls; apply/3 — all trip.
    violations =
      for {path, _source, ast} <- read_sources!() do
        remote =
          for {mod, fun, _args} <- remote_calls(ast), process_call_violation?(mod, fun) do
            "#{module_label(mod)}.#{fun}"
          end

        bare =
          for {fun, _args} <- bare_calls(ast), fun in @process_funs or fun == :apply do
            "Kernel-style #{fun}"
          end

        case remote ++ bare do
          [] -> []
          found -> "#{rel(path)}: #{Enum.join(found, ", ")}"
        end
      end

    violations = Enum.reject(violations, &(&1 == []))

    assert violations == [],
           """
           AshSurface spawned/signalled to execute an action out-of-band.
           Falsifiers survived:
           #{Enum.map_join(violations, "\n", &"  - #{&1}")}
           """
  end

  defp process_call_violation?(mod, fun) do
    mod == [:Task] or mod == [:Task, :Supervisor] or
      ((mod == [:Process] or mod == [:Kernel] or mod == [:erlang]) and fun in @process_funs)
  end

  test "TRIPWIRE v10 grep guard: the do_authority derivation does not reappear" do
    # INVARIANT: DO-ness is a delegated fact (v26.9.16). The v10-era local
    # binding `do_authority`, and any defaulted read of a delegated fact
    # (absent key == not delegated == null), are re-derivations, forbidden.
    for {path, source, ast} <- read_sources!() do
      file = rel(path)
      clause = "v26.9.16 invariant: #{file} must READ delegated facts, never derive DO authority"

      refute source =~ to_string(@do_authority_identifier),
             "#{file}: local `do_authority` reappeared — #{clause}"

      refute ast_mentions?(ast, @do_authority_identifier),
             "#{file}: `do_authority` binding in AST — #{clause}"

      defaulted =
        for {mod, :get, args} <- remote_calls(ast), defaulted_delegated_fact?(mod, args) do
          "#{module_label(mod)}.get(…, delegated_fact, default)"
        end

      assert defaulted == [],
             "#{file}: defaulted delegated-fact read — #{clause}\n  #{Enum.join(defaulted, "\n  ")}"
    end
  end

  defp ast_mentions?(ast, identifier) do
    Macro.prewalk(ast, false, fn
      {^identifier, _, _} = node, _acc -> {node, true}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end

  # Map.get/3 (map, delegated-fact key, default): the default argument is a
  # local re-derivation of a delegated authority fact.
  defp defaulted_delegated_fact?(mod, args) when is_list(args) do
    mod == [:Map] and
      case args do
        [_, key, _default] when is_binary(key) -> key in @delegated_fact_keys
        _ -> false
      end
  end

  defp defaulted_delegated_fact?(_mod, _arity), do: false

  test "TRIPWIRE capability gating flows only through IR.Capability.authority_required reads" do
    # INVARIANT v26.9.16 (second half): whether it may DO is IR.Capability's
    # verdict. No surface module may define a gate — bare or ?-suffixed
    # (finish-tripwires-024) — or call authority_required anywhere except
    # IR.Capability. The owner itself
    # (lib/ash_surface/ir/capability.ex => AshSurface.IR.Capability) is exempt
    # for its own gate name in both spellings: it defines; the surface only
    # reads.
    violations =
      for {path, _source, ast} <- read_sources!(),
          module_name = surface_module(path) do
        gate_defs =
          for {kind, _, [{name, _, _}, _]} = def_node <- function_defs(ast),
              name in @gate_fun_names,
              not (module_name == AshSurface.IR.Capability and
                     name in [:authority_required, :authority_required?]) do
            "#{kind} #{name}/#{arity_of(def_node)}"
          end

        bad_reads =
          for {mod, :authority_required, _args} <- remote_calls(ast),
              not ir_capability_read?(mod) do
            "#{module_label(mod)}.authority_required"
          end

        case Enum.uniq(gate_defs ++ bad_reads) do
          [] -> []
          found -> "#{rel(path)}: #{Enum.join(found, ", ")}"
        end
      end

    violations = Enum.reject(violations, &(&1 == []))

    assert violations == [],
           """
           AshSurface decided capability locally instead of reading IR.Capability.
           Falsifiers survived:
           #{Enum.map_join(violations, "\n", &"  - #{&1}")}
           """
  end

  defp function_defs(ast) do
    {_, acc} =
      Macro.prewalk(ast, [], fn
        {:def, _, _} = node, acc -> {node, [node | acc]}
        {:defp, _, _} = node, acc -> {node, [node | acc]}
        node, acc -> {node, acc}
      end)

    acc
  end

  defp arity_of({_, _, [{_, _, args}, _]}) when is_list(args), do: length(args)
  defp arity_of({_, _, [{_, _, _}, _]}), do: 0

  # Filesystem acronym convention: `Macro.camelize/1` maps "ir" to "Ir",
  # which can never equal the real module atom `AshSurface.IR.Capability`;
  # without this map the owner exemption is unsatisfiable by construction.
  # Detection logic is untouched — this only repairs the exemption the
  # tripwire's own comment promises ("lib/ash_surface/ir/capability.ex =>
  # AshSurface.IR.Capability"). The path base is lib/ash_surface (the module
  # tree below the AshSurface prefix), not lib.
  @path_acronyms %{"ir" => "IR"}

  defp surface_module(path) do
    if path == @root_envelope do
      # The envelope IS the AshSurface module itself; it cannot be expressed
      # relative to the lib/ash_surface base below.
      AshSurface
    else
      rel = Path.relative_to(path, Path.join([@repo_root, "lib", "ash_surface"]))

      parts =
        rel
        |> Path.rootname()
        |> String.split("/")
        |> Enum.map(&Map.get(@path_acronyms, &1, &1))
        |> Enum.map(&Macro.camelize/1)

      Module.concat([AshSurface | parts])
    end
  end
end
