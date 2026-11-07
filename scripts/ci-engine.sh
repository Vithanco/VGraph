#!/usr/bin/env bash
# Build the optimized engine in a swift:<.swift-version>-noble container, as the
# plugins bundle it. VGraph's CI runs this too, so it cannot rot until a release.
set -euo pipefail

cd "$(dirname "$0")/.."

apt-get update
# The bridge generator refuses to start without node, even with no TypeScript to read.
apt-get install -y --no-install-recommends curl ca-certificates python3 nodejs wabt

# Pinned because the optimizer decides the size the 5 MB limit checks, and noble ships
# binaryen 108, too far behind what a maintainer's release is built with.
BINARYEN=binaryen-version_133
SHA256=2dc9c7813f5375db93d96ead4b78222fcc3e2677bbb832297af4797782a37489
TARBALL=$(mktemp)
curl -fsSL -o "$TARBALL" "https://github.com/WebAssembly/binaryen/releases/download/version_133/$BINARYEN-x86_64-linux.tar.gz"
echo "$SHA256  $TARBALL" | sha256sum -c -
tar -xzf "$TARBALL" -C /usr/local/bin --strip-components=2 "$BINARYEN/bin/wasm-opt"
rm "$TARBALL"

./scripts/ci-wasm-sdk.sh
./build-wasm.sh --release --skip-smoke
./scripts/check-wasm-optimized.sh website/Package/VGraphWasm.wasm
