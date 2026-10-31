#!/bin/bash
# Bump the Node MCP host's version and refresh its vendored engine.
# Does NOT commit, tag, push, or publish — same rationale as the plugins':
# the bump folds into whatever commit makes sense.
#
# Usage:
#   ./release.sh                  # auto patch bump
#   ./release.sh --minor
#   ./release.sh --major
#   ./release.sh <version>        # explicit version
#   VGRAPH_REPO=/path/to/VGraph ./release.sh [args]
#
# Called by ../release-plugins.sh, which drives every consumer in plugins.json
# so all three hosts of the engine carry the same number. That is the point of
# the number here: it says which engine build you are running, and a bug report
# quoting it identifies the same thing whether it came from Obsidian, VS Code
# or npm.
#
# The version lives in two files — package.json and server.json, the latter
# twice — and `just publish-mcp-node` refuses to publish if they disagree.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

CURRENT=$(node -p "require('./package.json').version")

ARG="${1:-}"
case "$ARG" in
    ""|--patch) BUMP=patch ;;
    --minor)    BUMP=minor ;;
    --major)    BUMP=major ;;
    v*)
        echo "Error: version must not start with 'v' (use 1.0.9, not v1.0.9)"
        exit 1
        ;;
    *)
        if ! [[ "$ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Error: version must be semver (e.g. 1.0.9) or one of --patch/--minor/--major, got '$ARG'"
            exit 1
        fi
        BUMP=""
        ;;
esac

if [ -n "$BUMP" ]; then
    NEW=$(node -p "
        const [a,b,c] = '$CURRENT'.split('.').map(Number);
        ({patch:[a,b,c+1], minor:[a,b+1,0], major:[a+1,0,0]})['$BUMP'].join('.')
    ")
else
    NEW="$ARG"
fi

echo "  $CURRENT → $NEW"

node -e "
const fs = require('fs');
for (const [file, apply] of [
    ['package.json', (j) => { j.version = '$NEW'; }],
    ['server.json',  (j) => { j.version = '$NEW'; j.packages[0].version = '$NEW'; }],
]) {
    const j = JSON.parse(fs.readFileSync(file, 'utf8'));
    apply(j);
    fs.writeFileSync(file, JSON.stringify(j, null, 2) + '\n');
}
"

# The engine inside vendor/ is Apache-2.0: its LICENSE and NOTICE travel with it.
cp "$SCRIPT_DIR/../LICENSE" LICENSE
cp "$SCRIPT_DIR/../NOTICE" NOTICE

# Refresh the vendored engine from an already-built monorepo, the way the
# plugins re-copy VGraphWasm.wasm. A copy, not a build: building is `just
# mcp-node`, and a release script that silently spends three minutes compiling
# is a release script people stop running.
VGRAPH_REPO="${VGRAPH_REPO:-$(cd "$SCRIPT_DIR/.." && pwd)}"
if [ -d "$VGRAPH_REPO/website/Package" ] && [ -d "$VGRAPH_REPO/fonts" ]; then
    rm -rf vendor
    mkdir -p vendor
    cp -R "$VGRAPH_REPO/website/Package" vendor/Package
    cp -R "$VGRAPH_REPO/fonts" vendor/fonts
    WASM_BYTES=$(wc -c < vendor/Package/VGraphWasm.wasm)
    if [ "$WASM_BYTES" -gt 20000000 ]; then
        echo "  WARN: vendored engine is $WASM_BYTES bytes — that is a debug build."
        echo "        Run 'just mcp-node' before publishing."
    fi
    echo "  vendored engine refreshed ($(du -sh vendor | cut -f1))"
else
    echo "  WARN: $VGRAPH_REPO/website/Package or /fonts missing — vendor/ not refreshed."
fi

echo ""
echo "✓ Bumped to $NEW. Publish with:  just publish-mcp-node"
