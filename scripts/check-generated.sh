#!/usr/bin/env bash
# Regenerate every tracked file the build generates, and fail if that changed one.
#
#   scripts/check-generated.sh           # in CI and `just test`: stale means fail
#   scripts/check-generated.sh --write   # `just regen`: just regenerate
#
# Generated files used to be refreshed only by the release, which then found
# them uncommitted and stopped. Checked on every change, the pull request that
# makes one stale fails instead. Expects the binaries the generators ask to be
# built already.
set -euo pipefail

regenerate() {
    ./scripts/dump-mcp-tools.sh >/dev/null
}

if [ "${1:-}" = --write ]; then
    regenerate
    exit
fi

# Compare the working tree before and after, so unrelated uncommitted work and
# a file already regenerated but not yet committed both pass.
state() { git status --porcelain=v1 --untracked-files=all | while read -r _ f; do
    printf '%s %s\n' "$f" "$(git hash-object "$f" 2>/dev/null || echo gone)"; done; }
BEFORE=$(state)
regenerate
CHANGED=$( (diff <(echo "$BEFORE") <(state) || :) | sed -n 's/^> \([^ ]*\) .*/\1/p' | sort -u)
if [ -n "$CHANGED" ]; then
    echo "Generated files are out of date:" >&2
    echo "$CHANGED" | sed 's/^/  /' >&2
    echo "Run 'just regen' and commit them." >&2
    exit 1
fi
