#!/bin/bash
# General VGraph deployment script
# Usage: ./deploy.sh <target-directory> [--absolute-path <path>]

set -e

# Derived from this script's own location, not hardcoded: the previous absolute
# path pointed at a checkout that no longer exists, so every run failed on a
# missing package.json. Same approach as setup-plugins.sh.
VGRAPH_DIR="${VGRAPH_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
VERSION="v$(node -p "require('$VGRAPH_DIR/website/dist/package.json').version")"

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <target-directory> [--absolute-path <path>]"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/website/public/vgraph"
    echo "  $0 /path/to/website/Resources/vgraph --absolute-path /vgraph/Package"
    echo ""
    echo "Options:"
    echo "  --absolute-path PATH   Set wasmPath to absolute path (e.g., /vgraph/Package)"
    echo "                         If not set, uses './Package'"
    echo "  --canonical URL        Add rel=canonical to the staged index.html, pointing"
    echo "                         at the page a search engine should prefer"
    exit 1
fi

TARGET_DIR="$1"
ABSOLUTE_PATH=""
CANONICAL_URL=""

# Parse optional --absolute-path
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --absolute-path)
            ABSOLUTE_PATH="$2"
            shift 2
            ;;
        --canonical)
            CANONICAL_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "VGraph Distribution Deployment"
echo "========================================"
echo ""
echo "Source: $VGRAPH_DIR"
echo "Target: $TARGET_DIR"
echo "Version: $VERSION"
if [ -n "$ABSOLUTE_PATH" ]; then
    echo "WASM Path: $ABSOLUTE_PATH (absolute)"
else
    echo "WASM Path: ./Package (relative)"
fi
echo ""

# Verify source files exist
if [ ! -d "$VGRAPH_DIR/website/dist" ]; then
    echo "Error: Distribution not found. Build it first with: just build  (or: just release)"
    exit 1
fi

if [ ! -d "$VGRAPH_DIR/website/Package" ]; then
    echo "Error: WASM package not found. Build it first with: just build  (or: just release)"
    exit 1
fi

# Create target directories
echo "Creating directories..."
mkdir -p "$TARGET_DIR/$VERSION"
mkdir -p "$TARGET_DIR/Package"

# Copy library files
echo "Copying library files..."
cp "$VGRAPH_DIR/website/dist/vgraph-${VERSION}.js" "$TARGET_DIR/$VERSION/"
cp "$VGRAPH_DIR/website/dist/vgraph-${VERSION}.d.ts" "$TARGET_DIR/$VERSION/"
echo "  ✓ vgraph-${VERSION}.js"
echo "  ✓ vgraph-${VERSION}.d.ts"

# Copy the editor page — the interactive surface (the WASM ElementaryUI editor).
# It loads ./Package/index.js relative to itself, so no path rewriting is needed;
# the Package directory is copied alongside it below.
echo "Copying editor..."
cp "$VGRAPH_DIR/website/index.html" "$TARGET_DIR/"
echo "  ✓ index.html"

# The canonical is injected here rather than kept in `website/index.html`, which
# ships to every embedding host: a host that has no /editor/ page of its own
# would be pointing search engines at a URL that does not exist for it. Staging
# is the first moment a site-specific URL is known.
if [ -n "$CANONICAL_URL" ]; then
    python3 - "$TARGET_DIR/index.html" "$CANONICAL_URL" <<'PYEOF'
import io, sys
path, url = sys.argv[1], sys.argv[2]
html = io.open(path, encoding="utf-8").read()
tag = '  <link rel="canonical" href="%s" />\n' % url
if 'rel="canonical"' not in html:
    marker = "</head>"
    html = html.replace(marker, tag + marker, 1)
    io.open(path, "w", encoding="utf-8").write(html)
PYEOF
    echo "  ✓ canonical → $CANONICAL_URL"
fi

# Copy documentation — report per file so a missing source is visible (non-fatal).
echo "Copying documentation..."
copy_doc() {
    if cp "$1" "$TARGET_DIR/" 2>/dev/null; then
        echo "  ✓ $(basename "$1")"
    else
        echo "  ✗ $(basename "$1") — source not found: $1"
    fi
}
copy_doc "$VGRAPH_DIR/website/dist/README.md"
copy_doc "$VGRAPH_DIR/docs/VGL_GUIDE.md"

# Copy WASM package
echo "Copying WASM package..."
rm -rf "$TARGET_DIR/Package"/*
cp -r "$VGRAPH_DIR/website/Package/"* "$TARGET_DIR/Package/"
echo "  ✓ WASM binaries"

# Show summary
echo ""
echo "Deployment summary:"
echo "-------------------"
WASM_SIZE=$(du -h "$TARGET_DIR/Package/VGraphWasm.wasm" | cut -f1)
JS_SIZE=$(du -h "$TARGET_DIR/$VERSION/vgraph-${VERSION}.js" | cut -f1)
echo "  WASM binary: $WASM_SIZE"
echo "  JS library:  $JS_SIZE"

TOTAL_FILES=$(find "$TARGET_DIR" -type f | wc -l)
echo "  Total files: $TOTAL_FILES"

echo ""
echo "========================================"
echo "✓ Deployment complete!"
echo "========================================"
echo ""
echo "Files deployed to: $TARGET_DIR"
echo ""
echo "Integration:"
echo "  Editor URL: <target>/index.html"
echo "  Library:    <target>/$VERSION/vgraph-${VERSION}.js"
echo ""
