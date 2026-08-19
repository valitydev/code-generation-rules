#!/usr/bin/env bash
# CI entry point: fails when the installed compact guidance/hook configuration drifts.
exec "$(cd -- "$(dirname -- "$0")" && pwd)/install.sh" --check "$@"
