# Sourced, not run. Exports EMBEDDED_UNICODE_LIB_DIR, the toolchain directory
# holding libswiftUnicodeDataTables.a, or explains why it could not. Failing
# here beats ~50 undefined _swift_stdlib_getNormData symbols at link time.
# Background: docs/wasm-unicode-tables.md.

_embedded_unicode_fail() {
    echo "ERROR: libswiftUnicodeDataTables.a is required for the Embedded WASM link." >&2
    printf '       %s\n' "$@" >&2
    echo "       See docs/wasm-unicode-tables.md." >&2
    return 1
}

_embedded_unicode_resolve() {
    if [ -z "${EMBEDDED_UNICODE_LIB_DIR:-}" ]; then
        local info resource
        # A stale TOOLCHAINS makes the swiftly shim refuse to run swift at all.
        if ! info=$(env -u TOOLCHAINS swift -print-target-info 2>&1); then
            _embedded_unicode_fail "\`swift -print-target-info\` failed with:" "$info"
            return 1
        fi
        resource=$(sed -n 's/.*"runtimeResourcePath": *"\([^"]*\)".*/\1/p' <<<"$info")
        if [ -z "$resource" ]; then
            _embedded_unicode_fail "\`swift -print-target-info\` reported no runtimeResourcePath."
            return 1
        fi
        EMBEDDED_UNICODE_LIB_DIR="$resource/embedded/wasm32-unknown-none-wasm"
    fi
    if [ ! -f "$EMBEDDED_UNICODE_LIB_DIR/libswiftUnicodeDataTables.a" ]; then
        _embedded_unicode_fail "Not found in '$EMBEDDED_UNICODE_LIB_DIR'."
        return 1
    fi
    export EMBEDDED_UNICODE_LIB_DIR
}

_embedded_unicode_resolve
