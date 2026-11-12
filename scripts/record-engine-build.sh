#!/usr/bin/env bash
# Records which VGraph commit built a wasm package, as `<commit>[-dirty] <sha256>`
# in <package-dir>/VGRAPH_BUILD. The package directory is not tracked, so this is
# the only link from an artifact to its source; publish-plugins reads it.
# Run from the repository root: record-engine-build.sh website/Package
set -euo pipefail

DIR=$1
REV=$(git rev-parse HEAD)
[ -z "$(git status --porcelain)" ] || REV="$REV-dirty"
echo "$REV $(shasum -a 256 < "$DIR/VGraphWasm.wasm" | cut -d' ' -f1)" > "$DIR/VGRAPH_BUILD"
