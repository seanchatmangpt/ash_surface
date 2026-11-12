defmodule AshSurface.Projectors.JSSafeparseTest do
  @moduledoc """
  L17 courts for the safeParse INPUT_VALIDATION_FAILED envelope of the
  generated `dispatchIntent` (L07/L08's law).

  The artifact is manufactured by the real `AshSurface.Projectors.JS`
  projector and executed under real Node (`test/js/generated_js_safeparse_runner.mjs`)
  — no mocks, execution receipts only, per the generated_artifacts_exec_test
  pattern.

  Law under test: bad input to a DO-boundary `dispatchIntent` throws an error
  with `code = "INPUT_VALIDATION_FAILED"` and `detail.issues` =
  `[{path (dot-joined string), message, code}]`; no raw ZodError escapes;
  REFUSED_* refusals are unchanged and never carry the envelope code.
  """

  use ExUnit.Case, async: false

  alias AshSurface.{IR, Projectors.JS, Vocabulary}

  @prefix "ash_surface_client"
  @tmp_dir AshSurface.TestTmp.scoped(Path.expand("../../../_build/test/js_safeparse_l17", __DIR__))
  @dispatch_id "Todo.create"
  @descriptor_id "Todo.list"
  @unknown_id "Nope.missing"

  @nested_zod "z.object({\n  title: z.string().min(1),\n  meta: z.object({ due_on: z.string().optional() })\n})"
  @list_zod "z.object({\n  status: z.enum([\"open\", \"done\"]).optional()\n})"

  @valid_input %{"title" => "ship it", "meta" => %{"due_on" => "2026-11-12"}}

  @invalid_inputs [
    %{
      "label" => "missing required title",
      "input" => %{"meta" => %{}},
      "expectIssueFor" => "title"
    },
    %{"label" => "title wrong type", "input" => %{"title" => 5}, "expectIssueFor" => "title"},
    %{
      "label" => "nested path dot-joined",
      "input" => %{"title" => "ok", "meta" => %{"due_on" => 5}},
      "expectIssueFor" => "meta.due_on"
    }
  ]

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    :ok
  end

  describe "safeParse INPUT_VALIDATION_FAILED envelope" do
    test "bad input yields the envelope with dot-joined issues; valid input mints an intent; REFUSED_* unchanged" do
      dir = project_fixture!()

      assert %{"receipt" => "GENERATED_JS_SAFEPARSE_PASS", "invalidCases" => 3, "refusals" => 2} =
               run_runner!(dir)
    end
  end

  describe "Elixir-side twin: issue shape pinned to AshSurface.Vocabulary (I16)" do
    test "emitted issue keys, code and path/message shape match the vocabulary" do
      dir = project_fixture!()
      script = Path.join(@tmp_dir, "twin_probe.mjs")

      File.write!(script, """
      import { dispatchIntent } from "./artifact/#{@prefix}.mjs";
      try {
        dispatchIntent("#{@dispatch_id}", { title: "ok", meta: { due_on: 5 } });
        console.log(JSON.stringify({ threw: false }));
      } catch (e) {
        console.log(JSON.stringify({ threw: true, code: e.code, issues: e.detail.issues }));
      }
      """)

      assert File.dir?(dir)
      {out, 0} = System.cmd("node", [script], stderr_to_stdout: true, cd: @tmp_dir)

      assert %{"threw" => true, "code" => code, "issues" => [_ | _] = issues} =
               out |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()

      assert code in Vocabulary.issue_refusal_codes()
      assert code == "INPUT_VALIDATION_FAILED"

      for issue <- issues do
        assert Map.keys(issue) |> Enum.sort() == Enum.sort(Vocabulary.issue_shape_keys())
        assert is_binary(issue["path"]) and is_binary(issue["message"]) and is_binary(issue["code"])
      end

      assert Enum.any?(issues, &(&1["path"] == "meta.due_on"))
    end

    test "projector source emits exactly the vocabulary's issue keys" do
      source = File.read!(Path.expand("../../../lib/ash_surface/projectors/js.ex", __DIR__))
      [_, block] = Regex.run(~r/err\.issues = result\.error\.issues\.map\(\(i\) => \(\{(.*?)\}\)\)/s, source)
      keys = Regex.scan(~r/^\s*(\w+):/m, block) |> Enum.map(&List.last/1)
      assert keys == Vocabulary.issue_shape_keys()
    end
  end

  describe "mutation sanity: reverting safeParse to raw parse fails the same receipt" do
    test "raw ZodError passthrough is caught" do
      base = project_fixture!()
      mutant = Path.join(@tmp_dir, "mutant")
      File.mkdir_p!(mutant)

      for f <- File.ls!(base), String.ends_with?(f, ".mjs") do
        File.cp!(Path.join(base, f), Path.join(mutant, f))
      end

      install_runtime_shim!(mutant)

      # Control: the pristine copy passes the very same runner.
      assert {_, 0} = node_cmd([spec_for!(base)])

      path = Path.join(mutant, "#{@prefix}.mjs")
      source = File.read!(path)

      anchor = "const result = action.schema.safeParse(input);"
      assert String.contains?(source, anchor), "safeParse anchor not found in projected artifact"

      File.write!(
        path,
        String.replace(
          source,
          anchor,
          "const result = { success: true, data: action.schema.parse(input) };"
        )
      )

      assert {output, status} = node_cmd([spec_for!(mutant)])
      refute status == 0, "raw-ZodError passthrough mutation passed the receipt: #{output}"
      assert output =~ "AssertionError" or output =~ "Error"
    end
  end

  # -- manufacture + run helpers ----------------------------------------------

  defp project_fixture! do
    dir = Path.join(@tmp_dir, "artifact")
    File.mkdir_p!(dir)
    install_runtime_shim!(dir)

    irs = [
      IR.new(
        ash: %IR.Ash{
          resource: "Todo",
          action: :create,
          action_type: :create,
          policies: [%{"authorityBoundary" => "DO"}]
        },
        capability: %IR.Capability{capability_id: "todo.write", receipt_required: true},
        schema: %IR.Schema{zod: @nested_zod}
      ),
      IR.new(
        ash: %IR.Ash{
          resource: "Todo",
          action: :list,
          action_type: :read,
          policies: [%{"authorityBoundary" => "OBSERVE"}]
        },
        schema: %IR.Schema{zod: @list_zod}
      )
    ]

    assert {:ok, %{"#{@prefix}.mjs" => _}, _meta} = JS.project_ir(irs, target_dir: dir)
    dir
  end

  defp spec_for!(dir) do
    spec_path = Path.join(@tmp_dir, "spec_#{AshSurface.TestTmp.suffix()}.json")

    File.write!(
      spec_path,
      Jason.encode!(%{
        targetDir: dir,
        prefix: @prefix,
        dispatchId: @dispatch_id,
        descriptorId: @descriptor_id,
        unknownId: @unknown_id,
        validInput: @valid_input,
        invalidInputs: @invalid_inputs
      })
    )

    spec_path
  end

  defp run_runner!(dir) do
    {output, status} = node_cmd([spec_for!(dir)])
    assert status == 0, "execution receipt failed:\n#{output}"

    assert {:ok, receipt} =
             output |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode()

    receipt
  end

  defp node_cmd(args) do
    System.cmd("node", ["test/js/generated_js_safeparse_runner.mjs" | args],
      stderr_to_stdout: true,
      cd: Path.expand("../../..", __DIR__)
    )
  end

  defp install_runtime_shim!(dir) do
    zod_source = Path.expand("../../../node_modules/zod", __DIR__)
    assert File.dir?(zod_source), "npm install must provide node_modules/zod before mix test"

    File.mkdir_p!(Path.join(dir, "node_modules"))

    case File.ln_s(zod_source, Path.join([dir, "node_modules", "zod"])) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> flunk("failed to link Zod runtime: #{inspect(reason)}")
    end
  end
end
