#!/usr/bin/env bash
# Every `exports.X` a plugin calls must be an `@JS` function the engine still has.
#
# `just parity` compares the two plugins against *each other*, which is why it
# stayed green while both called `renderGraphWithLayout` for a month after
# ab13435 removed it: they were identically wrong. This compares them against the
# engine instead, which is the direction the breakage actually travels — the
# plugins live in their own repos and do not rebuild when an export goes.
#
# Main.swift is the source of truth rather than the built glue, so this needs no
# build and cannot pass by testing a stale artifact.
set -uo pipefail

MAIN=VGraphWasm/Sources/Main.swift

# name : source dir : the identifier that holds the engine's exports in that
# consumer. The plugins destructure them onto `exports`; the Node MCP host
# names the object `api`. Grepping for the wrong one finds nothing and reports
# success, which is the failure mode this script exists to prevent.
CONSUMERS=(
    "obsidian-vithanco:obsidian-vithanco/src:exports"
    "vscode-vithanco:vscode-vithanco/src:exports"
    "vgraph-mcp-node:vgraph-mcp-node/src:api"
)

if [ ! -f "$MAIN" ]; then
    echo "Error: $MAIN not found — run from the repository root." >&2
    exit 2
fi

exported=$(grep -oE '@JS public func [a-zA-Z0-9_]+' "$MAIN" | awk '{print $4}' | sort -u)
if [ -z "$exported" ]; then
    echo "Error: no '@JS public func' found in $MAIN — has the export syntax changed?" >&2
    exit 2
fi

status=0
checked=0

for consumer in "${CONSUMERS[@]}"; do
    name="${consumer%%:*}"
    rest="${consumer#*:}"
    dir="${rest%%:*}"
    accessor="${rest#*:}"

    if [ ! -d "$dir" ]; then
        echo "· $name not checked out — skipped (run 'just plugins-setup' to include it)"
        continue
    fi

    # Source only. The bundled main.js is generated, and would just repeat whatever
    # the sources already say.
    called=$(grep -rhoE "${accessor}\.[a-zA-Z0-9_]+" "$dir" 2>/dev/null \
        | sed "s/^${accessor}\.//" | sort -u)
    checked=$((checked + 1))

    if [ -z "$called" ]; then
        echo "· $name calls no engine exports — nothing to verify"
        continue
    fi

    missing=$(comm -23 <(echo "$called") <(echo "$exported"))
    if [ -n "$missing" ]; then
        status=1
        echo "✗ $name calls exports the engine does not have:"
        for fn in $missing; do
            echo "    ${accessor}.$fn"
            grep -rn "${accessor}\.$fn" "$dir" | sed 's/^/        /'
        done
    else
        echo "✓ $name — every ${accessor}.* call resolves"
    fi
done

if [ "$checked" -eq 0 ]; then
    echo "· no consumers checked out; nothing to verify"
    exit 0
fi

if [ "$status" -ne 0 ]; then
    echo
    echo "The engine's current exports:"
    echo "$exported" | sed 's/^/    /'
    echo
    echo "Removing an @JS function is a breaking change for the plugins, which are"
    echo "separate repos and will not notice. Update them in the same change."
fi

exit "$status"
