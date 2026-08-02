#!/usr/bin/env bash
# Shared helpers for agent lifecycle hooks.
#
# Hooks run inside somebody's coding session. The overriding rule for everything
# here: never break the session. Anything unexpected means "exit 0 quietly", not
# "fail loudly".

HOOK_PAYLOAD=""
HOOK_SESSION_ID=""
HOOK_CWD=""
HOOK_STOP_ACTIVE="false"

hook_log() {
    printf '%s\n' "$*" >&2
}

# Reads the event JSON from stdin and populates HOOK_* variables.
#
# jq is used when available; the fallback covers the two scalar fields we
# actually need, so a machine without jq still gets a working hook.
hook_read_payload() {
    HOOK_PAYLOAD="$(cat)"
    [ -n "$HOOK_PAYLOAD" ] || return 0

    if command -v jq >/dev/null 2>&1; then
        # One jq for all three fields: this runs on every turn, so the process
        # spawns are worth counting.
        IFS='	' read -r HOOK_SESSION_ID HOOK_CWD HOOK_STOP_ACTIVE <<EOF
$(printf '%s' "$HOOK_PAYLOAD" | jq -r '[.session_id // "", .cwd // "", (.stop_hook_active // false | tostring)] | @tsv' 2>/dev/null)
EOF
    else
        HOOK_SESSION_ID="$(hook_scalar_fallback session_id)"
        HOOK_CWD="$(hook_scalar_fallback cwd)"
        case "$HOOK_PAYLOAD" in
            *'"stop_hook_active"'*'true'*) HOOK_STOP_ACTIVE="true" ;;
        esac
    fi

    [ "$HOOK_STOP_ACTIVE" = "true" ] || HOOK_STOP_ACTIVE="false"
}

hook_scalar_fallback() {
    printf '%s' "$HOOK_PAYLOAD" |
        tr ',' '\n' |
        sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" |
        head -n 1
}

# Echoes the repository root, or returns non-zero when there is no repository.
hook_repo_root() {
    local dir="${HOOK_CWD:-$PWD}"
    [ -d "$dir" ] || dir="$PWD"
    git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}

# Projects declare their own build environment (JAVA_HOME, locale) here. The
# file belongs to the project; this repository only agrees to read it.
hook_load_project_env() {
    local env_file="$1/.agent-rules.env"
    [ -f "$env_file" ] || return 0
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
}

# Echoes working-tree files matching the given globs, one per line, relative to
# the repository root: everything changed against HEAD plus untracked files.
# Build and generated output is filtered out.
hook_changed_files() {
    local root="$1"
    shift

    {
        if git -C "$root" rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
            git -C "$root" diff --name-only --diff-filter=ACMR HEAD -- "$@"
        else
            git -C "$root" diff --name-only --diff-filter=ACMR --cached -- "$@"
        fi
        git -C "$root" ls-files --others --exclude-standard -- "$@"
    } 2>/dev/null | sort -u | while IFS= read -r file; do
        case "$file" in
            target/* | */target/* | build/* | */build/* | out/* | */out/*) continue ;;
            _generated/* | */_generated/* | */generated-sources/*) continue ;;
        esac
        [ -f "$root/$file" ] || continue
        printf '%s\n' "$file"
    done
}

# Loop guard for hooks that block on Stop.
#
# Blocking makes the agent run again, which fires Stop again. The agent's own
# stop_hook_active flag covers Claude Code; this covers the general case by
# refusing to block twice in a row on an identical message.
hook_should_block() {
    local message="$1"
    local state_dir="${TMPDIR:-/tmp}/agent-rules-hooks"
    local key="${HOOK_SESSION_ID:-nosession}"
    local state_file
    local digest

    [ "$HOOK_STOP_ACTIVE" = "true" ] && return 1

    key="$(printf '%s' "$key" | tr -c 'A-Za-z0-9_.-' '_')"
    state_file="$state_dir/$key.last"
    digest="$(printf '%s' "$message" | cksum | tr -d ' \n')"

    if [ -f "$state_file" ] && [ "$(cat "$state_file" 2>/dev/null)" = "$digest" ]; then
        return 1
    fi

    mkdir -p "$state_dir" 2>/dev/null || return 1
    printf '%s' "$digest" >"$state_file" 2>/dev/null || return 1
    return 0
}
