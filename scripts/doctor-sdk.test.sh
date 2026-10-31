#!/usr/bin/env bash
# The wasm build needs the Embedded Swift SDK that matches the pinned toolchain.
# `just doctor` must say when it is missing without failing native-only
# contributors, and the id must follow .swift-version so a bump cannot leave the
# build on the wrong SDK.
set -uo pipefail

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
# check "<test line>" <command...>: passes when the command succeeds.
check() { local name=$1; shift; "$@" || fail "$name"; }

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JUST=$(command -v just)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A copy of the repo's moving parts, so .swift-version can be a made-up value.
mkdir -p "$WORK/repo"
cp "$REPO/justfile" "$WORK/repo/"
cp -R "$REPO/scripts" "$WORK/repo/scripts"
echo "9.9.9" > "$WORK/repo/.swift-version"

# A PATH holding only what just and its recipes need, so the host's own swift
# (the /usr/bin shim included) cannot answer for us.
BIN="$WORK/bin"
mkdir -p "$BIN"
for tool in bash env sh cat grep sed head tail tr dirname; do
    ln -s "$(command -v "$tool")" "$BIN/$tool"
done
for tool in swiftly node npm jq wasm-opt wasm-strip python3; do
    printf '#!/bin/sh\nexit 0\n' > "$BIN/$tool"
done
printf '#!/bin/sh\n[ "$1 $2" = "sdk list" ] && printf "%%s\\n" "$STUB_SDKS"\nexit 0\n' > "$BIN/swift"
chmod +x "$BIN"/swiftly "$BIN"/node "$BIN"/npm "$BIN"/jq "$BIN"/wasm-opt \
    "$BIN"/wasm-strip "$BIN"/python3 "$BIN"/swift

# doctor <sdks>: sets OUT and STATUS for `just doctor` with swift listing <sdks>.
doctor() {
    OUT=$(cd "$WORK/repo" && PATH="$BIN" STUB_SDKS="$1" "$JUST" doctor 2>&1)
    STATUS=$?
}
sdk_id() { (cd "${1:-$WORK/repo}" && . "$WORK/repo/scripts/wasm-sdk.sh" && echo "$SWIFT_SDK_ID"); }
last_line() { echo "$OUT" | tail -n 1; }

HAS=swift-9.9.9-RELEASE_wasm-embedded

# scripts/wasm-sdk.sh — one place for the SDK id
check "1. Given a .swift-version of 9.9.9, when the file is sourced, then SWIFT_SDK_ID is swift-9.9.9-RELEASE_wasm-embedded" \
    test "$(sdk_id)" = "$HAS"
echo "8.8.8" > "$WORK/repo/.swift-version"
check "2. when .swift-version changes to 8.8.8 and the file is sourced again, then SWIFT_SDK_ID follows it" \
    test "$(sdk_id)" = "swift-8.8.8-RELEASE_wasm-embedded"
echo "9.9.9" > "$WORK/repo/.swift-version"
check "3. when sourced from another working directory, then SWIFT_SDK_ID still comes from the repo's .swift-version" \
    test "$(sdk_id /)" = "$HAS"

# build-wasm.sh — no second copy
check "4. Given the script, when read, then it sources scripts/wasm-sdk.sh" \
    grep -q "wasm-sdk.sh" "$REPO/build-wasm.sh"
check "5. Given the script, when read, then it does not spell out a swift-…-RELEASE_wasm-embedded id itself" \
    bash -c '! grep -Eq "swift-[0-9.]+-RELEASE_wasm" "$1"' _ "$REPO/build-wasm.sh"

# just doctor — SDK reporting
doctor "$HAS"
check "6. Given swift lists swift-9.9.9-RELEASE_wasm-embedded, when doctor runs, then it shows ✅ for the SDK" \
    grep -q "✅ $HAS" <<<"$OUT"
check "11. Given the SDK is present and every required tool present, when doctor runs, then the last line is \"All good.\"" \
    test "$(last_line)" = "All good."

doctor "swift-9.8.0-RELEASE_wasm-embedded"
check "7. Given swift lists only swift-9.8.0-RELEASE_wasm-embedded, when doctor runs, then it reports the 9.9.9 SDK as missing, marked optional" \
    grep -q "$HAS (optional)" <<<"$OUT"
check "8. Given a missing SDK, when doctor runs, then the output names the README section that has the install command" \
    grep -q "README.md#building" <<<"$OUT"
check "9. Given a missing SDK and every required tool present, when doctor runs, then it exits 0" \
    test "$STATUS" = 0
check "10. Given a missing SDK, when doctor runs, then the last line says the WASM build is unavailable without the SDK and how to install it" \
    bash -c 'case "$1" in "WASM build unavailable without SDK. Install: https://swift.org/"*) ;; *) exit 1 ;; esac' _ "$(last_line)"

doctor "swift-9.9.9-RELEASE_wasm"
check "12. Given swift lists the _wasm SDK for 9.9.9 but not _wasm-embedded, when doctor runs, then the embedded SDK is reported missing" \
    grep -q "$HAS (optional)" <<<"$OUT"

rm "$BIN/swift"
doctor "$HAS"
check "13. Given swift is not installed, when doctor runs, then swift is reported missing and the SDK check does not crash" \
    bash -c 'echo "$1" | grep -q "❌ swift" && ! echo "$1" | grep -q "not found"' _ "$OUT"

printf '#!/bin/sh\n[ "$1 $2" = "sdk list" ] && printf "%%s\\n" "$STUB_SDKS"\nexit 0\n' > "$BIN/swift"
chmod +x "$BIN/swift"
rm "$BIN/jq"
doctor "$HAS"
check "14. Given a missing required tool and a present SDK, when doctor runs, then it still exits 1" \
    test "$STATUS" = 1

exit $FAILED
