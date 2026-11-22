#!/usr/bin/env bash
# Every consumer that ships the engine publishes the build `just release` made,
# rather than building its own: one check says that build is still the one to ship.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

given_built() { # VGraph on origin/main, its engine built and copied into consumer/
    WORK=$(mktemp -d "$ROOT/work.XXXXXX") || exit 1
    mkdir -p "$WORK/Sources" "$WORK/website/Package" "$WORK/consumer"
    echo engine > "$WORK/Sources/engine.swift"
    printf '%s\n' '*.git/' website/Package/ consumer/ out err > "$WORK/.gitignore"
    git init -q --bare -b main "$WORK/vgraph.git"
    git -C "$WORK" init -q -b main
    git -C "$WORK" remote add origin "$WORK/vgraph.git"
    git -C "$WORK" add . && git -C "$WORK" commit -qm engine && git -C "$WORK" push -q origin main
    printf '\0asm\1\0\0\0' > "$WORK/website/Package/VGraphWasm.wasm"
    ( cd "$WORK" && "$REPO_ROOT/scripts/record-engine-build.sh" website/Package )
    cp "$WORK/website/Package/VGraphWasm.wasm" "$WORK/consumer/"
}
check() { ( cd "$WORK" && "$REPO_ROOT/scripts/check-engine-build.sh" "$@" ) >"$WORK/out" 2>"$WORK/err"; }

# Given a build of the current engine, when a consumer carries it, then the check
# passes and names the commit that built it.
given_built
check consumer || fail "a current build failed: $(cat "$WORK/err")"
[ "$(cat "$WORK/out")" = "$(git -C "$WORK" rev-parse HEAD)" ] || fail "does not print the build commit: $(cat "$WORK/out")"

# Given a version bump committed after the build, then the build still counts.
given_built
echo '{}' > "$WORK/plugins.json" && git -C "$WORK" add plugins.json && git -C "$WORK" commit -qm bump && git -C "$WORK" push -q origin main
check consumer || fail "a bump after the build failed: $(cat "$WORK/err")"

# Given an engine change after the build, then it fails and says to rebuild.
given_built
echo changed > "$WORK/Sources/engine.swift" && git -C "$WORK" commit -qam change && git -C "$WORK" push -q origin main
check consumer && fail "passed an engine built before the engine changed"
grep -q 'changed since' "$WORK/err" || fail "does not say the engine changed: $(cat "$WORK/err")"

# Given a consumer carrying another wasm, then it fails and names that copy.
given_built
printf '\0asm\1\0\0\0\2' > "$WORK/consumer/VGraphWasm.wasm"
check consumer && fail "passed a consumer carrying another engine"
grep -q 'consumer/VGraphWasm.wasm' "$WORK/err" || fail "does not name the mismatched copy: $(cat "$WORK/err")"

# Given no recorded build, then it fails and points at `just release`.
given_built
rm "$WORK/website/Package/VGRAPH_BUILD"
check consumer && fail "passed without a recorded build"
grep -q 'just release' "$WORK/err" || fail "does not point at 'just release': $(cat "$WORK/err")"

[ "$FAILED" -eq 0 ] && echo "✓ check-engine-build"
exit "$FAILED"
