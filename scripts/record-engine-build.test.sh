#!/usr/bin/env bash
# build-wasm.sh replaces website/Package on every build, so the record of which
# commit built it has to be written by the build itself, or a later build leaves
# publish-plugins with no record, or a stale one.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/record-engine-build.sh"
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

cd "$ROOT"
git init -q -b main
echo '/website/Package' > .gitignore
mkdir -p Sources website/Package
echo 'engine' > Sources/engine.swift
printf '\0asm\1\0\0\0' > website/Package/VGraphWasm.wasm
git add . && git commit -qm engine
SUM=$(shasum -a 256 < website/Package/VGraphWasm.wasm | cut -d' ' -f1)

# Given a clean checkout, when recording, then the record is the commit and the wasm's hash.
"$SCRIPT" website/Package || fail "recording a clean build failed"
[ "$(cat website/Package/VGRAPH_BUILD)" = "$(git rev-parse HEAD) $SUM" ] \
    || fail "clean record is '$(cat website/Package/VGRAPH_BUILD)'"

# Given uncommitted engine changes, when recording, then the commit is marked dirty.
echo 'changed' > Sources/engine.swift
"$SCRIPT" website/Package || fail "recording a dirty build failed"
[ "$(cat website/Package/VGRAPH_BUILD)" = "$(git rev-parse HEAD)-dirty $SUM" ] \
    || fail "dirty record is '$(cat website/Package/VGRAPH_BUILD)'"

# Given a build whose source git cannot name (no repository, or one git refuses to
# read, as CI containers do for a checkout owned by another user), when recording,
# then the build still succeeds and records the commit as unknown.
NOGIT=$(mktemp -d "$ROOT/nogit.XXXXXX")
mkdir -p "$NOGIT/website/Package" && cp website/Package/VGraphWasm.wasm "$NOGIT/website/Package/"
( cd "$NOGIT" && GIT_CEILING_DIRECTORIES="$ROOT" "$SCRIPT" website/Package ) || fail "recording without a readable repository failed the build"
[ "$(cat "$NOGIT/website/Package/VGRAPH_BUILD")" = "unknown $SUM" ] \
    || fail "record without a repository is '$(cat "$NOGIT/website/Package/VGRAPH_BUILD")'"

[ "$FAILED" -eq 0 ] && echo "✓ record-engine-build"
exit "$FAILED"
