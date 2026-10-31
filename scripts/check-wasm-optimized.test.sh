#!/usr/bin/env bash
# check-wasm-optimized.sh must reject a debug engine and accept an optimized one.
# The 1.0.9 plugins shipped a 90 MB debug WASM (a 115 MB main.js) because the
# only size check looked at website/Package, not at the copy a plugin embeds.
set -uo pipefail

CHECK=scripts/check-wasm-optimized.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAILED=0

expect() { # expected-exit description file...
    local want=$1 desc=$2; shift 2
    "$CHECK" "$@" >/dev/null 2>&1
    local got=$?
    if [ "$got" -ne "$want" ]; then
        echo "FAIL: $desc (exit $got, wanted $want)" >&2
        FAILED=1
    fi
}

printf '\0asm\1\0\0\0' > "$TMP/optimized.wasm"
printf '\0asm\1\0\0\0.debug_info' > "$TMP/debug-sections.wasm"
head -c 21000000 /dev/zero > "$TMP/oversized.wasm"

expect 0 "accepts a stripped small engine" "$TMP/optimized.wasm"
expect 1 "rejects an engine with DWARF sections" "$TMP/debug-sections.wasm"
expect 1 "rejects an oversized engine" "$TMP/oversized.wasm"
expect 1 "rejects when any one of several files is bad" "$TMP/optimized.wasm" "$TMP/debug-sections.wasm"
expect 1 "rejects a missing file" "$TMP/absent.wasm"
expect 2 "usage error with no arguments"

[ "$FAILED" -eq 0 ] && echo "✓ check-wasm-optimized"
exit "$FAILED"
