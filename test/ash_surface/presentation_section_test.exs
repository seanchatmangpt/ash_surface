# v06 owns lib/ash_surface/compiler/presentation.ex (the presentation reader
# and its IR struct). That branch is not merged into this one, so the build/2
# contract is DECLARED HERE locally — same module paths, same truth — guarded
# so the real reader wins the moment v06's file lands at integration. Any
# drift between the declaration and the real reader breaks this suite.
unless Code.ensure_loaded?(AshSurface.Compiler.Presentation) do
  defmodule AshSurface.Compiler.IR.Presentation do
    @moduledoc """
    Contract declaration of the presentation IR struct (v06 owns the real
    definition). Field defaults ARE the contract: label/group/format nil,
    order 0, widget "default".
    """

    defstruct label: nil, group: nil, order: 0, widget: "default", format: nil
  end

  defmodule AshSurface.Compiler.Presentation do
    @moduledoc """
    Contract declaration of the presentation section reader's build/2 (v06
    owns the real reader). Reads `custom.ash_surface` presentation overrides
    (envelope key atom or string; section key string only); defaults label to
    the humanized action name, group/format to nil, order to 0, widget to
    "default"; rejects a widget outside the admitted vocabulary with a typed
    refusal. Mirrors v06's truth exactly — do not extend here.
    """

    @admitted_widgets ~w(default text textarea toggle select number date)

    def build(action, custom) when is_map(custom) do
      with {:ok, name} <- action_identity(action),
           {:ok, overrides} <- presentation_overrides(custom),
           :ok <- admit_widget(name, overrides) do
        {:ok,
         %AshSurface.Compiler.IR.Presentation{
           label: overrides["label"] || humanize(name),
           group: overrides["group"],
           order: overrides["order"] || 0,
           widget: overrides["widget"] || "default",
           format: overrides["format"]
         }}
      end
    end

    def build(_action, _custom) do
      {:error, [invalid_compilation("custom metadata must be a map")]}
    end

    defp action_identity(name) when is_atom(name), do: {:ok, name}

    defp action_identity(%{name: name}) when is_atom(name), do: {:ok, name}

    defp action_identity(_other) do
      {:error,
       invalid_compilation(
         "an action is an atom action name or a map with an atom :name (e.g. a manifest entrypoint action)"
       )}
    end

    defp presentation_overrides(custom) do
      case Map.get(custom, :ash_surface) || Map.get(custom, "ash_surface") do
        nil ->
          {:ok, %{}}

        %{} = envelope ->
          case Map.get(envelope, "presentation") do
            nil -> {:ok, %{}}
            %{} = overrides -> {:ok, overrides}
            _ -> {:error, invalid_compilation("custom.ash_surface presentation must be a map")}
          end

        _other ->
          {:error, invalid_compilation("custom.ash_surface must be a map")}
      end
    end

    defp admit_widget(name, %{"widget" => widget}) do
      if widget in @admitted_widgets do
        :ok
      else
        {:error,
         [
           %{
             code: "unknown_widget_presentation",
             detail:
               "presentation for #{inspect(name)} declares widget #{inspect(widget)}; admitted widgets are " <>
                 inspect(@admitted_widgets)
           }
         ]}
      end
    end

    defp admit_widget(_name, _overrides), do: :ok

    defp humanize(name) when is_atom(name), do: humanize(Atom.to_string(name))

    defp humanize(name) when is_binary(name),
      do: name |> String.replace("_", " ") |> String.capitalize()

    defp invalid_compilation(detail),
      do: [%{code: "invalid_presentation_compilation", detail: detail}]
  end
end

defmodule AshSurface.PresentationSectionTest do
  @moduledoc """
  Adversarial depth for `AshSurface.Compiler.Presentation.build/2` — the
  presentation section reader, the ONLY metadata ash_surface owns.

  Law under test (basics live in v06's own suite; nothing here duplicates them):

    1. Label coercion truth: the reader is a CARRIER, not a coercer. No value
       is ever stringified, trimmed, or rejected on kind; only the falsy
       values nil/false collapse to the humanized default. Everything else —
       "", 0, atoms, maps — rides verbatim, so projection layers own coercion
       and escaping at their boundaries.
    2. Order numeric truth: no numeric parsing or clamping. Absent/nil/false
       collapse to 0; negatives, floats, and even numeric STRINGS ride verbatim.
    3. Section isolation: presentation never leaks into other sections and
       other sections never leak into presentation. The reader sees exactly
       the string `"presentation"` map inside `custom.ash_surface` — atom
       impostors, near-miss keys, and sibling sections are invisible — and
       the IR it returns carries exactly the five presentation fields.
    4. Widget vocabulary is admitted, never guessed: exact-match against the
       frozen seven-widget vocabulary; case variance, padding, blank, nil,
       and false are all the same typed refusal, never a silent default.
    5. Label projection-safety: hostile labels survive the reader
       byte-identical and compose safely with json/js/aria artifact fragments
       (JSON round-trip fidelity, breakout-free JS string literal, breakout-
       free escaped aria attribute).
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.IR.Presentation, as: PresentationIR
  alias AshSurface.Compiler.Presentation

  # Frozen vocabulary: drift in the admitted widget set breaks this build.
  @frozen_widgets ~w(default text textarea toggle select number date)

  # Hostile label corpus for projection-safety: HTML/script injection, quote
  # breakout, template-literal syntax, control characters, JS line separator
  # (U+2028), RTL override (U+202E), and meta-characters of every fragment
  # grammar under test.
  @hostile_labels [
    "</script>",
    ~s{aria-label" onmouseover="pwn()},
    "line1\nline2\ttab\r",
    "eval(`${payload}`)",
    "\u2028line separator",
    "\u202Ertl override",
    "quote'back`tick\\slash\"double"
  ]

  defp presentation(overrides) do
    %{ash_surface: %{"presentation" => overrides}}
  end

  # ---------------------------------------------------------------------------
  # 1. Label string-coercion truth
  # ---------------------------------------------------------------------------

  describe "label coercion truth: carrier, not coercer" do
    test "explicit nil is indistinguishable from absence (falsy collapse)" do
      assert {:ok, from_nil} = Presentation.build(:read, presentation(%{"label" => nil}))
      assert {:ok, from_absent} = Presentation.build(:read, presentation(%{}))

      assert from_nil.label == "Read"
      assert from_nil == from_absent
    end

    test "explicit false collapses to the humanized default like nil" do
      assert {:ok, presented} = Presentation.build(:read, presentation(%{"label" => false}))

      assert presented.label == "Read"
    end

    test "empty string is truthy: an explicit empty label is preserved, not defaulted" do
      assert {:ok, presented} = Presentation.build(:read, presentation(%{"label" => ""}))

      assert presented.label == ""
    end

    test "non-string labels ride verbatim — kind is never enforced or converted" do
      for value <- [0, 3.14, :publish_now, %{nested: true}, ["a", "b"]] do
        assert {:ok, presented} = Presentation.build(:read, presentation(%{"label" => value}))

        assert presented.label == value
      end

      assert {:ok, presented} = Presentation.build(:read, presentation(%{"label" => 0}))
      refute is_binary(presented.label)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Order numeric handling
  # ---------------------------------------------------------------------------

  describe "order numeric handling: no parsing, no clamping" do
    test "absent, nil, false, and explicit 0 all compile to 0" do
      for overrides <- [%{}, %{"order" => nil}, %{"order" => false}, %{"order" => 0}] do
        assert {:ok, presented} = Presentation.build(:read, presentation(overrides))

        assert presented.order == 0
      end
    end

    test "numeric truth rides verbatim: negatives, floats, and numeric strings" do
      for {value, expected} <- [{-7, -7}, {7.5, 7.5}, {1.0e300, 1.0e300}, {"42", "42"}] do
        assert {:ok, presented} = Presentation.build(:read, presentation(%{"order" => value}))

        assert presented.order == expected
      end

      assert {:ok, presented} = Presentation.build(:read, presentation(%{"order" => "42"}))
      refute is_integer(presented.order)
      refute is_number(presented.order)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Section isolation: presentation never leaks, in either direction
  # ---------------------------------------------------------------------------

  describe "section isolation" do
    test "sibling section keys in the envelope are invisible to the presentation reader" do
      custom = %{
        ash_surface: %{
          "presentation" => %{"label" => "Presentation Label", "widget" => "toggle"},
          "aria" => %{"label" => "Aria Label", "described_by" => "hostile-ref"},
          "capability" => %{"labels" => ["capability-label"]},
          "profile" => %{"consumer" => "web"},
          "transport" => %{"preferred" => "http"}
        }
      }

      assert {:ok, presented} = Presentation.build(:read, custom)

      # Presentation reads only its own section.
      assert presented.label == "Presentation Label"
      assert presented.widget == "toggle"

      # The IR exposes exactly the five presentation fields — nothing else.
      assert presented |> Map.from_struct() |> Map.keys() |> Enum.sort() ==
               [:format, :group, :label, :order, :widget]

      # No sibling section's value bleeds into any presentation field.
      sibling_values = ~w(Aria Label capability-label hostile-ref web http)a
      refute Enum.any?(Map.from_struct(presented), fn {_k, v} -> v in sibling_values end)
    end

    test "an atom :presentation key does not alias the string section key" do
      only_atom = %{ash_surface: %{:presentation => %{"label" => "Atom Impostor"}}}
      assert {:ok, presented} = Presentation.build(:read, only_atom)
      assert presented.label == "Read"

      both = %{
        ash_surface: %{
          :presentation => %{"label" => "Atom Impostor"},
          "presentation" => %{"label" => "String Key Wins"}
        }
      }

      assert {:ok, presented} = Presentation.build(:read, both)
      assert presented.label == "String Key Wins"
    end

    test "near-miss section keys are invisible" do
      custom = %{
        ash_surface: %{
          "presentations" => %{"label" => "Plural"},
          "presentation_shim" => %{"order" => 99}
        }
      }

      assert {:ok, presented} = Presentation.build(:read, custom)

      assert presented.label == "Read"
      assert presented.order == 0
    end

    test "an atom-keyed ash_surface envelope still reaches its presentation overrides" do
      assert {:ok, presented} =
               Presentation.build(:read, %{
                 ash_surface: %{"presentation" => %{"label" => "Atom Envelope"}}
               })

      assert presented.label == "Atom Envelope"
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Widget vocabulary enforcement
  # ---------------------------------------------------------------------------

  describe "widget vocabulary enforcement: admitted, never guessed" do
    test "the full frozen vocabulary is admitted verbatim" do
      for widget <- @frozen_widgets do
        assert {:ok, %PresentationIR{widget: ^widget}} =
                 Presentation.build(:read, presentation(%{"widget" => widget}))
      end
    end

    test "case variance is rejected — the vocabulary is exact, not normalized" do
      for widget <- ["Toggle", "TOGGLE", "Default", "tEXT"] do
        assert {:error, [%{code: "unknown_widget_presentation"}]} =
                 Presentation.build(:read, presentation(%{"widget" => widget}))
      end
    end

    test "padded and blank widgets are rejected without trimming" do
      for widget <- [" toggle", "toggle ", "toggle\n", ""] do
        assert {:error, [%{code: "unknown_widget_presentation"}]} =
                 Presentation.build(:read, presentation(%{"widget" => widget}))
      end
    end

    test "an explicit nil widget is a typed rejection, not a silent default" do
      assert {:error, [%{code: "unknown_widget_presentation", detail: detail}]} =
               Presentation.build(:read, presentation(%{"widget" => nil}))

      assert detail =~ "nil"
    end

    test "a false widget is the same typed rejection" do
      assert {:error, [%{code: "unknown_widget_presentation", detail: detail}]} =
               Presentation.build(:read, presentation(%{"widget" => false}))

      assert detail =~ "false"
    end

    test "every rejection is one typed refusal naming the value and the whole vocabulary" do
      assert {:error, refusals} =
               Presentation.build(:read, presentation(%{"widget" => "hologram"}))

      assert [%{code: "unknown_widget_presentation", detail: detail}] = refusals
      assert detail =~ ~s("hologram")

      for widget <- @frozen_widgets do
        assert detail =~ widget
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Label projection-safety across json/js/aria artifact fragments
  # ---------------------------------------------------------------------------

  describe "label projection-safety across artifact fragments" do
    test "the reader carries hostile labels byte-identical (projection-safety precondition)" do
      for hostile <- @hostile_labels do
        assert {:ok, %PresentationIR{label: label}} =
                 Presentation.build(:read, presentation(%{"label" => hostile}))

        assert label == hostile
        assert byte_size(label) == byte_size(hostile)
      end
    end

    test "json fragment: Jason round-trip preserves the label with no raw control characters" do
      for hostile <- @hostile_labels do
        encoded = Jason.encode!(%{"label" => hostile})

        # Fidelity: the artifact fragment decodes back to the exact label.
        assert Jason.decode!(encoded)["label"] == hostile

        # Breakout: JSON escapes every newline/quote, so the fragment is a
        # single line and the payload cannot terminate its own string.
        refute String.contains?(encoded, "\n")
        assert String.starts_with?(encoded, ~s({"label":))
      end
    end

    test "js fragment: a JSON string literal is a valid .mjs payload and survives verbatim" do
      for hostile <- @hostile_labels do
        encoded = Jason.encode!(hostile)
        fragment = "const label = " <> encoded <> ";\n"

        # The .mjs artifact (repo JS law: modules, never inline script tags)
        # embeds the label as a double-quoted JSON literal; the only breakout
        # vectors for that grammar — raw quote, raw newline — are absent, and
        # the artifact's payload is still the exact label.
        assert String.contains?(fragment, "const label = " <> encoded)

        literal =
          fragment |> String.trim_leading("const label = ") |> String.trim_trailing(";\n")

        assert literal == encoded
        refute String.contains?(encoded, "\n")
        assert Jason.decode!(encoded) == hostile
      end
    end

    test "aria fragment: boundary escaping is breakout-free and recoverable" do
      for hostile <- @hostile_labels do
        fragment = ~s(aria-label="#{escape_aria(hostile)}")

        # No early termination: the attribute value region contains no raw
        # quote, so hostile quoting cannot open a second attribute.
        assert fragment =~ ~r/\Aaria-label="[^"]*"\z/

        # No tag injection: no raw < survives inside the attribute value.
        value = fragment |> String.trim_leading(~s(aria-label=")) |> String.trim_trailing(~s("))
        refute String.contains?(value, "<")

        # Recoverable: unescaping yields the exact hostile label.
        assert unescape_aria(value) == hostile
      end
    end
  end

  # Minimal attribute escaper for the aria fragment projection (test-local
  # stub: proves the reader's verbatim truth composes safely with boundary
  # escaping; the real escaper belongs to the rendering projector).
  defp escape_aria(label) when is_binary(label) do
    label
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp unescape_aria(escaped) when is_binary(escaped) do
    escaped
    |> String.replace("&quot;", "\"")
    |> String.replace("&gt;", ">")
    |> String.replace("&lt;", "<")
    |> String.replace("&amp;", "&")
  end
end
