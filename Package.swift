// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VGraph",
    platforms: [
        .iOS("18.0"),
        .macOS("15.0"),
    ],
    products: [
        .library(
            name: "VGraph",
            targets: ["VGraph"]
        ),
        .library(
            name: "VGLanguage",
            targets: ["VGLanguage"]
        ),
        .library(
            name: "VGraphSVG",
            targets: ["VGraphSVG"]
        ),
        .library(
            name: "VGraphvizLib",
            targets: ["VGraphvizLib"]
        ),
        .library(
            name: "App",
            targets: ["App"]
        ),
        .library(
            name: "MathUtils",
            targets: ["MathUtils"]
        ),
        .library(
            name: "EditorCore",
            targets: ["EditorCore"]
        ),
        .executable(
            name: "vgraph-cli",
            targets: ["vgraph-cli"]
        ),
        .executable(
            name: "vgraph-mcp",
            targets: ["vgraph-mcp"]
        ),
        .executable(
            name: "vgraph-mcp-http",
            targets: ["vgraph-mcp-http"]
        ),
        .library(
            name: "VGraphMCPTools",
            targets: ["VGraphMCPTools"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.10.0"),
        .package(url: "https://github.com/Vithanco/swiftGraphviz.git", .upToNextMinor(from: "0.9.0")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        // Core: VGraph domain
        .target(
            name: "VGraph",
            dependencies: [
                "MathUtils"
            ],
            path: "Sources/VGraph",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),

        // VGL (Vithanco Graph Language) module - Parser and Exporter (depends on VGraph)
        .target(
            name: "VGLanguage",
            dependencies: [
                "VGraph"
            ],
            path: "Sources/VGLanguage",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),

        // Native SVG rendering module (depends on VGraph)
        .target(
            name: "VGraphSVG",
            dependencies: [
                "VGraph"
            ],
            path: "Sources/VGraphSVG",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),

        // In-process Graphviz module - uses swiftGraphviz C library directly
        // In-process Graphviz module - uses swiftGraphviz C library directly
        .target(
            name: "VGraphvizLib",
            dependencies: [
                "VGraph",
                .product(name: "SwiftGraphviz", package: "SwiftGraphviz"),
            ],
            path: "Sources/VGraphvizLib",
            swiftSettings: [
                .enableExperimentalFeature("Extern"),
                // wasm: in-process Graphviz layout via swiftGraphviz (>= 0.7.1).
                // No signal define / link libs needed — SwiftGraphviz carries those.
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
            ]
        ),

        // Application layer (composition root)
        .target(
            name: "App",
            dependencies: [
                "VGraph",
                "MathUtils",
                "VGLanguage",
                "VGraphSVG",
                // In-process Graphviz now available on wasi too (swiftGraphviz 0.7.0),
                // replacing the JS-host layout round-trip.
                .target(name: "VGraphvizLib", condition: .when(platforms: [.macOS, .iOS, .linux, .wasi])),
            ],
            path: "Sources/App",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),

        // Editor logic that is not WASM-specific: what the diagram pane offers
        // and what it is called. Here rather than in VGraphWasm so it can be
        // tested in Swift — the wasm module has only JS smoke tests.
        .target(
            name: "EditorCore",
            dependencies: ["App", "VGraph"],
            path: "Sources/EditorCore",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),

        // Native CLI executable
        .executableTarget(
            name: "vgraph-cli",
            dependencies: [
                // A driver reaches its adapters through App's composition and
                // never names one. Declaring them here compiles either way, so
                // this list is what keeps that honest.
                "App",
                "VGraph",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/VGraphCLI",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),

        // The native composition root the test suites share.
        .target(
            name: "TestSupport",
            dependencies: [
                "App",
                "VGraph",
            ],
            path: "Tests/TestSupport",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),

        // Shared MCP tool definitions (used by both stdio and HTTP servers)
        .target(
            name: "VGraphMCPTools",
            dependencies: [
                "App",
                "VGraph",  // RenderResult, alongside the ports that return it
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/VGraphMCPTools",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),

        // MCP server executable (stdio transport — local CLI & Docker)
        .executableTarget(
            name: "vgraph-mcp",
            dependencies: [
                "VGraphMCPTools",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/VGraphMCP",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),

        // The HTTP layer of the hosted server, a library so it can be tested.
        .target(
            name: "VGraphMCPHTTPKit",
            dependencies: [
                "VGraphMCPTools",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            path: "Sources/VGraphMCPHTTPKit",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),

        // MCP server executable (HTTP transport — Cloud Run)
        .executableTarget(
            name: "vgraph-mcp-http",
            dependencies: [
                "VGraphMCPTools",
                "VGraphMCPHTTPKit",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Sources/VGraphMCPHTTP",
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),

        // Tests - organized by module
        .testTarget(
            name: "VGraphTests",
            dependencies: ["VGraph", "VGLanguage", "App", "TestSupport"],
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
            ]
        ),
        .testTarget(
            name: "VGLanguageTests",
            dependencies: ["VGraph", "VGLanguage", "VGraphvizLib", "App"],
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
            ]
        ),
        .testTarget(
            name: "VGraphSVGTests",
            dependencies: ["VGraph", "VGraphSVG", "App", "TestSupport"],
            // Excluded, not a resource: the tests read them via `#filePath`, because
            // a snapshot's job is to be diffed in review.
            exclude: ["__Snapshots__"],
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["VGraph", "VGLanguage", "App", "EditorCore"],
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
            ]
        ),
        .testTarget(
            name: "VGraphvizLibTests",
            dependencies: ["VGraph", "VGraphvizLib", "App", "TestSupport"],
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),
        .testTarget(
            name: "VGraphMCPTests",
            dependencies: ["VGraph", "VGraphSVG", "vgraph-mcp", "VGraphMCPTools", "TestSupport"],
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),
        .testTarget(
            name: "VGraphMCPHTTPTests",
            dependencies: [
                "VGraphMCPHTTPKit", "VGraphMCPTools", "TestSupport",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),
        .testTarget(
            name: "VGraphCLITests",
            dependencies: ["VGraph", "vgraph-cli", "TestSupport"],
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: ["VGraph", "VGLanguage", "App"],
            path: "Tests/IntegrationTests",
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
            ]
        ),

        // Math utilities
        .target(
            name: "MathUtils",
            dependencies: [],
            swiftSettings: [
                .define("WASM", .when(platforms: [.wasi])),
                .enableExperimentalFeature("Extern"),
                .enableExperimentalFeature("Embedded", .when(platforms: [.wasi])),
                .unsafeFlags(["-wmo"], .when(platforms: [.wasi])),
            ]
        ),
    ]
)
