# code-generation-rules

Shared engineering rules and agent tooling for the organization, mounted into
projects as a git submodule.

The repository carries three things:

- `rules/` — the rules themselves, as plain markdown. Single source of truth.
- `hooks/` — scripts wired into agent lifecycle events (Claude Code and Codex).
- `install.sh` / `check.sh` — wire the above into a consuming project, idempotently.

## What belongs here

Only rules that hold for the whole organization. Anything tied to one service —
its packages, its build quirks, its local conventions — stays in that service's
own `AGENTS.md` / `CLAUDE.md`, outside the synced block.

## Adding to a project

```bash
git submodule add <repo-url> .agent-rules
./.agent-rules/install.sh
```

`install.sh` is idempotent and touches only what it owns:

- registers the Kotlin format hook in `.claude/settings.json` and `.codex/hooks.json`
- writes `@`-imports of `rules/*` into `CLAUDE.md`
- syncs the rule text into `AGENTS.md` between `<!-- BEGIN agent-rules -->` and
  `<!-- END agent-rules -->`

Everything outside those markers is yours and is never rewritten.

Commit the resulting changes together with the submodule pointer.

## Updating

```bash
git submodule update --remote .agent-rules
./.agent-rules/install.sh
```

Review the diff, then commit. The bump is explicit per project — rules never
change under a project without a commit in it.

## Keeping projects honest

`check.sh` is `install.sh --check`: it writes nothing and exits non-zero when a
project has drifted from the submodule it pins. Wire it into CI with
`ci/github-actions/agent-rules-drift.yml` — note the `submodules: true` on
checkout, without it the check runs against an empty directory.

## The Kotlin format hook

`hooks/format-kotlin.sh` runs on the agent's `Stop` event — once per turn, after
the code is generated, in both Claude Code and Codex.

When the turn touched Kotlin, it runs `ktlint:format` and `ktlint:check` in one
maven invocation. Both goals are needed: `format` fixes what it can but exits
successfully while staying silent about the rest, so only `check` surfaces the
violations that need a human-shaped fix. Those are handed back to the agent,
which then has to correct them before the turn can end.

It is deliberately quiet and cheap: with no changed `.kt`/`.kts` files, or in a
project with no ktlint, it exits in well under a tenth of a second without
starting a JVM.

Note that `ktlint:format` covers the whole module, not just the changed files.
In a project where CI already enforces `ktlint:check`, everything committed is
formatted anyway, so this is a no-op on untouched code.

If a project needs specific environment to run its build (a particular
`JAVA_HOME`, a locale), put it in `.agent-rules.env` in the project root — the
hook sources it when present. That file belongs to the project, not here.
