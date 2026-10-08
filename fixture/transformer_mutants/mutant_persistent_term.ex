# MUTANT (Lane C3, fixture/transformer_mutants/): reads hidden :persistent_term
# config into the persisted state. The transformer closure court MUST fail
# against this transformer -- determinism and parity both, and the hidden-state
# audit must name this line:
defmodule CourtProbe.Mutant.PersistentTerm do
  @moduledoc "MUTANT: derives persisted state from hidden :persistent_term config."
  use Spark.Dsl.Transformer

  @impl true
  def after?(_), do: false

  @impl true
  def transform(dsl_state) do
    hidden = :persistent_term.get({:court_probe, :hidden_mode}, :alpha)
    steps = Enum.map(Spark.Dsl.Transformer.get_entities(dsl_state, [:pipeline]), &%{name: &1.name, via: &1.via})
    compiled = %{mode: hidden, steps: steps}
    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :court_probe_compiled, compiled)}
  end
end
