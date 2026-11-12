#!/usr/bin/env bash
# The Embedded wasm link needs the toolchain's libswiftUnicodeDataTables.a. When
# the lookup fails, the error must say why — swift's own complaint and where it
# looked — because "<unset>" alone has sent us searching the disk more than once.
set -uo pipefail

FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=1; }
# check "<test line>" <command...>: passes when the command succeeds.
check() { local name=$1; shift; "$@" || fail "$name"; }

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

TOOLCHAIN="$WORK/tc/usr/lib/swift"
LIB="$TOOLCHAIN/embedded/wasm32-unknown-none-wasm"
mkdir -p "$LIB" "$WORK/bin"
touch "$LIB/libswiftUnicodeDataTables.a"

# stub_swift <body>: a `swift` whose -print-target-info runs <body>.
stub_swift() {
    printf '#!/bin/sh\n%s\n' "$1" > "$WORK/bin/swift"
    chmod +x "$WORK/bin/swift"
}
# resolve [VAR=value...]: sources the helper and sets OUT, STATUS and DIR.
resolve() {
    OUT=$(env -u EMBEDDED_UNICODE_LIB_DIR "$@" PATH="$WORK/bin:$PATH" bash -c \
        '. "$1" && echo "DIR=$EMBEDDED_UNICODE_LIB_DIR"' _ "$REPO/scripts/embedded-unicode.sh" 2>&1)
    STATUS=$?
    DIR=$(sed -n 's/^DIR=//p' <<<"$OUT")
}

stub_swift "printf '{\"paths\": {\n    \"runtimeResourcePath\": \"$TOOLCHAIN\"\n}}\n'"
resolve
check "1. Given swift reports a runtimeResourcePath holding the archive, when the helper is sourced, then EMBEDDED_UNICODE_LIB_DIR is its embedded wasm32 dir" \
    test "$STATUS" = 0 -a "$DIR" = "$LIB"

stub_swift "[ -z \"\${TOOLCHAINS:-}\" ] || { echo 'TOOLCHAINS leaked' >&2; exit 1; }
printf '{\"runtimeResourcePath\": \"$TOOLCHAIN\"}\n'"
resolve TOOLCHAINS="Swift 6.4.1 (/repo/.swift-version)"
check "10. Given a stale TOOLCHAINS in the environment, when the helper is sourced, then swift runs without it and the lookup succeeds" \
    test "$STATUS" = 0 -a "$DIR" = "$LIB"

stub_swift "exit 1"
resolve EMBEDDED_UNICODE_LIB_DIR="$LIB"
check "2. Given EMBEDDED_UNICODE_LIB_DIR is set, when the helper is sourced, then it is kept and swift is not asked" \
    test "$STATUS" = 0 -a "$DIR" = "$LIB"

stub_swift "echo 'STUB: swiftly has picked another toolchain' >&2; exit 1"
resolve
check "3. Given swift fails, when the helper is sourced, then it fails" \
    test "$STATUS" != 0
check "4. Given swift fails, when the helper is sourced, then the error repeats what swift said" \
    grep -q "STUB: swiftly has picked another toolchain" <<<"$OUT"

stub_swift "printf '{\"runtimeResourcePath\": \"$WORK/elsewhere/usr/lib/swift\"}\n'"
resolve
check "5. Given the toolchain has no archive, when the helper is sourced, then it fails" \
    test "$STATUS" != 0
check "6. Given the toolchain has no archive, when the helper is sourced, then the error names the directory it looked in" \
    grep -q "$WORK/elsewhere/usr/lib/swift/embedded/wasm32-unknown-none-wasm" <<<"$OUT"
check "7. Given any failure, when the helper is sourced, then the error points at the doc that explains the lookup" \
    grep -q "docs/wasm-unicode-tables.md" <<<"$OUT"

check "8. Given build-wasm.sh, when read, then it sources scripts/embedded-unicode.sh" \
    grep -q "scripts/embedded-unicode.sh" "$REPO/build-wasm.sh"
# swiftly 1.2's bare `swiftly use` prints a sentence, not a toolchain id; put in
# TOOLCHAINS, it makes the swiftly shim refuse to run swift at all.
check "9. Given build-wasm.sh, when read, then it does not set TOOLCHAINS from \`swiftly use\`" \
    bash -c '! grep -q "TOOLCHAINS=.*swiftly use" "$1"' _ "$REPO/build-wasm.sh"

exit $FAILED
