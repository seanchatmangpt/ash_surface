# L17-safeparse-courts

## Law under test

Generated `dispatchIntent` on bad input throws an error with
`code = "INPUT_VALIDATION_FAILED"` and `detail.issues` =
`[{path (dot-joined string), message, code}]`; no raw ZodError escapes;
REFUSED_* refusals (`REFUSED_UNKNOWN_ACTION`, `REFUSED_NOT_DO_BOUNDARY`) are
unchanged and never carry the envelope code. This is L07/L08's law, landed at
`lib/ash_surface/projectors/js.ex:507-524` (`safeParse` envelope).

## Courts

- `test/ash_surface/projectors/js_safeparse_test.exs` + runner
  `test/js/generated_js_safeparse_runner.mjs`: the artifact is manufactured by
  the real `AshSurface.Projectors.JS.project_ir/2` from a fixture IR set
  (DO-boundary `Todo.create` with a NESTED Zod schema so the dot-joined path
  law is exercised on both a top-level path `title` and a nested path
  `meta.due_on`; OBSERVE `Todo.list` for the refusal case), then imported and
  driven under real Node — no mocks, execution receipt only.
  - The runner asserts per invalid input: `code` equals the envelope constant,
    the error is not a ZodError by name NOR by real `instanceof ZodError`
    (runner imports zod for that check), `detail.issues` is a non-empty array
    of `{path: string, message: non-empty string, code: non-empty string}`,
    and the expected dot-joined path is present.
  - Valid input still mints the frozen `{kind, actionId, input}` intent.
  - REFUSED_* messages, `refusal` fields hold, and neither carries
    `INPUT_VALIDATION_FAILED`.
- Mutation court: a copy of the projected artifact with
  `action.schema.safeParse(input)` reverted to
  `{ success: true, data: action.schema.parse(input) }` (raw ZodError
  passthrough, i.e. the L07-reverted subject) must FAIL the same runner —
  control: the pristine copy passes.

## Notes

- Premise-rot hazard checked: the older
  `test/js/generated_js_projector_runner.mjs` pinned the raw-ZodError law
  (`assert.throws(..., { name: "ZodError" })`); L07 updated it — both that
  runner and `generated_artifacts_exec_test.exs` pass alongside these courts.
- Compile-freeze disclosure: `lib/ash_surface/compiler/calculation_schema.ex`
  was briefly non-compiling mid-flight (invalid multi-expression `cond`
  clause); the owning lane fixed it itself before L17 applied any unblock —
  no L17 edit landed in that file.

## See Also

- `docs/jira/v26.11.11/receipts/L17.md` (receipt)
- `test/ash_surface/projector/generated_artifacts_exec_test.exs` (harness pattern)
