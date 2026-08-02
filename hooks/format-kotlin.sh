#!/usr/bin/env bash
# Formats Kotlin sources touched during the turn.
#
# Wired to the Stop event of Claude Code and Codex alike: both hand the hook a
# JSON event on stdin, and both read exit code 2 with stderr as text to give
# back to the model. So one script serves both.
#
# Contract:
#   exit 0 — nothing to do, or everything formatted cleanly
#   exit 2 — ktlint found violations it cannot fix; stderr goes back to the agent
#
# It never fails the session for its own reasons: no Kotlin changes, no ktlint,
# no maven, no repository — all of these exit 0. Written against bash 3.2, which
# is still what ships with macOS.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

hook_read_payload

REPO_ROOT="$(hook_repo_root)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0

CHANGED="$(hook_changed_files "$REPO_ROOT" '*.kt' '*.kts')"
# The common case is a turn that touched no Kotlin. Leave before paying for a JVM.
[ -n "$CHANGED" ] || exit 0

hook_load_project_env "$REPO_ROOT"

# Resolves the module directories to format: for each changed file, the nearest
# ancestor holding a pom.xml. A leaf module inherits the plugin from its parent,
# so running there is enough.
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

# Keeps the ktlint violation lines and drops maven's own failure boilerplate and
# JVM warnings, so the agent gets the findings rather than a wall of noise. Falls
# back to the raw output if the run failed for some reason other than lint.
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
    # No subshell below: the loop is fed by a heredoc precisely so that a
    # failure inside it survives into the return value.
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
        # Both goals in one invocation: format is silent about what it cannot
        # fix — only check reports that — and a single mvn run means a single JVM.
        if ! output="$(cd "$dir" && mvn --batch-mode -q -Dstyle.color=never ktlint:format ktlint:check 2>&1)"; then
            status=1
            printf '%s\n' "$output" | extract_violations
        fi
    done <<EOF
$dirs
EOF

    return "$status"
}

# The runner is picked per project. Adding Gradle or the standalone CLI later
# means adding a branch here, not touching anything else.
if ! project_has_ktlint_maven; then
    # Plenty of repositories mount this submodule without being Kotlin projects.
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
