# code-generation-rules

Shared agent guidance and deterministic coding hooks for Vality services.

The repository is mounted into a consuming project as `.agent-rules`. The always-on
agent context stays intentionally small: durable cross-project invariants and routes to
more specific guidance. Detailed conventions are read only for tasks that need them.

Repository-local code, tests, build configuration, `AGENTS.md`, and `CLAUDE.md` remain
the primary source for local architecture and implementation patterns.

## Repository layout

- `guidance/core.md` — compact guidance installed into the persistent agent context.
- `skills/provider-adapter/` — workflow and focused references for external
  payment/provider integrations.
- `references/` — task-specific guidance for database, generated contracts, OpenAPI,
  and cross-layer code decisions.
- `hooks/` — deterministic lifecycle checks; currently Kotlin formatting/linting.
- `agents/` — Claude Code and Codex hook fragments.
- `install.sh` — installs or refreshes the managed agent block and hooks.
- `check.sh` — verifies that the consuming repository is synchronized with the pinned
  submodule revision.
- `ci/github-actions/agent-rules-drift.yml` — optional CI drift check.

## Install

From the consuming repository:

```bash
git submodule add <repo-url> .agent-rules
./.agent-rules/install.sh
```

The installer is idempotent. It owns only:

- content between `<!-- BEGIN agent-rules -->` and `<!-- END agent-rules -->` in
  `AGENTS.md` and `CLAUDE.md`;
- the hook entries registered in `.codex/hooks.json` and `.claude/settings.json`.

Content outside the managed block is preserved.

Requirements: `git` and `jq`. The Kotlin hook uses Maven only when the target project
contains `ktlint-maven-plugin`.

## Profiles

The default profile is `common`.

For a persistent project profile, commit `.agent-rules-profile` with exactly one of:

```text
common
openapi
adapter
```

- `common` — compact core plus common task routes.
- `openapi` — common routes plus OpenAPI guidance.
- `adapter` — common routes plus the provider-adapter workflow.

A profile can be overridden for one invocation:

```bash
./.agent-rules/install.sh --profile adapter
```

For normal repository use, prefer committing `.agent-rules-profile` so `check.sh` and
CI resolve the same profile without extra flags.

## Update

```bash
git submodule update --remote .agent-rules
./.agent-rules/install.sh
git diff
```

Review and commit the submodule pointer together with generated changes to the managed
agent configuration.

## CI drift check

Run:

```bash
./.agent-rules/check.sh
```

The command writes nothing. It exits non-zero if the managed blocks or hook
configuration do not match the pinned `.agent-rules` revision.

A GitHub Actions example is available at:

```text
ci/github-actions/agent-rules-drift.yml
```

The consuming workflow must checkout submodules.

## Agent routing

The installed persistent block does not copy the contents of `references/` or
`skills/` into every task. It tells the coding agent when to read them:

- schema/migration/repository/transaction work → `references/database.md`;
- generated-source or Protobuf work → `references/code-generation.md`;
- cross-layer architecture/client/converter decisions not settled by local code →
  `references/code-conventions.md`;
- OpenAPI work in the `openapi` profile → `references/openapi.md`;
- external payment/provider integrations in the `adapter` profile →
  `skills/provider-adapter/SKILL.md`.

The provider-adapter workflow starts from existing production adapters in the target
repository and loads its narrower references only when the concrete flow needs them.

## Project-specific environment

If the build hook needs project-local environment such as `JAVA_HOME`, the consuming
repository may provide `.agent-rules.env` at its root. The hook sources that file when
present. Keep secrets out of this file unless the consuming repository already has an
appropriate secret-injection mechanism and the file itself is not committed.
