#!/bin/bash
# Bump and rebuild every editor plugin listed in plugins.json, against the
# current monorepo's VGraphWasm.wasm. Each plugin's own ./release.sh handles
# the bump + build; this orchestrator just walks the registry, calls them
# with the right args, and updates plugins.json with the new versions.
#
# Does NOT commit / tag / push / publish — same rationale as the per-plugin
# scripts. The per-plugin scripts print the suggested commands; this one
# prints a final roll-up.
#
# Usage:
#   ./release-plugins.sh                # patch bump every plugin
#   ./release-plugins.sh --minor        # minor bump every plugin
#   ./release-plugins.sh --major        # major bump every plugin
#   ./release-plugins.sh <plugin-path>  # patch bump just that plugin
#                                       # (use the 'path' field from plugins.json,
#                                       # e.g. 'obsidian-vithanco')
#   ./release-plugins.sh <plugin-path> --minor
#
# The monorepo's `just build` should have been run first so that
# website/Package/VGraphWasm.wasm is up to date — each plugin's release.sh
# copies that file in when VGRAPH_REPO is set (which this orchestrator does).

set -euo pipefail

MONOREPO=$(cd "$(dirname "$0")" && pwd)
REGISTRY="$MONOREPO/plugins.json"

if [[ ! -f "$REGISTRY" ]]; then
    echo "Error: $REGISTRY not found."
    exit 1
fi

# ---- 1. Parse args --------------------------------------------------------
#
# Accept up to two positional args: a plugin path filter and/or a bump flag,
# in either order. Default is "all plugins, patch bump".

FILTER=""
BUMP_FLAG=""

for arg in "$@"; do
    case "$arg" in
        --patch|--minor|--major) BUMP_FLAG="$arg" ;;
        # An explicit version, which each release.sh already accepts. Without
        # this it fell through to FILTER and silently patch-bumped instead —
        # and `just` is the only interface some of us want to use, so the
        # driver has to take everything the scripts it drives take.
        [0-9]*.[0-9]*.[0-9]*) BUMP_FLAG="$arg" ;;
        *) FILTER="$arg" ;;
    esac
done

# ---- 2. Read registry --------------------------------------------------
# Each line printed by node is "<path>\t<version>". Read via a portable
# while-loop (macOS bash 3.2 has no `mapfile`).

REGISTRY_LINES=$(node -e "
const reg = require('$REGISTRY');
for (const p of reg.plugins) {
    console.log(p.path + '\t' + p.version);
}
")

# ---- 3. Iterate and bump --------------------------------------------------

SUMMARY=""
RAN_ANY=0

while IFS=$'\t' read -r PLUGIN_PATH OLD_VERSION; do
    [[ -z "$PLUGIN_PATH" ]] && continue
    PLUGIN_DIR="$MONOREPO/$PLUGIN_PATH"

    if [[ -n "$FILTER" && "$FILTER" != "$PLUGIN_PATH" ]]; then
        continue
    fi

    if [[ ! -d "$PLUGIN_DIR" ]]; then
        echo "WARN: $PLUGIN_PATH listed in plugins.json but directory missing — skipping."
        continue
    fi
    if [[ ! -x "$PLUGIN_DIR/release.sh" ]]; then
        echo "WARN: $PLUGIN_DIR/release.sh missing or not executable — skipping."
        continue
    fi

    echo ""
    echo "━━━ $PLUGIN_PATH (current $OLD_VERSION) ━━━"
    ( cd "$PLUGIN_DIR" && VGRAPH_REPO="$MONOREPO" ./release.sh ${BUMP_FLAG:-} )

    # Read what the plugin landed on. Both plugins keep their version in their
    # manifest (Obsidian) or package.json — manifest.json if present, else
    # package.json, both have a top-level "version" string.
    if [[ -f "$PLUGIN_DIR/manifest.json" ]]; then
        NEW_VERSION=$(node -p "require('$PLUGIN_DIR/manifest.json').version")
    else
        NEW_VERSION=$(node -p "require('$PLUGIN_DIR/package.json').version")
    fi

    SUMMARY="${SUMMARY}${PLUGIN_PATH}: ${OLD_VERSION} → ${NEW_VERSION}"$'\n'
    RAN_ANY=1

    # ---- 4. Write the new version back to plugins.json --------------------
    node -e "
        const fs = require('fs');
        const reg = JSON.parse(fs.readFileSync('$REGISTRY', 'utf8'));
        const p = reg.plugins.find(p => p.path === '$PLUGIN_PATH');
        if (p) p.version = '$NEW_VERSION';
        fs.writeFileSync('$REGISTRY', JSON.stringify(reg, null, 2) + '\n');
    "
done <<< "$REGISTRY_LINES"

if [[ "$RAN_ANY" -eq 0 ]]; then
    if [[ -n "$FILTER" ]]; then
        echo "No plugin matched '$FILTER'. Known paths:"
        node -e "require('$REGISTRY').plugins.forEach(p => console.log('  ' + p.path))"
    else
        echo "No plugins in $REGISTRY."
    fi
    exit 1
fi

# ---- 5. Summary -----------------------------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Plugin bumps complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf '%s' "$SUMMARY" | while IFS= read -r s; do echo "  $s"; done
echo ""
echo "plugins.json updated. Nothing committed, tagged or pushed."
echo ""
echo "Next:  just publish-plugins      # commits, tags and creates both GitHub releases"
