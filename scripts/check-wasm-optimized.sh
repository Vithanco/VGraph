#!/usr/bin/env bash
# Refuse a debug engine. The plugins embed the WASM (base64, so ~4/3 larger)
# into what users download; 1.0.9 shipped a 90 MB debug build that way.
# Size alone is not enough — a debug build can shrink under the limit — so
# DWARF sections are checked too; wasm-strip removes them in a release build.
set -uo pipefail

MAX_BYTES=20000000

if [ "$#" -eq 0 ]; then
    echo "usage: $0 <file.wasm>..." >&2
    exit 2
fi

FAIL=0
for f in "$@"; do
    if [ ! -f "$f" ]; then
        echo "✗ $f is missing" >&2
        FAIL=1
        continue
    fi
    bytes=$(wc -c < "$f" | tr -d ' ')
    if [ "$bytes" -gt "$MAX_BYTES" ]; then
        echo "✗ $f is $bytes bytes (limit $MAX_BYTES) — a debug build." >&2
        FAIL=1
    elif grep -aq '\.debug_info' "$f"; then
        echo "✗ $f has DWARF debug sections — it was not stripped." >&2
        FAIL=1
    fi
done

if [ "$FAIL" -ne 0 ]; then
    echo "  Build with 'just release' (or build-wasm.sh --release), then rebuild the plugins." >&2
fi
exit "$FAIL"
