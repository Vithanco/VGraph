#!/usr/bin/env bash
# A generated file regenerated only at release time left a stale copy on main,
# and the release stopped on the uncommitted change it made. Checked on every
# change, the pull request that makes it stale fails instead.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

given_generated() { # committed tools.json holding $1; the generator now writes $2
    WORK=$(mktemp -d "$ROOT/work.XXXXXX") || exit 1
    mkdir -p "$WORK/scripts" "$WORK/vgraph-mcp-node"
    printf '#!/bin/sh\necho %s > vgraph-mcp-node/tools.json\n' "$2" > "$WORK/scripts/dump-mcp-tools.sh"
    chmod +x "$WORK/scripts/dump-mcp-tools.sh"
    echo "$1" > "$WORK/vgraph-mcp-node/tools.json"
    git -C "$WORK" init -q -b main && git -C "$WORK" add . && git -C "$WORK" commit -qm init
}
check() { ( cd "$WORK" && "$REPO_ROOT/scripts/check-generated.sh" "$@" ) >"$WORK/out" 2>&1; }

# Given the committed file is what the generator writes, then the check passes.
given_generated '[decompose]' '[decompose]'
check || fail "up-to-date file failed: $(cat "$WORK/out")"

# Given a tool added without regenerating, then the check fails and says how to fix it.
given_generated '[]' '[decompose]'
check && fail "stale file passed"
grep -q 'vgraph-mcp-node/tools.json' "$WORK/out" || fail "does not name the stale file: $(cat "$WORK/out")"
grep -q 'just regen' "$WORK/out" || fail "does not say how to fix it: $(cat "$WORK/out")"

# Given unrelated uncommitted work, then the check still passes.
given_generated '[decompose]' '[decompose]'
echo wip > "$WORK/notes.md"
check || fail "unrelated uncommitted work failed: $(cat "$WORK/out")"

# Given --write, then the file is regenerated and nothing fails.
given_generated '[]' '[decompose]'
check --write || fail "--write failed: $(cat "$WORK/out")"
grep -q decompose "$WORK/vgraph-mcp-node/tools.json" || fail "--write did not regenerate"

exit "$FAILED"
