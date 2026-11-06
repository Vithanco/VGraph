#!/usr/bin/env bash
# The bump can reach a plugin's main through a merged bump PR, leaving nothing to
# commit. `git commit` then exits non-zero and `set -e` stops the recipe, which
# used to leave the Obsidian plugin published and the VS Code one not.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d)
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
export PATH="$ROOT/bin:$PATH"
export VITHANCO_MAINTAINER=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

given_plugins_at() { # version, in a fresh directory WORK with pushed plugin repos
    WORK=$(mktemp -d "$ROOT/work.XXXXXX")
    export GH_LOG="$WORK/gh.log"
    : > "$GH_LOG"
    mkdir -p "$WORK/website/Package" "$WORK/scripts"
    cp "$REPO_ROOT/scripts/check-wasm-optimized.sh" "$WORK/scripts/"
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
    echo 'main.js' > "$WORK/obsidian-vithanco/.gitignore"
    echo 'bundle' > "$WORK/obsidian-vithanco/main.js"
    echo 'package' > "$WORK/vscode-vithanco/vithanco-$1.vsix"
    echo '*.vsix' >> "$WORK/vscode-vithanco/.gitignore"
    for p in obsidian-vithanco vscode-vithanco; do
        git -C "$WORK/$p" add . && git -C "$WORK/$p" commit -qm "bump merged"
        git -C "$WORK/$p" push -q origin main
    done
}
publish() { just --justfile "$REPO_ROOT/justfile" --working-directory "$WORK" publish-plugins >"$WORK/out" 2>&1; }

# Given a bump PR already merged and nothing to commit, when publishing, then both plugins are tagged and released.
given_plugins_at 1.2.3
publish || fail "publishing with nothing to commit failed: $(cat "$WORK/out")"
for p in obsidian-vithanco vscode-vithanco; do
    git -C "$WORK/$p.git" rev-parse -q --verify refs/tags/1.2.3 >/dev/null || fail "$p was not tagged"
done
[ "$(grep -c '^release create' "$GH_LOG")" = 2 ] || fail "wanted two releases: $(cat "$GH_LOG")"

# Given a local rebuild that changed the committed engine, when publishing, then it is committed under the tag.
given_plugins_at 1.2.3
printf '\0asm\1\0\0\0\1' > "$WORK/obsidian-vithanco/VGraphWasm.wasm"
publish || fail "publishing a changed engine failed: $(cat "$WORK/out")"
[ "$(git -C "$WORK/obsidian-vithanco" log -1 --format=%s 1.2.3)" = "chore: release 1.2.3" ] \
    || fail "the changed engine was not committed under the tag"

[ "$FAILED" -eq 0 ] && echo "✓ publish-plugins"
exit "$FAILED"
