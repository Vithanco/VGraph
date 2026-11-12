#!/usr/bin/env bash
# Records which VGraph commit built a wasm package, as `<commit>[-dirty] <sha256>`
# (or `unknown <sha256>`)
# in <package-dir>/VGRAPH_BUILD. The package directory is not tracked, so this is
# the only link from an artifact to its source; publish-plugins reads it.
# Run from the repository root: record-engine-build.sh website/Package
set -euo pipefail

DIR=$1
# Git may be unable to name the commit (a tarball, or a CI checkout owned by
# another user): the build must still succeed, and publish-plugins refuses it.
if REV=$(git rev-parse HEAD 2>/dev/null) && STATUS=$(git status --porcelain 2>/dev/null); then
    [ -z "$STATUS" ] || REV="$REV-dirty"
else
    REV=unknown
fi
echo "$REV $(shasum -a 256 < "$DIR/VGraphWasm.wasm" | cut -d' ' -f1)" > "$DIR/VGRAPH_BUILD"
