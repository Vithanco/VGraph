#!/usr/bin/env bash
# The bump can already be committed on a plugin's main, leaving nothing to
# commit. `git commit` then exits non-zero and `set -e` stops the recipe, which
# used to leave the Obsidian plugin published and the VS Code one not.
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
[ "$1 $2" != "release view" ] # no release exists yet; everything else succeeds
EOF
chmod +x "$ROOT/bin/gh"
# The Marketplace is never reached: npx stands in for vsce, and the keychain
# lookup always misses, so only VSCE_PAT below decides whether a credential exists.
cat > "$ROOT/bin/npx" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$NPX_LOG"
case "$1 $2" in
    "vsce show") [ -n "${MARKETPLACE_VERSION:-}" ] || exit 1
                 printf '{"versions":[{"version":"%s"}]}\n' "$MARKETPLACE_VERSION" ;;
    "vsce verify-pat") exit 1 ;;
esac
EOF
printf '#!/bin/sh\nexit 1\n' > "$ROOT/bin/security"
chmod +x "$ROOT/bin/npx" "$ROOT/bin/security"
export PATH="$ROOT/bin:$PATH"
unset VSCE_PAT MARKETPLACE_VERSION
export VITHANCO_MAINTAINER=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

given_plugins_at() { # version, in a fresh directory WORK with pushed plugin repos
    WORK=$(mktemp -d "$ROOT/work.XXXXXX") || exit 1
    export GH_LOG="$WORK/gh.log" NPX_LOG="$WORK/npx.log"
    : > "$GH_LOG"; : > "$NPX_LOG"
    mkdir -p "$WORK/website/Package" "$WORK/scripts"
    cp "$REPO_ROOT/scripts/check-wasm-optimized.sh" "$REPO_ROOT/scripts/vscode-marketplace.sh" "$WORK/scripts/"
    printf '\0asm\1\0\0\0' > "$WORK/website/Package/VGraphWasm.wasm"
    for p in obsidian-vithanco vscode-vithanco; do
        git init -q --bare -b main "$WORK/$p.git"
        git init -q -b main "$WORK/$p"
        git -C "$WORK/$p" remote add origin "$WORK/$p.git"
        printf '\0asm\1\0\0\0' > "$WORK/$p/VGraphWasm.wasm"
        printf '{"version":"%s"}\n' "$1" | tee "$WORK/$p/manifest.json" > "$WORK/$p/package.json"
        echo '{}' > "$WORK/$p/versions.json"
        echo > "$WORK/$p/styles.css"
    done
    echo 'VGraphWasm.wasm' > "$WORK/vscode-vithanco/.gitignore"
    rm "$WORK/vscode-vithanco/manifest.json"
    printf '{"name":"vithanco","publisher":"vithanco","version":"%s"}\n' "$1" > "$WORK/vscode-vithanco/package.json"
    echo 'main.js' > "$WORK/obsidian-vithanco/.gitignore"
    echo 'bundle' > "$WORK/obsidian-vithanco/main.js"
    echo 'package' > "$WORK/vscode-vithanco/vithanco-$1.vsix"
    echo '*.vsix' >> "$WORK/vscode-vithanco/.gitignore"
    mkdir -p "$WORK/obsidian-vithanco/vendor/Package"
    echo 'glue' > "$WORK/obsidian-vithanco/vendor/Package/index.js"
    for p in obsidian-vithanco vscode-vithanco; do
        git -C "$WORK/$p" add . && git -C "$WORK/$p" commit -qm "bump merged"
        git -C "$WORK/$p" push -q origin main
    done
    # WORK stands in for VGraph itself: committed, and pushed to its main.
    mkdir -p "$WORK/Sources" && echo 'engine' > "$WORK/Sources/engine.swift"
    echo '{}' > "$WORK/plugins.json"
    printf '%s\n' '*.git/' obsidian-vithanco/ vscode-vithanco/ website/Package/ out gh.log npx.log > "$WORK/.gitignore"
    git init -q --bare -b main "$WORK/vgraph.git"
    git -C "$WORK" init -q -b main
    git -C "$WORK" remote add origin "$WORK/vgraph.git"
    git -C "$WORK" add . && git -C "$WORK" commit -qm "engine"
    git -C "$WORK" push -q origin main
    record_build
}
# What build-wasm.sh writes after every build: the commit and the wasm it produced.
record_build() { ( cd "$WORK" && "$REPO_ROOT/scripts/record-engine-build.sh" website/Package ); }
commit_and_push() { # file, message
    echo "$2" > "$WORK/$1" && git -C "$WORK" add "$1" && git -C "$WORK" commit -qm "$2" && git -C "$WORK" push -q origin main
}
nothing_released() { # why
    for p in obsidian-vithanco vscode-vithanco; do
        git -C "$WORK/$p.git" rev-parse -q --verify refs/tags/1.2.3 >/dev/null && fail "$1: $p was tagged"
    done
    grep -q '^release create' "$GH_LOG" && fail "$1: created a release"
}
publish() { just --justfile "$REPO_ROOT/justfile" --working-directory "$WORK" publish-plugins "$@" >"$WORK/out" 2>&1; }
pushed_to_marketplace() { grep -q '^vsce publish' "$NPX_LOG"; }

# Given the bump already committed and nothing to commit, when publishing, then both plugins are tagged and released.
given_plugins_at 1.2.3
publish || fail "publishing with nothing to commit failed: $(cat "$WORK/out")"
for p in obsidian-vithanco vscode-vithanco; do
    git -C "$WORK/$p.git" rev-parse -q --verify refs/tags/1.2.3 >/dev/null || fail "$p was not tagged"
done
[ "$(grep -c '^release create' "$GH_LOG")" = 2 ] || fail "wanted two releases: $(cat "$GH_LOG")"

# Given a local rebuild that changed the committed engine, when publishing, then it is committed under the tag.
given_plugins_at 1.2.3
for w in website/Package obsidian-vithanco vscode-vithanco; do printf '\0asm\1\0\0\0\1' > "$WORK/$w/VGraphWasm.wasm"; done
record_build
publish || fail "publishing a changed engine failed: $(cat "$WORK/out")"
[ "$(git -C "$WORK/obsidian-vithanco" log -1 --format=%s 1.2.3)" = "chore: release 1.2.3" ] \
    || fail "the changed engine was not committed under the tag"

# Given a plugin checked out on another branch, when publishing, then nothing is
# pushed, tagged or released: `git push origin HEAD` would release that branch.
given_plugins_at 1.2.3
git -C "$WORK/vscode-vithanco" switch -qc some-pr
publish && fail "published from a branch other than main"
grep -q 'some-pr' "$WORK/out" || fail "does not name the branch: $(cat "$WORK/out")"
for p in obsidian-vithanco vscode-vithanco; do
    git -C "$WORK/$p.git" rev-parse -q --verify refs/tags/1.2.3 >/dev/null && fail "$p was tagged"
done
grep -q '^release create' "$GH_LOG" && fail "created a release"

# Given VGraph with uncommitted changes, when publishing, then nothing is
# released: the engine would ship from code that no commit holds.
given_plugins_at 1.2.3
echo 'change' > "$WORK/engine.swift"
publish && fail "published from an uncommitted VGraph"
grep -q 'uncommitted' "$WORK/out" || fail "does not say VGraph is uncommitted: $(cat "$WORK/out")"
nothing_released "uncommitted VGraph"

# Given a VGraph commit that is not on origin/main, when publishing, then nothing is released.
given_plugins_at 1.2.3
git -C "$WORK" commit -qm "local only" --allow-empty
publish && fail "published from a VGraph commit that is not on origin/main"
grep -q 'origin/main' "$WORK/out" || fail "does not name origin/main: $(cat "$WORK/out")"
nothing_released "unpushed VGraph"

# Given the version bump committed after the build, when publishing, then it
# publishes, and both releases name the commit that built the engine, not HEAD.
given_plugins_at 1.2.3
ENGINE=$(git -C "$WORK" rev-parse --short=12 HEAD)
commit_and_push plugins.json '{"bumped":true}'
publish || fail "publishing after a version-bump commit failed: $(cat "$WORK/out")"
[ "$(grep '^release create' "$GH_LOG" | grep -c "$ENGINE")" = 2 ] \
    || fail "the releases do not name the build commit $ENGINE: $(cat "$GH_LOG")"

# Given an engine change merged after the build, when publishing, then nothing is
# released: the plugins carry the older engine, and the notes would name the newer.
given_plugins_at 1.2.3
commit_and_push Sources/engine.swift 'engine changed'
publish && fail "published an engine built before the engine changed"
grep -q 'changed since' "$WORK/out" || fail "does not say the engine changed: $(cat "$WORK/out")"
nothing_released "engine changed after the build"

# Given an engine built from uncommitted changes, when publishing, then nothing is released.
given_plugins_at 1.2.3
sed -i.bak 's/^\([0-9a-f]*\) /\1-dirty /' "$WORK/website/Package/VGRAPH_BUILD"
publish && fail "published an engine built from uncommitted changes"
grep -q 'uncommitted' "$WORK/out" || fail "does not say the build was uncommitted: $(cat "$WORK/out")"
# The fix is to commit and rebuild; plugins-release would bump the version again.
grep -q "just release" "$WORK/out" || fail "does not point at 'just release': $(cat "$WORK/out")"
grep -q "plugins-release" "$WORK/out" && fail "advises plugins-release, which bumps again: $(cat "$WORK/out")"
nothing_released "dirty build"

# Given a plugin whose wasm is not the recorded build, when publishing, then nothing is released.
given_plugins_at 1.2.3
printf '\0asm\1\0\0\0\2' > "$WORK/vscode-vithanco/VGraphWasm.wasm"
publish && fail "published a plugin carrying another engine"
grep -q 'vscode-vithanco/VGraphWasm.wasm' "$WORK/out" || fail "does not name the mismatched wasm: $(cat "$WORK/out")"
nothing_released "mismatched wasm"

# Given a build whose commit could not be read, when publishing, then nothing is released.
given_plugins_at 1.2.3
sed -i.bak 's/^[0-9a-f]* /unknown /' "$WORK/website/Package/VGRAPH_BUILD"
publish && fail "published an engine whose source commit is unknown"
grep -q 'unknown commit' "$WORK/out" || fail "does not say the commit is unknown: $(cat "$WORK/out")"
nothing_released "unknown build commit"

# Given no recorded build, when publishing, then nothing is released, and it
# points at `just release`, which builds: plugins-release only bumps.
given_plugins_at 1.2.3
rm "$WORK/website/Package/VGRAPH_BUILD"
publish && fail "published without knowing which commit built the engine"
grep -q 'just release' "$WORK/out" || fail "does not point at 'just release': $(cat "$WORK/out")"
nothing_released "no recorded build"

# Given a Marketplace credential, when publishing, then the .vsix goes to the
# Marketplace too, after both GitHub releases: no second recipe to remember.
given_plugins_at 1.2.3
VSCE_PAT=token publish || fail "publishing with a Marketplace credential failed: $(cat "$WORK/out")"
grep -q '^vsce publish --packagePath vithanco-1.2.3.vsix' "$NPX_LOG" \
    || fail "did not push vithanco-1.2.3.vsix to the Marketplace: $(cat "$NPX_LOG")"
[ "$(grep -c '^release create' "$GH_LOG")" = 2 ] || fail "wanted two releases before the Marketplace: $(cat "$GH_LOG")"

# Given no Marketplace credential, when publishing, then the GitHub releases
# still succeed and it says how to finish the Marketplace by hand.
given_plugins_at 1.2.3
publish || fail "publishing without a Marketplace credential failed: $(cat "$WORK/out")"
pushed_to_marketplace && fail "pushed to the Marketplace without a credential"
grep -q 'vithanco-1.2.3.vsix' "$WORK/out" || fail "does not name the .vsix to upload: $(cat "$WORK/out")"

# Given the Marketplace already at this version, when publishing, then it is not
# pushed again: vsce refuses a version it already has.
given_plugins_at 1.2.3
MARKETPLACE_VERSION=1.2.3 VSCE_PAT=token publish || fail "publishing failed: $(cat "$WORK/out")"
pushed_to_marketplace && fail "pushed a version the Marketplace already has"

# Given publish-all, which runs the Marketplace last itself, when it publishes
# the plugins, then publish-plugins leaves the Marketplace alone.
given_plugins_at 1.2.3
VSCE_PAT=token publish defer || fail "publishing with the Marketplace deferred failed: $(cat "$WORK/out")"
pushed_to_marketplace && fail "pushed to the Marketplace although it was deferred"

# Given origin cannot be fetched, when publishing, then nothing is released: a
# cached origin/main may still hold a commit the remote has dropped.
given_plugins_at 1.2.3
git -C "$WORK" remote set-url origin "$WORK/missing.git"
publish && fail "published without fetching origin/main"
grep -q 'fetch' "$WORK/out" || fail "does not say the fetch failed: $(cat "$WORK/out")"
nothing_released "fetch failed"

# Given a rebuild that refreshed the Obsidian plugin's vendored engine glue, when
# publishing, then the glue is committed under the tag next to the wasm: the
# directory builds the repo alone, and new wasm with old glue would not run.
given_plugins_at 1.2.3
echo 'new glue' > "$WORK/obsidian-vithanco/vendor/Package/index.js"
publish || fail "publishing refreshed glue failed: $(cat "$WORK/out")"
[ "$(git -C "$WORK/obsidian-vithanco" show 1.2.3:vendor/Package/index.js)" = "new glue" ] \
    || fail "the refreshed glue was not committed under the tag"

# Given VGraph with uncommitted changes (a version bump not yet merged), when
# `just release` starts, then it refuses before its long test and build run,
# not only publish-plugins after it.
given_plugins_at 1.2.3
echo '{"bumped":true}' > "$WORK/plugins.json"
just --justfile "$REPO_ROOT/justfile" --working-directory "$WORK" _release-preflight >"$WORK/out" 2>&1 \
    && fail "the release preflight accepted an uncommitted VGraph"
grep -q 'uncommitted' "$WORK/out" || fail "release preflight does not say VGraph is uncommitted: $(cat "$WORK/out")"
just --justfile "$REPO_ROOT/justfile" --show release | grep -q '^release: _release-preflight' \
    || fail "just release does not run _release-preflight first: $(just --justfile "$REPO_ROOT/justfile" --show release | grep '^release:')"

# Given a VGraph whose status git cannot read (a corrupt index), when the release
# preflight runs, then it refuses: empty output from a failed `git status` is
# not a clean checkout.
given_plugins_at 1.2.3
echo 'not an index' > "$WORK/.git/index"
just --justfile "$REPO_ROOT/justfile" --working-directory "$WORK" _release-preflight >"$WORK/out" 2>&1 \
    && fail "the release preflight accepted a VGraph whose status could not be read"
grep -q 'status' "$WORK/out" || fail "does not say the status could not be read: $(cat "$WORK/out")"

[ "$FAILED" -eq 0 ] && echo "✓ publish-plugins"
exit "$FAILED"
