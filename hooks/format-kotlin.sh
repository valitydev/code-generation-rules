#!/usr/bin/env bash
# Formats Kotlin sources touched during the turn.
#
# exit 0 — nothing to do or formatting/checking succeeded
# exit 2 — ktlint found violations it could not fix; stderr is returned to agent

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

hook_read_payload

REPO_ROOT="$(hook_repo_root)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0

CHANGED="$(hook_changed_files "$REPO_ROOT" '*.kt' '*.kts')"
[ -n "$CHANGED" ] || exit 0

hook_load_project_env "$REPO_ROOT"

maven_module_dirs() {
    printf '%s\n' "$CHANGED" | while IFS= read -r file; do
        [ -n "$file" ] || continue
        local dir
        dir="$(dirname -- "$REPO_ROOT/$file")"
        while [ "${#dir}" -ge "${#REPO_ROOT}" ]; do
            if [ -f "$dir/pom.xml" ]; then
                printf '%s\n' "$dir"
                break
            fi
            dir="$(dirname -- "$dir")"
        done
    done | sort -u
}

project_has_ktlint_maven() {
    find "$REPO_ROOT" -name pom.xml -not -path '*/target/*' -print0 2>/dev/null |
        xargs -0 grep -l 'ktlint-maven-plugin' 2>/dev/null |
        grep -q .
}

extract_violations() {
    local raw filtered
    raw="$(cat)"
    filtered="$(printf '%s\n' "$raw" | sed -n 's/^\[ERROR\] \(.*\.kts\{0,1\}:[0-9][0-9]*:[0-9][0-9]*: .*\)$/\1/p')"

    if [ -n "$filtered" ]; then
        printf '%s\n' "$filtered"
    else
        printf '%s\n' "$raw"
    fi
}

run_maven_ktlint() {
    local status=0
    local dirs dir output

    if ! command -v mvn >/dev/null 2>&1; then
        hook_log "agent-rules: ktlint hook skipped, mvn is not on PATH"
        return 0
    fi

    dirs="$(maven_module_dirs)"
    [ -n "$dirs" ] || return 0

    while IFS= read -r dir; do
        [ -n "$dir" ] || continue
        if ! output="$(cd "$dir" && mvn --batch-mode -q -Dstyle.color=never ktlint:format ktlint:check 2>&1)"; then
            status=1
            printf '%s\n' "$output" | extract_violations
        fi
    done <<EOF
$dirs
EOF

    return "$status"
}

if ! project_has_ktlint_maven; then
    exit 0
fi

if FAILURE="$(run_maven_ktlint)"; then
    exit 0
fi

MESSAGE="ktlint could not fix everything automatically. Fix the violations below before finishing:

$FAILURE"

if hook_should_block "$MESSAGE"; then
    hook_log "$MESSAGE"
    exit 2
fi

exit 0
