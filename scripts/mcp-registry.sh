#!/usr/bin/env bash
# List vgraph-mcp-node in the MCP Registry at the version its server.json names.
#
#   scripts/mcp-registry.sh          # log in and publish, retrying; nothing to do when listed
#   scripts/mcp-registry.sh --has    # exit 0 when the registry lists that version
#
# The registry stalls a TLS handshake now and then (one connection in six, on
# 2026-11-21), so every step is retried. A publish that timed out may still have
# landed, and the registry refuses a version twice, so each attempt asks first.
set -euo pipefail

cd vgraph-mcp-node
NAME=$(node -p "require('./server.json').name")
VER=$(node -p "require('./server.json').version")
REGISTRY=https://registry.modelcontextprotocol.io

listed() {
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
        "$REGISTRY/v0/servers/${NAME/\//%2F}/versions/$VER")" = 200 ]
}

if [ "${1:-}" = --has ]; then
    listed
    exit
fi

if ! command -v mcp-publisher >/dev/null 2>&1; then
    echo "· mcp-publisher not installed, so the registry entry was skipped —"
    echo "  'brew install mcp-publisher', then 'just publish-mcp-node'."
    exit 0
fi

# DNS auth, not GitHub: it is what earns the com.vithanco namespace rather than
# io.github.vithanco. The token is short-lived, so log in right before publishing.
KEY="${MCP_SIGNING_KEY:-$HOME/.config/mcp-publisher/vithanco-ed25519.pem}"
login() {
    [ -f "$KEY" ] || return 0
    mcp-publisher login dns --domain vithanco.com \
        --private-key "$(openssl pkey -in "$KEY" -outform DER | tail -c 32 | xxd -p -c 64)"
}
if [ ! -f "$KEY" ]; then
    echo "· no signing key at $KEY — using whatever session mcp-publisher holds."
    echo "  (set MCP_SIGNING_KEY if it lives elsewhere)"
fi

TRIES=${MCP_RETRIES:-4}
DELAY=${MCP_RETRY_DELAY:-15}
for attempt in $(seq 1 "$TRIES"); do
    if listed; then
        echo "✓ $NAME $VER is listed in the MCP Registry"
        exit 0
    fi
    echo "Publishing $NAME $VER to the MCP Registry (attempt $attempt of $TRIES)..."
    if login && mcp-publisher publish; then
        echo "✓ $NAME $VER is listed in the MCP Registry"
        exit 0
    fi
    [ "$attempt" -lt "$TRIES" ] && sleep $((DELAY * attempt))
done
if listed; then
    echo "✓ $NAME $VER is listed in the MCP Registry"
    exit 0
fi
echo "The MCP Registry did not take $NAME $VER after $TRIES attempts." >&2
echo "npm has it; finish with 'just publish-mcp-node', which goes straight to the registry." >&2
exit 1
