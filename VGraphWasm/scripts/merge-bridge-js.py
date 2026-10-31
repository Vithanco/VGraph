#!/usr/bin/env python3
"""
Merge BridgeJS glue for the ElementaryUI editor build.

WHY THIS EXISTS
---------------
Our wasm module links two sets of BridgeJS bindings:

  1. VGraphWasm's own @JS EXPORTS  (renderGraph, mountEditor, ...)
  2. ElementaryUI/BrowserInterop's IMPORTS  (the ~47 `BrowserInterop.*` DOM
     functions + the `bjs.*` closure trampolines / struct lifts they need)

PackageToJS's `js` plugin only links the skeleton of the *root bridged target*
(VGraphWasm). Its SkeletonCollector does not reach BrowserInterop, which is a
transitively-imported target of the ElementaryUI product (reached only through
`ElementaryUI` -> target dep `BrowserInterop`). As a result the generated
`website/Package/bridge-js.js` provides our exports but NOT the `BrowserInterop`
import module, and the wasm fails to instantiate with:

    WebAssembly.instantiate(): Import #<n> "BrowserInterop": module is not an
    object or function

FIX
---
elementary-ui ships a fully-generated instantiator at
`BrowserRuntime/src/generated/bridge-js.js` (committed at the pinned commit,
produced by the same BridgeJS/JavaScriptKit version). It contains the complete
preamble + `addImports` (bjs superset + BrowserInterop) + struct-helper
registration, but its `createExports` only exposes ElementaryUI's own exports —
not ours.

So we take elementary's generated instantiator as the base and MERGE our export
wrappers into its `createExports` (keeping elementary's struct-helper setup that
its `bjs.swift_js_struct_lift_*` functions depend on). Both files come from the
same generator, so they share identical scope identifiers (`swift`, `memory`,
`decodeString`, `setException`, `tmpRetString`, `textEncoder`, `_exports`,
`structHelpers`), and the merge is a pure textual splice.

Usage:
  merge-bridge-js.py <elementary_base.js> <our_generated.js> <output.js>
"""
import re
import sys


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: merge-bridge-js.py <base> <ours> <out>", file=sys.stderr)
        return 2

    base_path, ours_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(base_path, encoding="utf-8") as f:
        base = f.read()
    with open(ours_path, encoding="utf-8") as f:
        ours = f.read()

    # Extract our export entries: everything inside `const exports = { ... }`
    # within our createExports, up to the closing that precedes `_exports`.
    m = re.search(
        r"const exports = \{\n(.*?)\n            \};\n            _exports = exports;",
        ours,
        re.S,
    )
    if not m:
        print("ERROR: could not locate our exports object in " + ours_path, file=sys.stderr)
        return 1
    entries = m.group(1)

    # Sanity: our expected exports must be present.
    for required in ("mountEditor:", "setEditorVGL:", "renderGraph:", "exportToVGL:"):
        if required not in entries:
            print(f"ERROR: expected export {required} missing from our glue", file=sys.stderr)
            return 1

    # The base must actually provide the BrowserInterop import module.
    if 'importObject["BrowserInterop"]' not in base:
        print("ERROR: base glue does not define BrowserInterop imports", file=sys.stderr)
        return 1

    # Insert our entries into the base's createExports exports object, right
    # before it closes (`            };\n            _exports = exports;`).
    marker = "            };\n            _exports = exports;"
    idx = base.rfind(marker)
    if idx == -1:
        print("ERROR: could not locate exports close marker in base glue", file=sys.stderr)
        return 1

    merged = base[:idx] + entries + "\n" + base[idx:]

    # Guard against accidental double-merge on repeated runs.
    if merged.count("function bjs_mountEditor(") != 1:
        print("ERROR: unexpected number of mountEditor definitions after merge", file=sys.stderr)
        return 1

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(merged)

    print(
        f"merge-bridge-js: merged {entries.count('function bjs_')} exports into "
        f"BrowserInterop-enabled instantiator -> {out_path}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
