#!/usr/bin/env bash
# Install the wasm SDK on a CI Linux box. Plugin CI runs this from the VGraph ref it
# builds, so a Swift bump here cannot leave the plugin repos on the wrong SDK.
set -euo pipefail

# swift.org's checksum for this release; it must change along with .swift-version.
CHECKSUM=5f24408dc9737ce4cb23b7e3ed4306cabfa02cc02f22ab260b14579b955d4b12

V=$(tr -d '[:space:]' < "$(dirname "$0")/../.swift-version")
swift sdk install \
    "https://download.swift.org/swift-$V-release/wasm-sdk/swift-$V-RELEASE/swift-$V-RELEASE_wasm.artifactbundle.tar.gz" \
    --checksum "$CHECKSUM"
