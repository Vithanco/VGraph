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
(`swift-6.4.0-RELEASE_wasm-embedded`), builds this package for WASI, generates
the JavaScript bindings with BridgeJS, and copies the output to
`../website/Package/`.

## The Unicode tables

`libswiftUnicodeDataTables.a` must be linked or every `String` comparison fails
to link (see AGENTS.md). `build-wasm.sh` finds it and exports
`EMBEDDED_UNICODE_LIB_DIR`; `Package.swift` otherwise walks `$PATH` for an
`*.xctoolchain/usr/bin` entry. Where neither works, set the variable yourself:

- **Linux swiftly** has no `.xctoolchain` in its layout
  (`~/.swiftly/toolchains/<name>/usr/bin`), so the `$PATH` walk misses it.
- **Other toolchains may not ship the archive.** Both `Package.swift` and
  `build-wasm.sh` fail with a clear error. Once the wasm SDK ships it, this
  machinery can go.
- **Building for WASI from Xcode is untested.**
