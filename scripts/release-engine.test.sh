#!/usr/bin/env bash
# A VGraph release is a v* tag plus a build of each plugin against it. The tag
# cannot be taken back, so everything that can fail must fail before it is pushed.
set -uo pipefail

SCRIPT=$(cd "$(dirname "$0")" && pwd)/release-engine.sh
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

mkdir "$ROOT/bin"
cat > "$ROOT/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
case "$*" in
    "workflow view"*) [ -z "${GH_VIEW_FAILS:-}" ] ;;
    "workflow run"*)  [ -z "${GH_RUN_FAILS:-}" ] ;;
esac
EOF
chmod +x "$ROOT/bin/gh"
export PATH="$ROOT/bin:$PATH"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

CASE=0
given_a_clean_main() { # sets REPO, ORIGIN and GH_LOG
    CASE=$((CASE + 1))
    ORIGIN="$ROOT/$CASE-origin.git"
    REPO="$ROOT/$CASE-repo"
    export GH_LOG="$ROOT/$CASE-gh.log"
    : > "$GH_LOG"
    git init -q --bare -b main "$ORIGIN"
    git init -q -b main "$REPO"
    mkdir "$REPO/scripts"
    cp "$SCRIPT" "$REPO/scripts/"
    cat > "$REPO/plugins.json" <<'EOF'
{"plugins":[
  {"path":"obsidian-vithanco","version":"1.0.0","repo":"https://github.com/Vithanco/obsidian-vithanco.git"},
  {"path":"vscode-vithanco","version":"1.0.0","repo":"https://github.com/Vithanco/vscode-vithanco.git"},
  {"path":"vgraph-mcp-node","version":"1.0.0"}
]}
EOF
    git -C "$REPO" add . && git -C "$REPO" commit -qm init
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin main
}
run() { ( cd "$REPO" && ./scripts/release-engine.sh "$@" ) >"$ROOT/out" 2>&1; }
tag_pushed() { git -C "$ORIGIN" rev-parse -q --verify "refs/tags/$1" >/dev/null; }
refused() { # description, then: nothing reached origin and no plugin was started
    grep -q 'workflow run' "$GH_LOG" && fail "$1: started a plugin build"
    [ -z "$(git -C "$ORIGIN" tag)" ] || fail "$1: pushed a tag"
}

# Given a clean main, when releasing, then the tag lands and each plugin with a repo builds against it.
given_a_clean_main
run 1.2.3 || fail "clean release failed: $(cat "$ROOT/out")"
tag_pushed v1.2.3 || fail "the tag was not pushed"
for p in obsidian-vithanco vscode-vithanco; do
    grep -qx "workflow run ci.yml --repo Vithanco/$p -f vgraph_ref=v1.2.3 -f release_version=1.2.3" "$GH_LOG" \
        || fail "$p was not started: $(cat "$GH_LOG")"
done
grep -q 'vgraph-mcp-node' "$GH_LOG" && fail "started vgraph-mcp-node, which has no repo of its own"

# Given a version that is not plain semver, when releasing, then nothing happens.
# A leading v would double up in the tag and reach Obsidian, which rejects it.
for bad in v1.2.3 1.2 1.2.3-rc1 "" 'x;y' 01.2.3 1.02.3 1.2.03; do
    given_a_clean_main
    run "$bad" && fail "accepted version '$bad'"
    refused "version '$bad'"
done

# Given zeros that semver allows, when releasing, then they are accepted.
given_a_clean_main
run 0.10.0 || fail "refused 0.10.0: $(cat "$ROOT/out")"
tag_pushed v0.10.0 || fail "v0.10.0 was not pushed"

# Given a dirty tree, when releasing, then nothing happens: the tag would not describe it.
given_a_clean_main
echo dirty >> "$REPO/plugins.json"
run 1.2.3 && fail "released from a dirty tree"
refused "dirty tree"

# Given another branch, when releasing, then nothing happens.
given_a_clean_main
git -C "$REPO" switch -qc feature
run 1.2.3 && fail "released from a branch other than main"
refused "other branch"

# Given unpushed work, when releasing, then nothing happens: CI could not check it out by its history.
given_a_clean_main
git -C "$REPO" commit -q --allow-empty -m unpushed
run 1.2.3 && fail "released a commit origin does not have"
refused "unpushed commit"

# Given main behind origin, when releasing, then nothing happens.
given_a_clean_main
OTHER="$ROOT/$CASE-other"
git clone -q "$ORIGIN" "$OTHER" && git -C "$OTHER" commit -q --allow-empty -m newer && git -C "$OTHER" push -q origin main
run 1.2.3 && fail "released a stale main"
refused "stale main"

# Given the tag already on origin, when releasing, then it is refused and not moved.
given_a_clean_main
git -C "$REPO" tag v1.2.3 && git -C "$REPO" push -q origin v1.2.3 && git -C "$REPO" tag -d v1.2.3 >/dev/null
git -C "$REPO" commit -q --allow-empty -m later && git -C "$REPO" push -q origin main
before=$(git -C "$ORIGIN" rev-parse v1.2.3)
run 1.2.3 && fail "re-released an existing tag"
[ "$(git -C "$ORIGIN" rev-parse v1.2.3)" = "$before" ] || fail "moved an existing tag"
grep -q 'workflow run' "$GH_LOG" && fail "started a build for an existing tag"

# Given a plugin without the workflow, when releasing, then no tag is pushed.
given_a_clean_main
GH_VIEW_FAILS=1 run 1.2.3 && fail "released with a plugin workflow missing"
refused "missing workflow"

# Given a tag pushed but a start that fails, when releasing, then it says so and how to retry.
given_a_clean_main
GH_RUN_FAILS=1 run 1.2.3 && fail "reported success though a plugin build did not start"
tag_pushed v1.2.3 || fail "the tag should stand"
grep -q 'gh workflow run ci.yml' "$ROOT/out" || fail "does not say how to start the build by hand: $(cat "$ROOT/out")"

[ "$FAILED" -eq 0 ] && echo "✓ release-engine"
exit "$FAILED"
