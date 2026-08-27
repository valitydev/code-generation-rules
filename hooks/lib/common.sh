#!/usr/bin/env bash
# Shared helpers for agent lifecycle hooks.
#
# Hooks run inside a coding session. Unexpected hook/environment conditions should
# not break the session; deterministic findings from a check may still be returned
# to the agent.

HOOK_PAYLOAD=""
HOOK_SESSION_ID=""
HOOK_CWD=""
HOOK_STOP_ACTIVE="false"

hook_log() {
    printf '%s\n' "$*" >&2
}

hook_read_payload() {
    HOOK_PAYLOAD="$(cat)"
    [ -n "$HOOK_PAYLOAD" ] || return 0

    if command -v jq >/dev/null 2>&1; then
        IFS=$'\t' read -r HOOK_SESSION_ID HOOK_CWD HOOK_STOP_ACTIVE <<EOF
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

hook_repo_root() {
    local dir="${HOOK_CWD:-$PWD}"
    [ -d "$dir" ] || dir="$PWD"
    git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}

hook_load_project_env() {
    local env_file="$1/.agent-rules.env"
    [ -f "$env_file" ] || return 0
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
}

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
