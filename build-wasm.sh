#!/bin/bash
# Build the Embedded-Swift WASM package and deploy it to website/Package.
#
# Single source of truth for the WASM build + deploy step. `just wasm` wraps this,
# and `just build`/`just release` call it; run it directly for a fast dev loop when
# you only need to rebuild the WASM and refresh what the website serves.
#
# It does NOT run the host `swift test` suite — that gating lives in `just test`.
set -e  # Exit on any error

OPTIMIZE=false
USE_CDN=false
RUN_SMOKE=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Builds VGraphWasm and deploys it to website/Package."
    echo ""
    echo "Options:"
    echo "  --release       Build with release configuration + wasm-opt (default: debug)"
    echo "  --use-cdn       Use CDN for JavaScript dependencies"
    echo "  --skip-smoke    Skip the Node WASM smoke tests after deploy"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Quick debug build + deploy + smoke tests"
    echo "  $0 --release             # Optimized release build + deploy + smoke tests"
    echo "  $0 --release --skip-smoke"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --release) OPTIMIZE=true; shift ;;
        --use-cdn) USE_CDN=true; shift ;;
        --skip-smoke) RUN_SMOKE=false; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Resolve repo root from this script's location so it works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Ensure swiftly's shim is ahead of the system swift. Non-login shells (editor
# task runners, CI, Claude Code's own shell) never source ~/.zprofile, so
# without this `swift` can resolve to /usr/bin/swift (CommandLineTools) —
# which lacks the Embedded Swift wasm32 libs — instead of the swiftly-managed
# toolchain that has them.
export PATH="$HOME/.swiftly/bin:$PATH"

STEP_START=$SECONDS
cd VGraphWasm

export TOOLCHAINS=$(swiftly use)
# The Embedded WASM SDK, derived from .swift-version so it matches the toolchain.
. "$SCRIPT_DIR/scripts/wasm-sdk.sh"
# Enable BridgeJS experimental feature for @JS macro support.
export JAVASCRIPTKIT_EXPERIMENTAL_BRIDGEJS=1
# Enable JavaScriptKit's Embedded-Swift code paths (cSettings + Embedded feature
# in JSK targets). Required when SWIFT_SDK_ID points at a `-embedded` artifact.
export JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM=true
# swiftGraphviz's manifest selects its wasm artifact bundle (CGraphvizWasm) when
# this is set — the manifest runs on the host and can't otherwise detect a wasm
# cross-compile. Without it, it would pick the macOS xcframework and fail to link.
export GRAPHVIZ_WASM=1

# Resolve the xctoolchain's `libswiftUnicodeDataTables.a` directory and run an
# early sanity check, so a misconfigured toolchain fails here with a clear
# diagnostic instead of at link time with 50 undefined-symbol errors.
#
# VGraphWasm/Package.swift can resolve the same path itself (it shells out to
# `swift -print-target-info`) — this block just gives users the early signal,
# and exports the value for any tooling that wants to inspect it.
if [ -z "${EMBEDDED_UNICODE_LIB_DIR:-}" ]; then
    SWIFT_RUNTIME_RESOURCE_PATH=$(swift -print-target-info | sed -n 's/.*"runtimeResourcePath": "\(.*\)".*/\1/p')
    if [ -n "$SWIFT_RUNTIME_RESOURCE_PATH" ]; then
        EMBEDDED_UNICODE_LIB_DIR="${SWIFT_RUNTIME_RESOURCE_PATH}/embedded/wasm32-unknown-none-wasm"
    fi
fi
if [ -z "${EMBEDDED_UNICODE_LIB_DIR:-}" ] || [ ! -f "${EMBEDDED_UNICODE_LIB_DIR}/libswiftUnicodeDataTables.a" ]; then
    echo "ERROR: libswiftUnicodeDataTables.a is required for the Embedded WASM link." >&2
    echo "       Looked for it under '${EMBEDDED_UNICODE_LIB_DIR:-<unset>}'." >&2
    echo "       Set EMBEDDED_UNICODE_LIB_DIR to the directory containing the archive," >&2
    echo "       or ensure 'swift -print-target-info' returns a valid runtimeResourcePath." >&2
    exit 1
fi
export EMBEDDED_UNICODE_LIB_DIR

# wasm-strip and wasm-opt can be installed yet unlinked (see scripts/brew-kegs.sh).
. "$SCRIPT_DIR/scripts/brew-kegs.sh"
append_brew_kegs wabt binaryen

# Build configuration
BUILD_CONFIG="debug"
if [ "$OPTIMIZE" = true ]; then
    BUILD_CONFIG="release"

    # A release build MUST be size-optimized. The wasm-strip/wasm-opt steps below
    # are `command -v` guarded, so a machine missing them would silently produce a
    # ~6x oversized binary (20MB instead of 3.3MB) and still exit 0 — an
    # unoptimized artifact would ship unnoticed. Fail here instead, and do it
    # before the ~70s build rather than after it.
    MISSING_OPT_TOOLS=""
    command -v wasm-strip >/dev/null 2>&1 || MISSING_OPT_TOOLS="${MISSING_OPT_TOOLS}\n         - wasm-strip   (brew install wabt)"
    command -v wasm-opt >/dev/null 2>&1 || MISSING_OPT_TOOLS="${MISSING_OPT_TOOLS}\n         - wasm-opt     (brew install binaryen)"
    if [ -n "$MISSING_OPT_TOOLS" ]; then
        echo "ERROR: --release requires the wasm size-optimisation tools, but these are missing:" >&2
        printf "%b\n" "$MISSING_OPT_TOOLS" >&2
        echo "       Without them the release wasm is ~6x larger (20MB vs 3.3MB)." >&2
        echo "       Install them, or omit --release for an unoptimized debug build." >&2
        echo "       (If they ARE installed, check PATH — this script only prepends ~/.swiftly/bin.)" >&2
        exit 1
    fi

    echo "Building with RELEASE configuration and optimizations..."
else
    echo "Building with DEBUG configuration (quick build, larger binary)..."
fi

# CDN flag
CDN_FLAG=""
if [ "$USE_CDN" = true ]; then
    CDN_FLAG="--use-cdn"
    echo "Using CDN for JavaScript dependencies..."
fi

# First, ensure plugin tools are built
swift package plugin --list

# Regenerate BridgeJS bindings from @JS annotations in Main.swift.
# The `js` plugin further down reads Sources/Generated/JavaScript/BridgeJS.json
# to emit the JS glue (bridge-js.js / bridge-js.d.ts) — without this step a
# newly-added @JS function gets into the WASM but stays invisible from JS.
# `--target VGraphWasm` is required: the plugin's default target filter doesn't
# match this package, so omitting it makes the command a no-op. The tool does
# content-based change detection, so it only rewrites files when signatures
# actually changed.
echo "Regenerating BridgeJS bindings..."
swift package --allow-writing-to-package-directory bridge-js --target VGraphWasm

# Build the JS package
# `--build-system native`, not SwiftPM 6.4's new `swiftbuild` default. PackageToJS
# infers the target triple from the *build directory name* — the wasm's
# grandparent directory (Plugins/PackageToJS/Sources/PackageToJS.swift:79) — and
# decides `IS_WASI` from it. The native layout is
# `.build/wasm32-unknown-wasip1/<config>/`, which answers that question; the new
# one is `.build/out/Products/Debug-webassembly-wasm32/`, whose grandparent is
# `Products`, so `IS_WASI` comes out false and the generated `platforms/browser.js`
# omits the WASI shim entirely. The wasm still imports `wasi_snapshot_preview1`,
# so the page dies at instantiation with "module is not an object or function" —
# and nothing in the build fails, so the broken package deploys quietly.
echo "Running: swift package --build-system native --swift-sdk $SWIFT_SDK_ID js -c $BUILD_CONFIG $CDN_FLAG"
echo "  (EMBEDDED_UNICODE_LIB_DIR=$EMBEDDED_UNICODE_LIB_DIR — picked up by VGraphWasm/Package.swift)"
swift package --build-system native --swift-sdk $SWIFT_SDK_ID js -c $BUILD_CONFIG $CDN_FLAG

echo "Moving package to website..."
rm -f ../website/VGraphExec.wasm
rm -rf ../website/Package
cp -R .build/plugins/PackageToJS/outputs/Package ../website/

# --- BridgeJS BrowserInterop merge (ElementaryUI editor) --------------------
# PackageToJS only links the root bridged target's (VGraphWasm) BridgeJS
# skeleton, so the generated bridge-js.js provides our @JS exports but NOT the
# `BrowserInterop` import module that ElementaryUI's wasm needs. We merge our
# export wrappers into elementary-ui's fully-generated instantiator (which does
# provide BrowserInterop). See scripts/merge-bridge-js.py for the full rationale.
ELEMENTARY_BRIDGE_JS=".build/checkouts/elementary-ui/BrowserRuntime/src/generated/bridge-js.js"
if [ -f "$ELEMENTARY_BRIDGE_JS" ]; then
    echo "Merging BrowserInterop BridgeJS glue into deployed bridge-js.js..."
    python3 scripts/merge-bridge-js.py \
        "$ELEMENTARY_BRIDGE_JS" \
        ../website/Package/bridge-js.js \
        ../website/Package/bridge-js.js
else
    echo "ERROR: elementary-ui generated bridge-js.js not found at $ELEMENTARY_BRIDGE_JS." >&2
    echo "       The ElementaryUI editor mount needs the BrowserInterop import glue." >&2
    exit 1
fi

# Apply additional optimizations only in release mode
if [ "$OPTIMIZE" = true ]; then
    # Both tools are guaranteed present — validated up front when --release was
    # parsed, so these run unconditionally rather than being silently skipped.
    echo "Stripping WASM binary to reduce size..."
    wasm-strip ../website/Package/VGraphWasm.wasm

    echo "Running wasm-opt for additional size optimization..."
    wasm-opt -Oz --enable-bulk-memory --enable-nontrapping-float-to-int \
        --strip-debug --strip-dwarf --strip-producers \
        --vacuum \
        ../website/Package/VGraphWasm.wasm \
        -o ../website/Package/VGraphWasm.wasm
else
    echo "Skipping wasm-strip and wasm-opt (only applied in --release mode)"
fi


echo "Patching browser.js to add getImports function..."
# Insert getImports function before the closing brace of the return object
awk '
/^    return {$/,/^    }$/ {
    if (/^    }$/ && !inserted) {
        print "        getImports(importsContext) {"
        print "            return {};"
        print "        }"
        inserted = 1
    }
}
{ print }
' ../website/Package/platforms/browser.js > ../website/Package/platforms/browser.js.tmp
mv ../website/Package/platforms/browser.js.tmp ../website/Package/platforms/browser.js

cd ..
echo "WASM build completed in $(( SECONDS - STEP_START ))s"

# Show final size
echo ""
echo "Final WASM size:"
ls -lh website/Package/VGraphWasm.wasm | awk '{print "  " $5 " - " $9}'

# WASM smoke harness — Phase 0 safety net.
# Loads website/Package/index.js in Node, calls the 4 layout-free @JS functions
# against minimal fixtures for every notation. Fails the build on regression.
if [ "$RUN_SMOKE" = true ]; then
    STEP_START=$SECONDS
    echo ""
    echo "Running WASM smoke tests..."
    pushd VGraphWasm/Tests-JS > /dev/null
    if [ ! -d node_modules ]; then
        npm install --silent
    fi
    ./node_modules/.bin/vitest run --reporter=default
    popd > /dev/null
    echo "WASM smoke tests completed in $(( SECONDS - STEP_START ))s"
else
    echo "Skipping WASM smoke tests (--skip-smoke)"
fi
