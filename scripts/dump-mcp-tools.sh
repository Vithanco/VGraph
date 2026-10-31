#!/usr/bin/env bash
# Regenerate vgraph-mcp-node/tools.json from the native MCP server.
#
# The Node host serves the same tools as `vgraph-mcp`, and their descriptions
# are ~20KB of VGL documentation that the model actually reads — the difference
# between a diagram that follows a notation and one that doesn't. Re-typing
# them in JavaScript would guarantee they drift, so the Swift stays the single
# source of truth and this asks the built server what it offers.
#
# Speaking MCP to it rather than parsing Swift: what a client sees is the thing
# worth copying, and a tool added to VGraphTools.all shows up here with no
# change to this script.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
OUT="vgraph-mcp-node/tools.json"

# Whichever was built most recently, not a fixed preference: a stale release
# binary sitting next to a fresh debug one would silently dump old descriptions.
BIN=""
for candidate in .build/release/vgraph-mcp .build/debug/vgraph-mcp; do
    [ -x "$candidate" ] || continue
    if [ -z "$BIN" ] || [ "$candidate" -nt "$BIN" ]; then
        BIN="$candidate"
    fi
done
if [ -z "$BIN" ]; then
    echo "Error: no vgraph-mcp binary — run 'just mcp' first." >&2
    exit 1
fi

echo "Asking $BIN for its tool list..."

# stdin must stay open until the server has answered; a closed pipe races the
# reply. Three seconds is slack, not a measurement.
RESPONSE=$( (
    printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"dump-tools","version":"1"}}}' \
      '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
      '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
    sleep 3
) | "$BIN" 2>/dev/null | grep '"id":2' )

if [ -z "$RESPONSE" ]; then
    echo "Error: no tools/list response from $BIN." >&2
    exit 1
fi

printf '%s' "$RESPONSE" | python3 -c "
import json, sys
tools = json.load(sys.stdin)['result']['tools']
if not tools:
    sys.exit('Error: server returned an empty tool list.')
with open(sys.argv[1], 'w') as fh:
    json.dump(tools, fh, indent=2, sort_keys=True)
    fh.write(chr(10))
print('  %d tools -> %s' % (len(tools), sys.argv[1]))
for t in tools:
    print('    ' + t['name'])
" "$OUT"
