# code-generation-rules

Shared agent guidance and deterministic coding hooks for Vality services.

The repository is mounted into a consuming project as `.agent-rules`. The persistent
agent context stays intentionally small: durable cross-project invariants plus routes
to more specific guidance. Detailed conventions are read only for tasks that need
them.

Repository-local code, tests, build configuration, `AGENTS.md`, and `CLAUDE.md` remain
the primary evidence for local architecture and implementation patterns. External
contract skills may define a different authoritative source for the wire contract
itself.

## Guidance model

Use the narrowest mechanism that reliably owns a rule:

- `guidance/core.md` — durable organization-wide invariants and routing only;
- `references/` — task-specific checklists and defaults loaded when relevant;
- `skills/provider-adapter/` — the reusable workflow for external provider adapters;
- repository-local code/instructions — service-specific architecture and conventions;
- hooks, generators, linters, tests, and CI — deterministic checks that should not be
  implemented mainly through prose.

A rule should not become always-on merely because it is good engineering advice. Keep
it persistent when omitting it repeatedly causes a material wrong choice across the
whole scope. Otherwise put it in a narrower reference/skill, leave it to repository
evidence, or enforce it with tooling.

## Repository layout

- `guidance/core.md` — compact guidance installed into persistent agent context.
- `references/` — focused guidance for database, generated contracts, OpenAPI, and
  cross-layer code decisions.
- `skills/provider-adapter/` — contract-first provider workflow and narrow references.
- `hooks/` — deterministic lifecycle checks; currently Kotlin formatting/linting.
- `agents/` — Claude Code and Codex hook fragments.
- `install.sh` — installs or refreshes the managed agent block and hooks.
- `check.sh` — verifies that a consuming repository matches the pinned submodule.
- `ci/github-actions/agent-rules-drift.yml` — optional consuming-repository drift check.

## Install

From the consuming repository:

```bash
git submodule add <repo-url> .agent-rules
./.agent-rules/install.sh
```

The installer is idempotent. It owns only:

- content between `<!-- BEGIN agent-rules -->` and `<!-- END agent-rules -->` in
  `AGENTS.md` and `CLAUDE.md`;
- hook entries containing this repository's `format-kotlin.sh` marker in
  `.codex/hooks.json` and `.claude/settings.json`.

Content outside those owned areas is preserved. On Codex, a one-time migration may
move legacy root-level `Stop`/`SubagentStop` groups into the current top-level `hooks`
object; unrelated handlers inside those groups are preserved.

Requirements: `git` and `jq`. The Kotlin hook uses Maven only when the target project
contains `ktlint-maven-plugin`.

## Legacy profile compatibility

Guidance routing is task-driven rather than profile-driven. New consuming repositories
do not need `.agent-rules-profile`.

For compatibility with repositories already using the previous interface,
`.agent-rules-profile` and `--profile common|openapi|adapter` are still accepted by
`install.sh` / `check.sh`, but those values no longer remove routes from the managed
agent block. This lets existing CI and project configuration migrate without changing
which task-specific guidance is available.

## Agent routing

The managed block does not copy `references/` or `skills/` into every task. It routes
the coding agent:

- schema/migration/repository/transaction work → `references/database.md`;
- generated-source or Protobuf work → `references/code-generation.md`;
- cross-layer architecture/client/converter decisions not settled by local code →
  `references/code-conventions.md`;
- OpenAPI contract/generation work → `references/openapi.md`;
- changes that cross an external provider boundary or provider flow — request/response,
  authentication, callbacks, polling, provider error mapping, provider integration
  tests, or adapting another provider → `skills/provider-adapter/SKILL.md`.

Ordinary internal bugs/refactors do not load the provider skill merely because they are
in an adapter repository. The provider skill distinguishes the provider contract from
local implementation evidence, starts from the closest working local flow, and loads
only references needed for the concrete operation. Routes may compose: for example, an
adapter change that also modifies OpenAPI or persistence can load both relevant paths.

## Hooks

`hooks/format-kotlin.sh` runs at `Stop`/`SubagentStop` when the current agent surface
supports project hooks. When Kotlin changed and the project uses
`ktlint-maven-plugin`, it runs formatting and checking and can return remaining
violations to the agent.

The Codex fragment follows the current `.codex/hooks.json` schema with a top-level
`hooks` object. `install.sh` also removes legacy root-level `Stop`/`SubagentStop`
entries previously installed by this repository before writing the current shape.

## Update and drift check

```bash
git submodule update --remote .agent-rules
./.agent-rules/install.sh
git diff
./.agent-rules/check.sh
```

Review and commit the submodule pointer together with generated managed-block/hook
changes. `check.sh` writes nothing and exits non-zero on drift.

The optional GitHub Actions example is
`ci/github-actions/agent-rules-drift.yml`; consuming workflows must checkout
submodules.

## Project-specific environment

If the Kotlin hook needs project-local environment such as `JAVA_HOME`, the consuming
repository may provide `.agent-rules.env` at its root. The hook sources that file when
present. Do not commit secrets in that file.
