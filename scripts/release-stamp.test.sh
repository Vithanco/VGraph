#!/usr/bin/env bash
# `just release` takes long, and publish-all ran it again on every resume, so a
# registry timeout cost a full test run. The stamp lets a resume skip it while
# what would ship is unchanged.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

given_released() { # VGraph with every engine consumer, their bump uncommitted, stamp recorded
    WORK=$(mktemp -d "$ROOT/work.XXXXXX") || exit 1
    git -C "$WORK" init -q -b main
    printf '%s\n' .build/ obsidian-vithanco/ vscode-vithanco/ vgraph-mcp/ > "$WORK/.gitignore"
    echo engine > "$WORK/engine.swift"
    git -C "$WORK" add . && git -C "$WORK" commit -qm engine
    for p in obsidian-vithanco vscode-vithanco vgraph-mcp; do
        git -C "$WORK" init -q -b main "$p"
        echo main.js > "$WORK/$p/.gitignore"
        echo '{"version":"1.0.0"}' > "$WORK/$p/package.json"
        git -C "$WORK/$p" add . && git -C "$WORK/$p" commit -qm init
        echo '{"version":"1.0.1"}' > "$WORK/$p/package.json"
    done
    stamp record || fail "could not record: $(cat "$WORK/out")"
}
stamp() { ( cd "$WORK" && "$REPO_ROOT/scripts/release-stamp.sh" "$@" ) >"$WORK/out" 2>&1; }

# Given nothing changed since the release, when checking, then it still holds.
given_released
stamp check || fail "nothing changed, but the stamp does not hold"

# Given no release recorded, when checking, then it does not hold.
given_released
rm -rf "$WORK/.build"
stamp check && fail "holds with no release recorded"

# Given the plugins' bump committed by publish-plugins, when resuming, then it still holds.
given_released
for p in obsidian-vithanco vscode-vithanco vgraph-mcp; do git -C "$WORK/$p" commit -qam "chore: release 1.0.1"; done
stamp check || fail "committing the released bump broke the stamp"

# Given build output a release writes, when checking, then it still holds.
given_released
echo bundle > "$WORK/obsidian-vithanco/main.js"
stamp check || fail "an ignored build output broke the stamp"

# Given an engine change, when checking, then it does not hold.
given_released
echo changed > "$WORK/engine.swift"
stamp check && fail "holds after the engine changed"

# Given a new file in a plugin, when checking, then it does not hold.
given_released
echo new > "$WORK/vscode-vithanco/extra.ts"
stamp check && fail "holds after a plugin gained a file"

# Given an MCP server change, when checking, then it does not hold.
given_released
echo new > "$WORK/vgraph-mcp/Tool.swift"
stamp check && fail "holds after vgraph-mcp gained a file"

# Given a new VGraph commit, when checking, then it does not hold.
given_released
echo next > "$WORK/next.swift" && git -C "$WORK" add next.swift && git -C "$WORK" commit -qm next
stamp check && fail "holds after a new commit"

# Given a check, when it runs, then neither repository's index is touched.
given_released
echo staged > "$WORK/engine.swift"
stamp check
[ -z "$(git -C "$WORK" diff --cached --name-only)" ] || fail "checking staged changes"

exit "$FAILED"
