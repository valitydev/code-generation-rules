#!/usr/bin/env bash
# Wires the shared rules into the project that mounts this submodule.
#
#   ./.agent-rules/install.sh            apply
#   ./.agent-rules/install.sh --check    report drift, write nothing, exit 1 on drift
#
# Everything here is idempotent and owns a bounded piece of each file: the hook
# entries it registered, and the text between the agent-rules markers. Whatever
# else the project keeps in CLAUDE.md, AGENTS.md or its agent settings is left
# untouched.

set -uo pipefail

RULES_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
BEGIN_MARKER="<!-- BEGIN agent-rules -->"
END_MARKER="<!-- END agent-rules -->"
HOOK_MARKER="format-kotlin.sh"

CHECK_ONLY=0
DRIFT=0

case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    "") ;;
    *)
        printf 'usage: %s [--check]\n' "$0" >&2
        exit 64
        ;;
esac

command -v jq >/dev/null 2>&1 || {
    printf 'agent-rules: jq is required\n' >&2
    exit 1
}

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'agent-rules: run this from inside the consuming git repository\n' >&2
    exit 1
}

case "$RULES_DIR" in
    "$PROJECT_ROOT"/*) ;;
    *)
        printf 'agent-rules: %s is not inside %s — run install.sh from the project that mounts it\n' \
            "$RULES_DIR" "$PROJECT_ROOT" >&2
        exit 1
        ;;
esac

report() {
    if [ "$CHECK_ONLY" -eq 1 ]; then
        printf 'drift: %s\n' "$1" >&2
        DRIFT=1
    else
        printf 'updated: %s\n' "$1"
    fi
}

# Writes $2 to $1 unless --check, in which case it only records the difference.
apply_file() {
    local path="$1" desired="$2" label="$3"

    if [ -f "$path" ] && [ "$(cat "$path")" = "$desired" ]; then
        return 0
    fi

    report "$label"
    [ "$CHECK_ONLY" -eq 1 ] && return 0

    mkdir -p "$(dirname -- "$path")"
    printf '%s\n' "$desired" >"$path"
}

# --- agent hook registration -------------------------------------------------

# Drops any previously registered entry for our hook, then appends the current
# one. That makes the merge both idempotent and self-healing when a project has
# edited the command by hand.
merge_hooks() {
    local target="$1" fragment="$2" root_path="$3" label="$4"
    local base desired

    base='{}'
    [ -f "$target" ] && base="$(cat "$target")"

    desired="$(printf '%s' "$base" | jq --slurpfile frag "$fragment" --arg marker "$HOOK_MARKER" --arg root "$root_path" '
        ($frag[0] | getpath($root | split(".") | map(select(length > 0)))) as $events
        | reduce ($events | keys[]) as $event (
            .;
            setpath(
                ($root | split(".") | map(select(length > 0))) + [$event];
                (
                    (getpath(($root | split(".") | map(select(length > 0))) + [$event]) // [])
                    | map(select([.hooks[]?.command // ""] | map(contains($marker)) | any | not))
                )
                + $events[$event]
            )
        )
    ')" || {
        printf 'agent-rules: failed to merge %s\n' "$target" >&2
        exit 1
    }

    # Compare normalized so that key order and indentation never look like drift.
    if [ -f "$target" ] &&
        [ "$(jq -S . "$target" 2>/dev/null)" = "$(printf '%s' "$desired" | jq -S .)" ]; then
        return 0
    fi

    report "$label"
    [ "$CHECK_ONLY" -eq 1 ] && return 0

    mkdir -p "$(dirname -- "$target")"
    printf '%s' "$desired" | jq . >"$target"
}

# --- markdown block sync -----------------------------------------------------

rule_files() {
    find "$RULES_DIR/rules" -maxdepth 1 -name '*.md' -not -name 'index.md' | sort
}

# Path of a rule file relative to the project root, e.g. .agent-rules/rules/x.md
rule_rel_path() {
    printf '%s' "${1#"$PROJECT_ROOT"/}"
}

claude_block_body() {
    printf '%s\n' "Shared organization rules, synced by .agent-rules/install.sh."
    printf '\n'
    rule_files | while IFS= read -r file; do
        printf '@%s\n' "$(rule_rel_path "$file")"
    done
}

agents_block_body() {
    printf '%s\n' "Shared organization rules, synced by .agent-rules/install.sh. Do not edit by hand."
    rule_files | while IFS= read -r file; do
        printf '\n'
        cat "$file"
    done
}

# Replaces the marked block in $1 with $2, keeping everything outside it. Creates
# the file, or appends the block, when either is missing.
render_with_block() {
    local path="$1" body="$2"
    local block existing

    block="$BEGIN_MARKER
$body
$END_MARKER"

    if [ ! -f "$path" ]; then
        printf '%s' "$block"
        return 0
    fi

    existing="$(cat "$path")"

    if ! printf '%s' "$existing" | grep -qF "$BEGIN_MARKER"; then
        printf '%s\n\n%s' "$existing" "$block"
        return 0
    fi

    BLOCK="$block" awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        index($0, begin) == 1 { print ENVIRON["BLOCK"]; skipping = 1; next }
        index($0, end) == 1 && skipping { skipping = 0; next }
        !skipping { print }
    ' "$path"
}

# --- run ---------------------------------------------------------------------

merge_hooks "$PROJECT_ROOT/.claude/settings.json" \
    "$RULES_DIR/agents/claude/settings.hooks.json" \
    "hooks" \
    ".claude/settings.json"

merge_hooks "$PROJECT_ROOT/.codex/hooks.json" \
    "$RULES_DIR/agents/codex/hooks.json" \
    "" \
    ".codex/hooks.json"

apply_file "$PROJECT_ROOT/CLAUDE.md" \
    "$(render_with_block "$PROJECT_ROOT/CLAUDE.md" "$(claude_block_body)")" \
    "CLAUDE.md"

apply_file "$PROJECT_ROOT/AGENTS.md" \
    "$(render_with_block "$PROJECT_ROOT/AGENTS.md" "$(agents_block_body)")" \
    "AGENTS.md"

if [ "$CHECK_ONLY" -eq 1 ] && [ "$DRIFT" -eq 1 ]; then
    printf '\nagent-rules: project has drifted from .agent-rules — run ./.agent-rules/install.sh\n' >&2
    exit 1
fi

exit 0
