#!/usr/bin/env bash
# Installs compact agent routing and deterministic hooks into a consuming repository.
# Detailed references and skills stay in .agent-rules and are loaded only when needed.

set -uo pipefail

RULES_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
BEGIN_MARKER="<!-- BEGIN agent-rules -->"
END_MARKER="<!-- END agent-rules -->"
HOOK_MARKER="format-kotlin.sh"

CHECK_ONLY=0
DRIFT=0
PROFILE_OVERRIDE=""

usage() {
    printf 'usage: %s [--check] [--profile common|openapi|adapter]\n' "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --profile)
            case "${2:-}" in
                ""|--*)
                    printf 'agent-rules: --profile requires a value\n' >&2
                    usage
                    exit 64
                    ;;
            esac
            PROFILE_OVERRIDE="$2"
            shift 2
            ;;
        *)
            printf 'agent-rules: unknown argument: %s\n' "$1" >&2
            usage
            exit 64
            ;;
    esac
done

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
        printf 'agent-rules: %s is not inside %s — mount it inside the consuming project\n' \
            "$RULES_DIR" "$PROJECT_ROOT" >&2
        exit 1
        ;;
esac

PROFILE="common"
PROFILE_FILE="$PROJECT_ROOT/.agent-rules-profile"

if [ -f "$PROFILE_FILE" ]; then
    PROFILE="$(tr -d '\r\n' <"$PROFILE_FILE")"
fi
if [ -n "$PROFILE_OVERRIDE" ]; then
    PROFILE="$PROFILE_OVERRIDE"
fi

case "$PROFILE" in
    common|openapi|adapter) ;;
    "")
        printf 'agent-rules: profile in %s is empty\n' "$PROFILE_FILE" >&2
        exit 64
        ;;
    *)
        printf 'agent-rules: unknown profile: %s\n' "$PROFILE" >&2
        printf 'agent-rules: expected common, openapi, or adapter\n' >&2
        exit 64
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

normalize_legacy_codex_hooks() {
    local base="$1"

    # Older revisions of this repository wrote Stop/SubagentStop at the JSON root.
    # Current Codex expects events under the top-level "hooks" object. Move the
    # complete legacy groups so unrelated user hooks are preserved as well.
    printf '%s' "$base" | jq '
        reduce ["Stop", "SubagentStop"][] as $event (
            .;
            if (.[$event]? | type) == "array" then
                .hooks = (.hooks // {})
                | .hooks[$event] = ((.hooks[$event] // []) + .[$event])
                | del(.[$event])
            else
                .
            end
        )
    '
}

merge_hooks() {
    local target="$1" fragment="$2" root_path="$3" label="$4" migrate_legacy="${5:-0}"
    local base desired

    base='{}'
    [ -f "$target" ] && base="$(cat "$target")"

    if [ "$migrate_legacy" -eq 1 ]; then
        base="$(normalize_legacy_codex_hooks "$base")" || {
            printf 'agent-rules: failed to normalize legacy hooks in %s\n' "$target" >&2
            exit 1
        }
    fi

    desired="$(printf '%s' "$base" | jq --slurpfile frag "$fragment" --arg marker "$HOOK_MARKER" --arg root "$root_path" '
        def without_marker($marker):
            map(
                if (.hooks? | type) == "array" then
                    .hooks |= map(select((((.command // "") | contains($marker))) | not))
                else
                    .
                end
            )
            | map(select((.hooks? // []) | length > 0));

        ($frag[0] | getpath($root | split(".") | map(select(length > 0)))) as $events
        | reduce ($events | keys[]) as $event (
            .;
            setpath(
                ($root | split(".") | map(select(length > 0))) + [$event];
                (
                    (getpath(($root | split(".") | map(select(length > 0))) + [$event]) // [])
                    | without_marker($marker)
                )
                + $events[$event]
            )
        )
    ')" || {
        printf 'agent-rules: failed to merge %s\n' "$target" >&2
        exit 1
    }

    if [ -f "$target" ] &&
        [ "$(jq -S . "$target" 2>/dev/null)" = "$(printf '%s' "$desired" | jq -S .)" ]; then
        return 0
    fi

    report "$label"
    [ "$CHECK_ONLY" -eq 1 ] && return 0

    mkdir -p "$(dirname -- "$target")"
    printf '%s' "$desired" | jq . >"$target"
}

routing_body() {
    cat "$RULES_DIR/guidance/core.md"

    cat <<'EOF'

## Load targeted guidance only when relevant

- Database/schema/repository/transaction work: read `.agent-rules/references/database.md`.
- Generated-source or Protobuf work: read `.agent-rules/references/code-generation.md`.
- Cross-layer architecture/client/converter decisions not settled by local code: consult
  `.agent-rules/references/code-conventions.md`.
EOF

    case "$PROFILE" in
        openapi)
            cat <<'EOF'
- OpenAPI contract/generation work: read `.agent-rules/references/openapi.md`.
EOF
            ;;
        adapter)
            cat <<'EOF'
- External provider/payment-adapter work: read
  `.agent-rules/skills/provider-adapter/SKILL.md` and follow its progressive-disclosure
  workflow.
EOF
            ;;
    esac
}

validate_managed_block() {
    local path="$1"

    [ -f "$path" ] || return 0

    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        index($0, begin) == 1 {
            begin_count++
            if (end_count > 0) invalid = 1
            next
        }
        index($0, end) == 1 {
            end_count++
            if (begin_count == 0) invalid = 1
        }
        END {
            if (begin_count == 0 && end_count == 0) exit 0
            if (begin_count == 1 && end_count == 1 && !invalid) exit 0
            exit 1
        }
    ' "$path" || {
        printf 'agent-rules: malformed managed block in %s; expected one BEGIN marker followed by one END marker\n' \
            "$path" >&2
        return 1
    }
}

render_with_block() {
    local path="$1" body="$2"
    local block existing

    validate_managed_block "$path" || return 1

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

sync_markdown_file() {
    local path="$1" body="$2" label="$3" desired

    desired="$(render_with_block "$path" "$body")" || exit 1
    apply_file "$path" "$desired" "$label"
}

# Refuse malformed managed blocks before touching any project file. This keeps a
# missing/duplicated marker from turning a bounded sync into destructive truncation.
validate_managed_block "$PROJECT_ROOT/CLAUDE.md" || exit 1
validate_managed_block "$PROJECT_ROOT/AGENTS.md" || exit 1

merge_hooks "$PROJECT_ROOT/.claude/settings.json" \
    "$RULES_DIR/agents/claude/settings.hooks.json" \
    "hooks" \
    ".claude/settings.json"

merge_hooks "$PROJECT_ROOT/.codex/hooks.json" \
    "$RULES_DIR/agents/codex/hooks.json" \
    "hooks" \
    ".codex/hooks.json" \
    1

BODY="$(routing_body)"

sync_markdown_file "$PROJECT_ROOT/CLAUDE.md" "$BODY" "CLAUDE.md"
sync_markdown_file "$PROJECT_ROOT/AGENTS.md" "$BODY" "AGENTS.md"

if [ "$CHECK_ONLY" -eq 1 ] && [ "$DRIFT" -eq 1 ]; then
    printf '\nagent-rules: project has drifted from .agent-rules — run ./.agent-rules/install.sh\n' >&2
    exit 1
fi

exit 0
