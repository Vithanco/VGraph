#!/usr/bin/env bash
# Build the optimized engine in a swift:<.swift-version>-noble container, as the
# plugins bundle it. VGraph's CI runs this too, so it cannot rot until a release.
set -euo pipefail

cd "$(dirname "$0")/.."

apt-get update
apt-get install -y --no-install-recommends curl ca-certificates python3 wabt binaryen
./scripts/ci-wasm-sdk.sh
./build-wasm.sh --release --skip-smoke
./scripts/check-wasm-optimized.sh website/Package/VGraphWasm.wasm
