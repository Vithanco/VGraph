// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// The xctoolchain (separate from the WASM SDK) ships the Unicode normalization
// data tables at `usr/lib/swift/embedded/wasm32-unknown-none-wasm/libswiftUnicodeDataTables.a`.
// Without linking that archive, Swift's `String` operations (==, hasPrefix,
// contains, split) fail to link in the embedded WASM build with ~50 undefined
// symbols (_swift_stdlib_getNormData & friends).
//
// The path is per-user (depends on where swiftly/Xcode installed the toolchain),
// so it can't be hard-coded here. Resolution order, evaluated when SwiftPM
// loads this manifest:
//   1. `EMBEDDED_UNICODE_LIB_DIR` env var, if set (build-wasm.sh exports it; direct
//      `swift build` users can also set it manually for non-standard layouts).
//   2. Walk `$PATH` for an `*.xctoolchain/usr/bin` entry and derive the embedded
//      lib dir from it. Works for swiftly + Xcode on macOS, the two ways
//      anyone realistically installs an OSS Swift toolchain there.
//
// Why PATH-walking and not `Process` + `swift -print-target-info`: SwiftPM
// evaluates this manifest in a sandbox that blocks Process invocations. PATH
// is exposed though, and on macOS it always has the active toolchain's bin
// directory at the front (set by `swiftly use` / Xcode's toolchain selection).
//
// The platform scope on the resulting linker flag (`.when(platforms: [.wasi])`)
// is essential: passing the same path via `-Xswiftc -Xlinker -Xswiftc -L…` on
// the command line leaks into host-side macro-plugin builds (BridgeJSMacros-tool,
// etc.), which use macOS `ld` and choke on the wasm32 archive.

func resolveEmbeddedUnicodeLibDir() -> String {
    let env = ProcessInfo.processInfo.environment
    // 1. Explicit override.
    if let override = env["EMBEDDED_UNICODE_LIB_DIR"], !override.isEmpty {
        return override
    }
    // 2. Walk PATH for an `*.xctoolchain/usr/bin` entry.
    guard let path = env["PATH"] else { return "" }
    let suffix = ".xctoolchain/usr/bin"
    let binSuffixLength = "/usr/bin".count
    for entry in path.split(separator: ":") {
        let entryString = String(entry)
        guard entryString.hasSuffix(suffix) else { continue }
        // Strip `/usr/bin`, append the embedded subtree.
        let toolchainRoot = String(entryString.dropLast(binSuffixLength))
        return toolchainRoot + "/usr/lib/swift/embedded/wasm32-unknown-none-wasm"
    }
    return ""
}

let embeddedUnicodeLibDir = resolveEmbeddedUnicodeLibDir()
let embeddedUnicodeLinkerFlags: [String] = {
    guard !embeddedUnicodeLibDir.isEmpty else {
        FileHandle.standardError.write(
            Data(
                """
                [VGraphWasm/Package.swift] warning: could not resolve EMBEDDED_UNICODE_LIB_DIR.
                  Embedded WASM builds will fail to link Swift's String operations
                  (== / hasPrefix / contains / split) with "undefined symbol:
                  _swift_stdlib_getNormData" errors. Either set EMBEDDED_UNICODE_LIB_DIR
                  explicitly, or ensure `swift -print-target-info` works on PATH.

                """.utf8))
        return []
    }
    let archive = embeddedUnicodeLibDir + "/libswiftUnicodeDataTables.a"
    guard FileManager.default.fileExists(atPath: archive) else {
        FileHandle.standardError.write(
            Data(
                """
                [VGraphWasm/Package.swift] warning: libswiftUnicodeDataTables.a not found at
                  \(archive)
                  Active toolchain may not ship the embedded Unicode tables. Embedded
                  WASM build will fail at link time.

                """.utf8))
        return []
    }
    return ["-Xlinker", "-L\(embeddedUnicodeLibDir)", "-Xlinker", "-lswiftUnicodeDataTables"]
}()

let package = Package(
    name: "VGraphWasm",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .executable(
            name: "VGraphWasm",
            targets: ["VGraphWasm"]
        )
    ],
    dependencies: [
        .package(name: "VGraph", path: ".."),
        .package(url: "https://github.com/swiftwasm/carton", from: "1.0.0"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", .upToNextMinor(from: "0.59.0")),
        .package(url: "https://github.com/elementary-swift/elementary-ui.git", from: "0.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "VGraphWasm",
            dependencies: [
                .product(name: "App", package: "VGraph"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit", condition: .when(platforms: [.wasi])),
                .target(name: "VGraphEditor"),
            ],
            path: "Sources",
            exclude: [
                "bridge-js.config.json",
                "Generated/JavaScript/BridgeJS.json",
            ],
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ],
            linkerSettings: [
                // Increase stack size to 1MB (default is ~64KB) — needed for deep graph
                // traversal and recursive algorithms.
                .unsafeFlags(["-Xlinker", "-z", "-Xlinker", "stack-size=1048576"], .when(platforms: [.wasi])),
                // Embedded WASM defaults to an executable ABI (has _start); JavaScriptKit
                // requires a reactor (callable library, no _start). Without this the
                // runtime throws "JavaScriptKit supports only WASI reactor ABI" at init.
                .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"], .when(platforms: [.wasi])),
                // Unicode normalization archive — path resolved from
                // `EMBEDDED_UNICODE_LIB_DIR` (set by build-wasm.sh). See top of this file.
                .unsafeFlags(embeddedUnicodeLinkerFlags, .when(platforms: [.wasi])),
            ]
        ),
        // ElementaryUI editor UI, kept out of both the engine and the thin
        // executable. Only real on wasi (ElementaryUI + JavaScriptKit are
        // wasi-conditioned). The
        // VGraphWasm executable depends on this and exposes the @JS entry
        // points that call into it.
        .target(
            name: "VGraphEditor",
            dependencies: [
                .product(name: "App", package: "VGraph"),
                // Menu construction, which lives outside this package so it can
                // be tested in Swift rather than only by JS smoke tests.
                .product(name: "EditorCore", package: "VGraph"),
                // VGraph core — needed so the file that catches the engine's
                // typed `throws(VError)` can see VError's conformances.
                .product(name: "VGraph", package: "VGraph"),
                // The id/class vocabulary the click handlers resolve against is
                // minted by the renderer — see SVGElementId.
                .product(name: "VGraphSVG", package: "VGraph"),
                .product(name: "ElementaryUI", package: "elementary-ui", condition: .when(platforms: [.wasi])),
                .product(name: "JavaScriptKit", package: "JavaScriptKit", condition: .when(platforms: [.wasi])),
            ],
            path: "VGraphEditor",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),
    ]
)
