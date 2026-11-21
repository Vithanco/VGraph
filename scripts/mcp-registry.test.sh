#!/usr/bin/env bash
# The registry stalls a TLS handshake now and then. One stall used to end the
# release, and a rerun of publish-all never came back to the registry, so it
# fell several versions behind npm.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(mktemp -d) || exit 1
trap 'rm -rf "$ROOT"' EXIT
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }

# Counters in REG: a file `login-fails` holding 2 makes the next two logins fail.
mkdir "$ROOT/bin"
cat > "$ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$REG/curl.log"
if [ -s "$REG/curl-fails" ] && [ "$(cat "$REG/curl-fails")" -gt 0 ]; then
    echo $(( $(cat "$REG/curl-fails") - 1 )) > "$REG/curl-fails"
    printf 000; exit 28
fi
case "$*" in
    *"/v0/servers/com.example%2Fdemo/versions/1.2.3"*) [ -f "$REG/listed" ] && printf 200 || printf 404 ;;
    *) printf 404 ;;
esac
EOF
cat > "$ROOT/bin/mcp-publisher" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$REG/calls"
fails() { [ -s "$REG/$1" ] && [ "$(cat "$REG/$1")" -gt 0 ] && echo $(( $(cat "$REG/$1") - 1 )) > "$REG/$1"; }
case "$1" in
    login) if fails login-fails; then echo "TLS handshake timeout" >&2; exit 1; fi ;;
    publish)
        if fails publish-fails; then echo "TLS handshake timeout" >&2; exit 1; fi
        touch "$REG/listed"
        [ -f "$REG/lands-then-fails" ] && { rm "$REG/lands-then-fails"; exit 1; }
        ;;
esac
exit 0
EOF
printf '#!/bin/sh\nhead -c 32 /dev/zero\n' > "$ROOT/bin/openssl"
chmod +x "$ROOT/bin/"*
export PATH="$ROOT/bin:$PATH" MCP_RETRY_DELAY=0 MCP_RETRIES=3

given_registry() { # in a fresh WORK with server.json at 1.2.3 and a signing key
    WORK=$(mktemp -d "$ROOT/work.XXXXXX") || exit 1
    export REG="$WORK/reg" MCP_SIGNING_KEY="$WORK/key.pem"
    mkdir -p "$REG" "$WORK/vgraph-mcp-node"
    : > "$REG/calls"; : > "$REG/curl.log"; echo key > "$MCP_SIGNING_KEY"
    echo '{"name":"com.example/demo","version":"1.2.3"}' > "$WORK/vgraph-mcp-node/server.json"
}
registry() { ( cd "$WORK" && "$REPO_ROOT/scripts/mcp-registry.sh" "$@" ) >"$WORK/out" 2>&1; }
count() { grep -cx "$1" "$REG/calls"; }

# Given logins that time out twice, when publishing, then the third attempt lists it.
given_registry
echo 2 > "$REG/login-fails"
registry || fail "gave up on two timeouts: $(cat "$WORK/out")"
[ -f "$REG/listed" ] || fail "not listed after the timeouts"
[ "$(count login)" = 3 ] || fail "wanted three logins: $(cat "$REG/calls")"
[ "$(count publish)" = 1 ] || fail "wanted one publish: $(cat "$REG/calls")"

# Given the version already listed, when publishing, then mcp-publisher is not run.
given_registry
touch "$REG/listed"
registry || fail "failed on a version already listed: $(cat "$WORK/out")"
[ -s "$REG/calls" ] && fail "ran mcp-publisher for a listed version: $(cat "$REG/calls")"

# Given a publish that lands but reports a timeout, when retrying, then it is not published twice.
given_registry
touch "$REG/lands-then-fails"
registry || fail "failed although the publish landed: $(cat "$WORK/out")"
[ "$(count publish)" = 1 ] || fail "published a listed version again: $(cat "$REG/calls")"

# Given a registry that never answers, when publishing, then it stops after
# MCP_RETRIES attempts and says how to finish.
given_registry
echo 99 > "$REG/login-fails"
registry && fail "succeeded without listing"
[ "$(count login)" = 3 ] || fail "wanted three attempts: $(cat "$REG/calls")"
grep -q 'just publish-mcp-node' "$WORK/out" || fail "does not say how to finish: $(cat "$WORK/out")"

# Given the version listed, not listed, or a registry that times out, when
# asking, then only a listed version answers yes.
given_registry
registry --has && fail "--has said yes before publishing"
touch "$REG/listed"
registry --has || fail "--has said no for a listed version"
echo 1 > "$REG/curl-fails"
registry --has && fail "--has said yes when the registry timed out"
grep -q -- '--max-time' "$REG/curl.log" || fail "asks the registry without a timeout: $(cat "$REG/curl.log")"

exit "$FAILED"
