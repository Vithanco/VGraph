#!/usr/bin/env bash
# Install the wasm SDK on a CI Linux box. Plugin CI runs this from the VGraph ref it
# builds, so a Swift bump here cannot leave the plugin repos on the wrong SDK.
set -euo pipefail

# swift.org's checksum for this release; it must change along with .swift-version.
CHECKSUM=783e6128d174d9f975b4eda68be02a5960681b723ef372e6876a7c2543a365d8

V=$(tr -d '[:space:]' < "$(dirname "$0")/../.swift-version")
swift sdk install \
    "https://download.swift.org/swift-$V-release/wasm-sdk/swift-$V-RELEASE/swift-$V-RELEASE_wasm.artifactbundle.tar.gz" \
    --checksum "$CHECKSUM"
