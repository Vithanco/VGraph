#!/bin/bash
# Clone every editor plugin listed in plugins.json into ./<path> as a sibling
# of this monorepo, unless it's already there. Idempotent — re-run any time.
#
# Usage:
#   ./setup-plugins.sh                # clone any missing plugin
#   ./setup-plugins.sh --pull         # also `git pull` plugins that exist
#
# The plugin dirs are gitignored in this monorepo (each is its own repo), so
# the orchestrator + bootstrap together replace what a submodule setup would
# do — without the submodule ergonomics tax.

set -euo pipefail

MONOREPO=$(cd "$(dirname "$0")" && pwd)
REGISTRY="$MONOREPO/plugins.json"

if [[ ! -f "$REGISTRY" ]]; then
    echo "Error: $REGISTRY not found."
    exit 1
fi

PULL=0
case "${1:-}" in
    "")     ;;
    --pull) PULL=1 ;;
    *)      echo "Usage: $0 [--pull]"; exit 1 ;;
esac

# Each line: "<path>\t<repo>"
REGISTRY_LINES=$(node -e "
const reg = require('$REGISTRY');
for (const p of reg.plugins) {
    if (!p.repo) {
        console.error('skip ' + p.path + ': no repo URL in plugins.json');
        continue;
    }
    console.log(p.path + '\t' + p.repo);
}
")

CLONED=0
PULLED=0
SKIPPED=0

while IFS=$'\t' read -r PLUGIN_PATH REPO_URL; do
    [[ -z "$PLUGIN_PATH" ]] && continue
    TARGET="$MONOREPO/$PLUGIN_PATH"

    if [[ -d "$TARGET/.git" ]]; then
        if [[ "$PULL" -eq 1 ]]; then
            echo "→ pulling $PLUGIN_PATH"
            ( cd "$TARGET" && git pull --ff-only )
            PULLED=$((PULLED + 1))
        else
            echo "✓ $PLUGIN_PATH already cloned"
            SKIPPED=$((SKIPPED + 1))
        fi
    elif [[ -e "$TARGET" ]]; then
        echo "WARN: $TARGET exists but is not a git repo — skipping."
        SKIPPED=$((SKIPPED + 1))
    else
        echo "→ cloning $REPO_URL → $PLUGIN_PATH"
        git clone "$REPO_URL" "$TARGET"
        CLONED=$((CLONED + 1))
    fi
done <<< "$REGISTRY_LINES"

echo ""
echo "Cloned: $CLONED   Pulled: $PULLED   Already present: $SKIPPED"
