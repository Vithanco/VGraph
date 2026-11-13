#!/usr/bin/env bash
# `just plugins-release` only decides the next version: `just release` builds
# what ships, so a build here was thrown away. Its VGraph half reaches main
# through a PR, so it commits that half and opens the PR rather than leaving
# changes that `just release` then refuses.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

mkdir "$ROOT/bin"
cat > "$ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
EOF
chmod +x "$ROOT/bin/gh"
export PATH="$ROOT/bin:$PATH"
export VITHANCO_MAINTAINER=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

# A consumer's release.sh that only accepts being asked to bump: anything else
# would build, and the log says what it was asked.
stub_release_sh() { # dir
    cat > "$1/release.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$(basename "$PWD") $*" >> "$RELEASE_LOG"
[[ " $* " == *" --bump-only "* ]] || { echo "release.sh asked to build" >&2; exit 1; }
CURRENT=$(node -p "require('./package.json').version")
NEW=$(node -p "const [a,b,c]='$CURRENT'.split('.').map(Number); [a,b,c+1].join('.')")
node -e "const fs=require('fs');const j=require('./package.json');j.version='$NEW';fs.writeFileSync('package.json',JSON.stringify(j)+'\n')"
[ ! -f manifest.json ] || cp package.json manifest.json
EOF
    chmod +x "$1/release.sh"
}

given_everything_at() { # version, in a fresh WORK standing in for a merged VGraph
    WORK=$(mktemp -d "$ROOT/work.XXXXXX") || exit 1
    export GH_LOG="$WORK/gh.log" RELEASE_LOG="$WORK/release.log"
    : > "$GH_LOG"; : > "$RELEASE_LOG"
    cp "$REPO_ROOT/release-plugins.sh" "$WORK/"
    printf '#!/bin/sh\necho built >> "%s/built.log"\n' "$WORK" > "$WORK/build-wasm.sh"
    chmod +x "$WORK/build-wasm.sh"
    for p in obsidian-vithanco vscode-vithanco; do
        git init -q --bare -b main "$WORK/$p.git"
        git init -q -b main "$WORK/$p"
        git -C "$WORK/$p" remote add origin "$WORK/$p.git"
        printf '{"version":"%s"}\n' "$1" > "$WORK/$p/package.json"
        stub_release_sh "$WORK/$p"
        git -C "$WORK/$p" add . && git -C "$WORK/$p" commit -qm "at $1"
    done
    cp "$WORK/obsidian-vithanco/package.json" "$WORK/obsidian-vithanco/manifest.json"
    git -C "$WORK/obsidian-vithanco" add . && git -C "$WORK/obsidian-vithanco" commit -qm manifest
    mkdir "$WORK/vgraph-mcp-node"
    printf '{"version":"%s"}\n' "$1" > "$WORK/vgraph-mcp-node/package.json"
    stub_release_sh "$WORK/vgraph-mcp-node"
    printf '{"plugins":[{"path":"obsidian-vithanco","version":"%s"},{"path":"vscode-vithanco","version":"%s"},{"path":"vgraph-mcp-node","version":"%s"}]}\n' \
        "$1" "$1" "$1" > "$WORK/plugins.json"
    printf '%s\n' '*.git/' obsidian-vithanco/ vscode-vithanco/ out gh.log release.log built.log > "$WORK/.gitignore"
    git init -q --bare -b main "$WORK/vgraph.git"
    git -C "$WORK" init -q -b main
    git -C "$WORK" remote add origin "$WORK/vgraph.git"
    git -C "$WORK" add . && git -C "$WORK" commit -qm "at $1"
    git -C "$WORK" push -q origin main
}
bump() { just --justfile "$REPO_ROOT/justfile" --working-directory "$WORK" plugins-release "$@" >"$WORK/out" 2>&1; }
nothing_bumped() { # why
    [ -s "$RELEASE_LOG" ] && fail "$1: a consumer was bumped: $(cat "$RELEASE_LOG")"
    git -C "$WORK/vgraph.git" rev-parse -q --verify refs/heads/release/1.2.4 >/dev/null && fail "$1: a release branch was pushed"
    grep -q '^pr create' "$GH_LOG" && fail "$1: a PR was opened"
}

# Given every consumer at 1.2.3 and VGraph merged, when bumping a patch, then
# every consumer is bumped without building anything, VGraph's half is committed
# on release/1.2.4, pushed and offered as a PR, and the checkout is back on main, clean.
given_everything_at 1.2.3
bump patch || fail "plugins-release patch failed: $(cat "$WORK/out")"
[ "$(wc -l < "$RELEASE_LOG" | tr -d ' ')" = 3 ] || fail "wanted all three consumers bumped: $(cat "$RELEASE_LOG")"
[ -f "$WORK/built.log" ] && fail "plugins-release built the engine"
git -C "$WORK/vgraph.git" show release/1.2.4:plugins.json 2>/dev/null | grep -q '1.2.4' \
    || fail "release/1.2.4 on origin does not carry the bumped plugins.json"
git -C "$WORK/vgraph.git" show release/1.2.4:vgraph-mcp-node/package.json 2>/dev/null | grep -q '1.2.4' \
    || fail "release/1.2.4 on origin does not carry the bumped vgraph-mcp-node"
grep -q '^pr create.*release/1.2.4' "$GH_LOG" || fail "no PR opened for release/1.2.4: $(cat "$GH_LOG")"
[ "$(git -C "$WORK" branch --show-current)" = main ] || fail "left VGraph on $(git -C "$WORK" branch --show-current)"
[ -z "$(git -C "$WORK" status --porcelain)" ] || fail "left VGraph dirty: $(git -C "$WORK" status --porcelain)"
grep -q 'just release' "$WORK/out" || fail "does not say 'just release' comes next: $(cat "$WORK/out")"

# Given an explicit version, when bumping, then the branch is named after it.
given_everything_at 1.2.3
bump 2.0.0 || fail "plugins-release 2.0.0 failed: $(cat "$WORK/out")"
grep -q -- '--bump-only 2.0.0' "$RELEASE_LOG" || fail "consumers were not asked for 2.0.0: $(cat "$RELEASE_LOG")"

# Given VGraph with uncommitted changes, when bumping, then nothing is bumped:
# the commit would sweep them into the release PR.
given_everything_at 1.2.3
echo 'change' > "$WORK/stray.txt"
bump patch && fail "bumped over an uncommitted VGraph"
grep -q 'uncommitted' "$WORK/out" || fail "does not say VGraph is uncommitted: $(cat "$WORK/out")"
nothing_bumped "uncommitted VGraph"

# Given a VGraph commit not on origin/main, when bumping, then nothing is bumped:
# the release PR would carry that commit along.
given_everything_at 1.2.3
git -C "$WORK" commit -qm "local only" --allow-empty
bump patch && fail "bumped on top of a commit that is not on origin/main"
grep -q 'origin/main' "$WORK/out" || fail "does not name origin/main: $(cat "$WORK/out")"
nothing_bumped "unpushed VGraph"

# The real consumers' release.sh, asked only to bump: the version moves and
# nothing is built, installed or copied in. Skips a plugin that is not cloned.
REAL=$(mktemp -d "$ROOT/real.XXXXXX") || exit 1
cat > "$ROOT/bin/npm" <<'EOF'
#!/bin/sh
echo "npm $*" >> "$TOOL_LOG"; exit 1
EOF
cp "$ROOT/bin/npm" "$ROOT/bin/npx" && sed -i.bak 's/npm \$\*/npx $*/' "$ROOT/bin/npx"
chmod +x "$ROOT/bin/npm" "$ROOT/bin/npx"
export TOOL_LOG="$REAL/tools.log"
mkdir -p "$REAL/website/Package" "$REAL/fonts"
printf '\0asm' > "$REAL/website/Package/VGraphWasm.wasm"
cp "$REPO_ROOT/LICENSE" "$REPO_ROOT/NOTICE" "$REAL/"
for spec in "obsidian-vithanco:manifest.json package.json versions.json scripts/set-version.mjs" \
            "vscode-vithanco:package.json" \
            "vgraph-mcp-node:package.json server.json"; do
    p=${spec%%:*}
    [ -f "$REPO_ROOT/$p/release.sh" ] || { echo "· skipping $p: not cloned"; continue; }
    mkdir -p "$REAL/$p/scripts"
    for f in release.sh ${spec#*:}; do cp "$REPO_ROOT/$p/$f" "$REAL/$p/$f"; done
    : > "$TOOL_LOG"
    ( cd "$REAL/$p" && VGRAPH_REPO="$REAL" ./release.sh --bump-only 9.8.7 ) >"$REAL/out" 2>&1 \
        || fail "$p: release.sh --bump-only failed: $(cat "$REAL/out")"
    [ "$(node -p "require('$REAL/$p/package.json').version")" = 9.8.7 ] || fail "$p: package.json was not bumped"
    [ -s "$TOOL_LOG" ] && fail "$p: bump-only ran $(cat "$TOOL_LOG")"
    [ -e "$REAL/$p/VGraphWasm.wasm" ] && fail "$p: bump-only copied the engine in"
    [ -e "$REAL/$p/vendor" ] && fail "$p: bump-only vendored the engine"
done

[ "$FAILED" -eq 0 ] && echo "✓ plugins-release"
exit "$FAILED"
