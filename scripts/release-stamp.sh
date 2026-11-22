#!/usr/bin/env bash
# Remember that `just release` passed, so publish-all can skip it on a resume.
#
#   scripts/release-stamp.sh record   # after release has built and checked everything
#   scripts/release-stamp.sh check    # exit 0 when nothing that ships has changed since
#
# The key is the content of VGraph and every engine consumer's checkout, uncommitted files
# included, not their commits: publish-plugins and `just mcp publish` commit each bump after
# the release, and that must not count as a change.
set -euo pipefail

STAMP=.build/release-passed

key() {
    local dir idx
    for dir in . obsidian-vithanco vscode-vithanco vgraph-mcp; do
        idx=$(mktemp)
        # -p: git trusts an index entry's timestamps only against the index's
        # own mtime, so a fresh copy hides an edit made in the same second.
        cp -p "$(git -C "$dir" rev-parse --absolute-git-dir)/index" "$idx" 2>/dev/null || :
        GIT_INDEX_FILE=$idx git -C "$dir" add -A
        echo "$dir $(GIT_INDEX_FILE=$idx git -C "$dir" write-tree)"
        rm -f "$idx"
    done
}

case "${1:-}" in
    record) mkdir -p .build && key > "$STAMP" ;;
    check) [ -f "$STAMP" ] && [ "$(key)" = "$(cat "$STAMP")" ] ;;
    *) echo "usage: $0 record|check" >&2; exit 2 ;;
esac
