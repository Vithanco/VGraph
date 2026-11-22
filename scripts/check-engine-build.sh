#!/usr/bin/env bash
# Is the engine in website/Package still the one to ship, and does each consumer
# carry exactly it? Prints the commit that built it; says what is wrong on stderr.
#
#   scripts/check-engine-build.sh [consumer-dir...]   # each holding a VGraphWasm.wasm
#
# Run from VGraph's root, after origin/main was fetched. A release ships the build
# `just release` made, so a consumer never rebuilds the engine to publish it.
set -uo pipefail

# What build-wasm.sh reads. A version-bump commit after the build is expected.
ENGINE_PATHS=(Sources Package.swift Package.resolved .swift-version build-wasm.sh
    scripts/wasm-sdk.sh scripts/embedded-unicode.sh VGraphWasm/Package.swift
    VGraphWasm/Package.resolved VGraphWasm/Sources VGraphWasm/VGraphEditor VGraphWasm/scripts)

if [ ! -f website/Package/VGRAPH_BUILD ]; then
    echo "Preflight: no record of which commit built website/Package — rebuild it with 'just release'." >&2
    exit 1
fi
read -r BUILT BUILT_SUM < website/Package/VGRAPH_BUILD
FAIL=0
if [ "$BUILT" = unknown ]; then
    echo "Preflight: the engine was built from an unknown commit — git could not read the checkout. Rebuild it here." >&2
    FAIL=1
elif [ "${BUILT%-dirty}" != "$BUILT" ]; then
    echo "Preflight: the engine was built from uncommitted changes on ${BUILT:0:12} — commit and merge them, then rebuild with 'just release'." >&2
    FAIL=1
elif ! git merge-base --is-ancestor "$BUILT" origin/main 2>/dev/null; then
    echo "Preflight: the engine was built from ${BUILT:0:12}, which is not on origin/main." >&2
    FAIL=1
elif ! git diff --quiet "$BUILT" HEAD -- "${ENGINE_PATHS[@]}"; then
    echo "Preflight: the engine sources changed since the build at ${BUILT:0:12} — rebuild with 'just release'." >&2
    FAIL=1
fi
for w in website/Package "$@"; do
    if [ "$(shasum -a 256 < "$w/VGraphWasm.wasm" | cut -d' ' -f1)" != "$BUILT_SUM" ]; then
        echo "Preflight: $w/VGraphWasm.wasm is not the engine built at ${BUILT:0:12}." >&2
        FAIL=1
    fi
done
echo "$BUILT"
exit "$FAIL"
