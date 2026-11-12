# VGraphWasm

The WebAssembly build of VGraph: the engine's `@JS` functions and the editor,
in one module. A separate package so the main one builds with plain
`swift build` and no WASI toolchain. The exports are in `Sources/Main.swift`.

## Building

From the root VGraph directory:

```bash
just wasm           # build + deploy the WASM package (debug)
just wasm --release # optimized build with wasm-opt
```

`just wasm` wraps `build-wasm.sh`, which switches to the WASM SDK
(`swift-<.swift-version>-RELEASE_wasm-embedded`), builds this package for WASI, generates
the JavaScript bindings with BridgeJS, and copies the output to
`../website/Package/`.

## The Unicode tables

`libswiftUnicodeDataTables.a` must be linked, or every `String` comparison fails
to link. Where it lives, how the build finds it and what to do when it can't:
[docs/wasm-unicode-tables.md](../docs/wasm-unicode-tables.md). Building for
WASI from Xcode is untested.
