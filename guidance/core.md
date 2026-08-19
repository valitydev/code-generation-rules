# Shared agent guidance

Treat repository-local code, tests, build configuration, and local `AGENTS.md` /
`CLAUDE.md` content as the primary evidence for how this project is built.

Keep these organization-level invariants:

- Do not edit generated sources. Change their source contract or generator instead.
- Preserve published wire/storage compatibility unless the task explicitly requires a
  coordinated breaking change or migration.
- Never hardcode, expose, or log credentials, tokens, PANs, bank-account data, or
  other payment-sensitive values.
- Prefer an established local implementation pattern over introducing a new framework,
  package layout, abstraction, or dependency without a concrete need.
- Run the project's existing focused tests, linters, generators, and compatibility
  checks that cover the changed area.
- Do not load or apply detailed guidance that is unrelated to the current task.

Detailed references are defaults and checklists, not permission to override stronger
repository evidence or explicit task requirements.
