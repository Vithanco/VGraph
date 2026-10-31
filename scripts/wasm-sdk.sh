# Sourced, not run. The Embedded Swift SDK must match the pinned toolchain, so
# the id is derived from .swift-version instead of being spelled out beside it.
SWIFT_SDK_ID="swift-$(tr -d '[:space:]' < "$(dirname "${BASH_SOURCE[0]}")/../.swift-version")-RELEASE_wasm-embedded"
export SWIFT_SDK_ID
