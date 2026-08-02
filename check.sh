#!/usr/bin/env bash
# CI entry point: fails when the project has drifted from the rules it pins.
exec "$(cd -- "$(dirname -- "$0")" && pwd)/install.sh" --check
