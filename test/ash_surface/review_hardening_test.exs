defmodule AshSurface.ReviewHardeningTest do
  @moduledoc """
  Pins the defects an independent adversarial review of the hardening PR found
  in the Elixir production code (each reproduced before the fix):

    * `EventProjection.from_receipt/2` binds only the exact 64-byte digest
      shape; git SHAs, UUIDs and long IRIs are opaque references, not digest
      claims (a broader heuristic wrongly refused them);
    * `Projectors.JS.project_ir/2` refuses a non-string descriptor field or a
      non-string `:prefix` typed instead of raising mid-render;
    * `from_manifest/2` refuses an improper list in the profile typed;
    * `MXEpisode.verify_file/2` validates `:timeout` before opening the
      verifier port (no orphaned process);
    * the ARIA projector treats `"fields"` as the compiler's list form only
      when it is a list - a name-keyed input called `fields` stays an input.

  State-based: real modules, real returns.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.MXEpisode
  alias AshSurface.Projectors.{ARIA, JS}

  defp ir(overrides \\ %{}) do
    %IR{
      ash: %{
        resource: Some.Domain.Todo,
        action: :create,
        action_type: :create,
        policies: []
      },
      presentation: struct(IR.Presentation, Map.get(overrides, :presentation, %{})),
      schema: %IR.Schema{
        zod: "z.object({ title: z.string() })",
        input: %{},
        output: %{},
        aria: Map.get(overrides, :aria)
      }
    }
  end

  describe "JS projector: non-string fields are typed refusals" do
    test "a decoded label or capability IRI of the wrong type refuses, never raises" do
      assert {:error, {:unadmitted_field, _id, :label}} =
               JS.project_ir(ir(%{presentation: %{label: 5}}))

      assert {:error, {:unadmitted_field, _id, :label}} =
               JS.project_ir(ir(%{presentation: %{label: :foo}}))
    end

    test "a non-string or empty :prefix refuses, never raises" do
      for bad <- [:abc, 5, "", nil] do
        assert JS.project_ir(ir(), prefix: bad) == {:error, {:invalid_prefix, bad}}
      end
    end

    test "well-typed IR still projects" do
      assert {:ok, %{"ash_surface_client.mjs" => code}, _meta} = JS.project_ir(ir())
      assert code =~ "Todo"
    end
  end

  describe "from_manifest/2: improper lists are not JSON data" do
    test "an improper list anywhere in the profile is a typed refusal" do
      manifest = %Ash.Info.Manifest{entrypoints: []}

      assert {:error, {:profile_value_not_serializable, [1 | 2]}} =
               AshSurface.from_manifest(manifest, profile: %{"a" => [1 | 2]})

      assert {:error, {:profile_value_not_serializable, [1, 2 | 3]}} =
               AshSurface.from_manifest(manifest, profile: %{"a" => %{"b" => [1, 2 | 3]}})
    end
  end

  describe "MXEpisode.verify_file/2 validates :timeout before spawning" do
    test "a non-integer or negative timeout is refused and no verifier runs" do
      for bad <- [:infinity, -1, 1.5, "10", nil] do
        assert MXEpisode.verify_file("/nonexistent/episode.json", timeout: bad) ==
                 {:error, {:invalid_verifier_timeout, bad}}
      end
    end
  end

  describe "ARIA: \"fields\" is the list form only when it is a list" do
    test "the compiler's list-form carrier yields the inputs" do
      contract =
        ir(%{
          aria: %{"fields" => [%{"name" => "title", "required" => true, "role" => "textbox"}]}
        })
        |> ARIA.project_ir()

      assert {:ok, %{"surfaces" => [%{"inputs" => [%{"name" => "title", "required" => true}]}]},
              _} = contract
    end

    test "a name-keyed input literally called fields stays an input" do
      assert {:ok, %{"surfaces" => [%{"inputs" => inputs}]}, _} =
               ir(%{aria: %{"fields" => %{"role" => "textbox", "required" => true}}})
               |> ARIA.project_ir()

      assert [%{"name" => "fields", "role" => "textbox", "required" => true}] = inputs
    end
  end
end
