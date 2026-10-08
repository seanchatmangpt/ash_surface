defmodule AshSurface.ProjectorsCoverageTest do
  @moduledoc """
  Chicago state tests for the edge laws of the target projectors and the IR
  readers they share.

  Laws pinned here:

    * **IREntry reads, never infers**: a non-map policy, a non-atom/string
      key, and a stored `nil` boundary are all "not delegated"; the first
      delegated value wins.
    * **JS namespace docs** count actions in the singular for one action.
    * **ARIA shape is law**: a non-map list-form input raises; a non-string
      key is never read as a fact.
    * **LiveView fields/widgets fail soft to the type default**: atom
      widgets render as strings, unrecognized widget or field shapes fall to
      the type-derived default, atom-keyed field specs are read, a binary
      resource name is its own module name, and nil inputs/predicates project
      as empty collections.
    * **Expo** projects with its default prefix; unresolvable resources
      yield an empty (passthrough) input schema.
    * **Projector.IR** refuses a surface node whose `ash` facts are not a map.
    * **VoiceKiosk** projects with its default prefix, emits the exact
      artifact bytes to `target_dir`, and gives no slots when the resource
      has no fields (or no resources are admitted).

  Hand-built IR/surface state only; scratch writes under `_build/test/`.
  """

  use ExUnit.Case, async: false

  alias AshSurface.IR
  alias AshSurface.Projector.{Expo, IREntry, VoiceKiosk}
  alias AshSurface.Projectors.{ARIA, JS, LiveView}

  describe "IREntry.authority_boundary/1" do
    test "skips non-map policies, non-string keys, and nil facts; the first delegated value wins" do
      ir = %IR{
        ash: %IR.Ash{
          resource: "Help.Ticket",
          action: :close,
          policies: [
            "loose policy",
            {:authorityBoundary, "DO"},
            %{1 => "DO", "authorityBoundary" => nil},
            %{authorityBoundary: :OBSERVE},
            %{"authorityBoundary" => "DO"}
          ]
        }
      }

      assert IREntry.authority_boundary(ir) == "OBSERVE"
    end

    test "only non-delegating shapes yield nil" do
      ir = %IR{
        ash: %IR.Ash{
          resource: "Help.Ticket",
          action: :close,
          policies: ["x", %{2 => "DO"}, %{"authorityBoundary" => nil}]
        }
      }

      assert IREntry.authority_boundary(ir) == nil
      refute IREntry.do_boundary?(IREntry.describe(ir))
    end
  end

  describe "JS namespace docs" do
    test "one action is counted in the singular, two in the plural" do
      irs = [
        %IR{ash: %IR.Ash{resource: "Help.Ticket", action: :read, action_type: :read}},
        %IR{ash: %IR.Ash{resource: "Help.Agent", action: :read, action_type: :read}},
        %IR{ash: %IR.Ash{resource: "Help.Agent", action: :create, action_type: :create}}
      ]

      assert {:ok, %{"ash_surface_client.mjs" => code}, _meta} = JS.project_ir(irs)

      assert code =~ "JSDoc-typed namespace for resource `Ticket` (1 action: read)."
      assert code =~ "JSDoc-typed namespace for resource `Agent` (2 actions: create, read)."
    end
  end

  describe "ARIA shape law" do
    test "a non-map list-form input raises with the offending entry" do
      ir = aria_ir(%{"inputs" => ["title"]})

      assert_raise ArgumentError, ~s(list-form aria inputs must be maps, got "title"), fn ->
        ARIA.contract(ir)
      end
    end

    test "a non-string key is never read as a fact" do
      ir = aria_ir(%{1 => "button", "role" => "form", "title" => %{"role" => "textbox"}})

      assert %{"surfaces" => [surface]} = ARIA.contract(ir)
      assert surface["role"] == "form"

      assert surface["inputs"] == [
               %{
                 "name" => "title",
                 "role" => "textbox",
                 "required" => false,
                 "aria-describedby" => nil,
                 "tabIndex" => 1
               }
             ]
    end
  end

  describe "LiveView fail-soft field and widget reads" do
    test "atom widgets render as strings; unrecognized widgets fall to the type default" do
      atom_widget =
        lv_ir("Catalog.Product", :create, :create,
          widget: :textarea,
          input: %{"name" => "string"}
        )

      odd_widget =
        lv_ir("Catalog.Product", :update, :update,
          widget: ["not", "a", "widget"],
          input: %{"price" => %{"type" => "integer"}}
        )

      assert {:ok, view, _meta} = LiveView.project_ir([atom_widget, odd_widget], [])

      forms = view["resources"]["Catalog.Product"]["forms"]
      by_action = Map.new(forms, &{&1["action"], &1["fields"]})

      assert by_action["create"] == [
               %{
                 "name" => "name",
                 "type" => "string",
                 "required" => false,
                 "widget" => "textarea"
               }
             ]

      assert by_action["update"] == [
               %{
                 "name" => "price",
                 "type" => "integer",
                 "required" => false,
                 "widget" => "number"
               }
             ]
    end

    test "atom-keyed specs are read; unrecognized specs are string-typed and optional" do
      read =
        lv_ir("Catalog.Review", :read, :read,
          input: %{
            rating: %{type: :integer, required: true},
            body: 42
          }
        )

      assert {:ok, view, _meta} = LiveView.project_ir(read, [])

      assert view["resources"]["Catalog.Review"]["table"]["columns"] == [
               %{"name" => "body", "type" => "string", "required" => false},
               %{"name" => "rating", "type" => "integer", "required" => true}
             ]
    end

    test "a binary resource name is its own module name; nil inputs and predicates are empty" do
      ir = lv_ir("Catalog.Review", :read, :read, input: nil, predicates: nil)

      assert {:ok, view, meta} = LiveView.project_ir(ir, [])

      block = view["resources"]["Catalog.Review"]
      assert block["resource"] == "Catalog.Review"
      assert block["table"]["surface_action_id"] == "Catalog.Review#read"
      assert block["table"]["columns"] == []
      assert block["relationships"] == []
      assert meta["resource_count"] == 1
    end
  end

  describe "Expo" do
    test "project/1 uses the default prefix and matches project/2 with no opts" do
      surface = expo_surface(%{})

      assert {:ok, artifacts, meta} = AshSurface.project(surface, Expo)
      assert {:ok, ^artifacts, ^meta} = AshSurface.project(surface, Expo, [])
      assert meta.prefix == "zoela_surface"
      assert Map.has_key?(artifacts, "zoela_surface.schemas.mjs")
    end

    test "resources that are neither a map nor a list resolve no fields" do
      assert {:ok, artifacts, _meta} = AshSurface.project(expo_surface("not resources"), Expo)

      assert artifacts["zoela_surface.schemas.mjs"] =~
               "export const Help_Ticket_read_inputSchema = z.object({\n\n}).passthrough();"
    end
  end

  describe "Projector.IR.to_surface/1" do
    test "a surface node whose ash facts are not a map is refused" do
      assert AshSurface.Projector.IR.to_surface(%{kind: "ash_surface.surface", ash: "facts"}) ==
               {:error, {:invalid_surface_facts, []}}

      assert AshSurface.Projector.IR.to_surface([%{kind: "ash_surface.surface"}]) ==
               {:error, {:invalid_surface_facts, []}}
    end
  end

  describe "VoiceKiosk" do
    test "project/1 uses the default prefix and emits the exact bytes to target_dir" do
      surface = voice_surface(%{"res" => %{"name" => "Help.Ticket"}})

      assert {:ok, artifacts, meta} = AshSurface.project(surface, VoiceKiosk)
      assert meta == %{prefix: "voice_kiosk", intent_count: 1}
      assert Map.keys(artifacts) == ["voice_kiosk.voice.json"]

      target_dir =
        Path.join([
          "_build",
          "test",
          "projectors_coverage",
          "voice_#{System.unique_integer([:positive])}"
        ])

      on_exit(fn -> File.rm_rf!(target_dir) end)

      assert {:ok, ^artifacts, _meta} =
               AshSurface.project(surface, VoiceKiosk, target_dir: target_dir)

      assert File.read!(Path.join(target_dir, "voice_kiosk.voice.json")) ==
               artifacts["voice_kiosk.voice.json"]
    end

    test "a resource entry without fields gives no slots" do
      surface = voice_surface(%{"res" => %{"name" => "Help.Ticket"}})

      assert %{"intents" => [%{"slots" => []}]} = VoiceKiosk.voice_ir(surface)
    end

    test "absent resources give no slots" do
      surface = voice_surface(nil)

      assert %{"intents" => [%{"slots" => [], "mode" => "ANSWER"}]} =
               VoiceKiosk.voice_ir(surface)
    end
  end

  ## State builders

  defp aria_ir(aria) do
    %IR{
      ash: %IR.Ash{resource: "Help.Ticket", action: :open, action_type: :create},
      schema: %IR.Schema{aria: aria}
    }
  end

  defp lv_ir(resource, action, action_type, opts) do
    %IR{
      version: "26.10.8",
      digest: "digest-#{resource}-#{action}",
      ash: %IR.Ash{resource: resource, action: action, action_type: action_type, policies: []},
      semantic: %IR.Semantic{predicates: Keyword.get(opts, :predicates, %{})},
      capability: %IR.Capability{
        capability_id: "#{resource}##{action}",
        consequence_class: :observe,
        authority_required: false,
        receipt_required: false
      },
      presentation: %IR.Presentation{label: to_string(action), widget: Keyword.get(opts, :widget)},
      schema: %IR.Schema{input: Keyword.get(opts, :input, %{})}
    }
  end

  defp expo_surface(resources) do
    actions = [%{"id" => "Help.Ticket.read", "resource" => "Help.Ticket", "action" => "read"}]

    AshSurface.TestSupport.VerifiedSurface.seal(%AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-test",
      action_ids: ["Help.Ticket.read"]
    })
  end

  defp voice_surface(resources) do
    actions = [
      %{
        "id" => "Help.Ticket#read",
        "resource" => "Help.Ticket",
        "action" => "read",
        "authorityBoundary" => "OBSERVE",
        "doAuthority" => false,
        "profile" => %{}
      }
    ]

    AshSurface.TestSupport.VerifiedSurface.seal(%AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-test",
      action_ids: ["Help.Ticket#read"]
    })
  end
end
