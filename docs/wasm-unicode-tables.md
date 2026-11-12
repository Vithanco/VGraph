# The Embedded Unicode tables

Every `String ==`, `hasPrefix`, `contains` and `split` in the wasm module needs
Swift's Unicode normalization data. Embedded Swift doesn't link it by itself.
The build takes it from the **host toolchain**:

```
<toolchain>/usr/lib/swift/embedded/wasm32-unknown-none-wasm/libswiftUnicodeDataTables.a
```

The `swift-<version>-RELEASE_wasm` SDK bundles under
`~/Library/org.swift.swiftpm/swift-sdks/` carry a copy too, inside their own
`swift.xctoolchain`. The build doesn't use those copies, so seeing one there
doesn't mean the build can find the archive.

With swiftly on macOS, `<toolchain>` is
`~/Library/Developer/Toolchains/swift-<.swift-version>-RELEASE.xctoolchain`.
`swiftly use --print-location` prints it. Without the archive, the link fails
with about 50 undefined `_swift_stdlib_getNormData`-style symbols.

## How the build finds it

`build-wasm.sh` sources `scripts/embedded-unicode.sh`, which exports
`EMBEDDED_UNICODE_LIB_DIR`:

1. If `EMBEDDED_UNICODE_LIB_DIR` is already set, it is used.
2. Otherwise it takes `runtimeResourcePath` from `swift -print-target-info` and
   appends `embedded/wasm32-unknown-none-wasm`.

`VGraphWasm/Package.swift` reads that variable and adds the linker flags for
WASI only. If the flags also reached host builds, the macro plugins would try
to link a wasm archive with macOS `ld`. The manifest can't run `swift` itself
because SwiftPM sandboxes it, so when the variable is unset it falls back to
the first `*.xctoolchain/usr/bin` entry on `$PATH`. Under swiftly, `$PATH` holds
`~/.swiftly/bin` instead, so a direct `swift build` of `VGraphWasm` needs the
variable set by hand. Use `build-wasm.sh`.

## When the lookup fails

The error repeats what `swift` said, and that usually points at the cause.
Causes seen so far:

- **`TOOLCHAINS` holds something swiftly doesn't recognise.** The swiftly shim
  then refuses to run `swift` ("swiftly has picked another toolchain").
  swiftly 1.2's bare `swiftly use` prints a sentence, not a toolchain id, and
  `build-wasm.sh` used to export that sentence as `TOOLCHAINS`. The build now
  unsets the variable and lets `.swift-version` choose the toolchain.
- **`swift` is `/usr/bin/swift` (CommandLineTools)**, which has no Embedded
  wasm32 libraries. Non-login shells skip `~/.zprofile`, so `build-wasm.sh`
  puts `~/.swiftly/bin` first in `$PATH`.
- **The pinned toolchain isn't installed.** `swiftly install "$(cat .swift-version)"`.
- **Linux swiftly** keeps toolchains under `~/.swiftly/toolchains/<name>`, with
  no `.xctoolchain` in the path. `print-target-info` still works there; only the
  manifest's `$PATH` fallback misses it.

To check this machine by hand:

```bash
ls "$(swiftly use --print-location)/usr/lib/swift/embedded/wasm32-unknown-none-wasm/libswiftUnicodeDataTables.a"
```

All of this can go once the `_wasm-embedded` SDK links the tables itself.
