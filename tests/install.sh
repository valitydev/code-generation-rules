#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"

command -v git >/dev/null
command -v jq >/dev/null

bash -n "$ROOT/install.sh"
bash -n "$ROOT/check.sh"
bash -n "$ROOT/hooks/format-kotlin.sh"
bash -n "$ROOT/hooks/lib/common.sh"

jq -e '
  (.hooks.Stop | type == "array") and
  (.hooks.SubagentStop | type == "array") and
  (has("Stop") | not) and
  (has("SubagentStop") | not)
' "$ROOT/agents/codex/hooks.json" >/dev/null

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

CONSUMER="$TMP/consumer"
mkdir -p "$CONSUMER/.agent-rules"
(
    cd "$ROOT"
    tar --exclude=.git -cf - .
) | (
    cd "$CONSUMER/.agent-rules"
    tar -xf -
)

git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email test@example.invalid
git -C "$CONSUMER" config user.name agent-rules-test
mkdir -p "$CONSUMER/.codex"

cat >"$CONSUMER/.codex/hooks.json" <<'JSON'
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "if [ -x .agent-rules/hooks/format-kotlin.sh ]; then exec .agent-rules/hooks/format-kotlin.sh; fi"
        },
        {
          "type": "command",
          "command": "echo keep-me"
        }
      ]
    }
  ],
  "SubagentStop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "if [ -x .agent-rules/hooks/format-kotlin.sh ]; then exec .agent-rules/hooks/format-kotlin.sh; fi"
        }
      ]
    }
  ]
}
JSON

(
    cd "$CONSUMER"
    ./.agent-rules/install.sh
    ./.agent-rules/check.sh
)

grep -q 'references/database.md' "$CONSUMER/AGENTS.md"
grep -q 'references/code-generation.md' "$CONSUMER/AGENTS.md"
grep -q 'references/code-conventions.md' "$CONSUMER/AGENTS.md"
grep -q 'references/openapi.md' "$CONSUMER/AGENTS.md"
grep -q 'provider-adapter/SKILL.md' "$CONSUMER/AGENTS.md"
grep -q 'do not cross the provider boundary' "$CONSUMER/AGENTS.md"
cp "$CONSUMER/AGENTS.md" "$CONSUMER/AGENTS.common"
cmp "$CONSUMER/AGENTS.md" "$CONSUMER/CLAUDE.md"

jq -e '
  (has("Stop") | not) and
  (has("SubagentStop") | not) and
  ([.hooks.Stop[].hooks[]?.command | select(. == "echo keep-me")] | length == 1) and
  ([.hooks.Stop[].hooks[]?.command | select(contains("format-kotlin.sh"))] | length == 1) and
  ([.hooks.SubagentStop[].hooks[]?.command | select(contains("format-kotlin.sh"))] | length == 1)
' "$CONSUMER/.codex/hooks.json" >/dev/null

# Legacy profile selectors remain accepted but must not change task routing.
printf 'adapter\n' >"$CONSUMER/.agent-rules-profile"
(
    cd "$CONSUMER"
    ./.agent-rules/install.sh
    ./.agent-rules/check.sh
)
cmp "$CONSUMER/AGENTS.common" "$CONSUMER/AGENTS.md"

printf 'openapi\n' >"$CONSUMER/.agent-rules-profile"
(
    cd "$CONSUMER"
    ./.agent-rules/install.sh
    ./.agent-rules/check.sh
)
cmp "$CONSUMER/AGENTS.common" "$CONSUMER/AGENTS.md"

(
    cd "$CONSUMER"
    ./.agent-rules/install.sh --profile common
    ./.agent-rules/check.sh --profile adapter
)
cmp "$CONSUMER/AGENTS.common" "$CONSUMER/AGENTS.md"

sed -i.bak 's/# Shared agent guidance/# Shared agent guidance DRIFT/' "$CONSUMER/AGENTS.md"
rm -f "$CONSUMER/AGENTS.md.bak"
if (
    cd "$CONSUMER"
    ./.agent-rules/check.sh >/dev/null 2>&1
); then
    echo "check.sh did not detect managed guidance drift" >&2
    exit 1
fi

# A malformed managed block must fail closed before any project file is rewritten.
BROKEN="$TMP/broken"
mkdir -p "$BROKEN/.agent-rules"
(
    cd "$ROOT"
    tar --exclude=.git -cf - .
) | (
    cd "$BROKEN/.agent-rules"
    tar -xf -
)
git -C "$BROKEN" init -q
git -C "$BROKEN" config user.email test@example.invalid
git -C "$BROKEN" config user.name agent-rules-test
cat >"$BROKEN/AGENTS.md" <<'EOF_BROKEN'
local instructions before
<!-- BEGIN agent-rules -->
valuable local content that must not be truncated
EOF_BROKEN
cp "$BROKEN/AGENTS.md" "$BROKEN/AGENTS.before"
if (
    cd "$BROKEN"
    ./.agent-rules/install.sh >/dev/null 2>&1
); then
    echo "install.sh accepted a malformed managed block" >&2
    exit 1
fi
cmp "$BROKEN/AGENTS.before" "$BROKEN/AGENTS.md"
if [ -e "$BROKEN/.codex/hooks.json" ] || [ -e "$BROKEN/.claude/settings.json" ]; then
    echo "install.sh mutated hooks before rejecting a malformed managed block" >&2
    exit 1
fi

echo "agent-rules install tests passed"
