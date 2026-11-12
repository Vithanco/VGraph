#!/usr/bin/env bash
# Install the wasm SDK on a CI Linux box. Plugin CI runs this from the VGraph ref it
# builds, so a Swift bump here cannot leave the plugin repos on the wrong SDK.
set -euo pipefail

# swift.org's checksum for this release; it must change along with .swift-version.
CHECKSUM=83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5

V=$(tr -d '[:space:]' < "$(dirname "$0")/../.swift-version")
swift sdk install \
    "https://download.swift.org/swift-$V-release/wasm-sdk/swift-$V-RELEASE/swift-$V-RELEASE_wasm.artifactbundle.tar.gz" \
    --checksum "$CHECKSUM"
