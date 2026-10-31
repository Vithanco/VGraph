// Uses BridgeJS @JS macros for automatic Swift <-> JavaScript type marshalling.
// BridgeJS generates TypeScript declarations and handles all memory management.

import App
import JavaScriptKit
import VGraph
import VGraphEditor
import VGraphSVG

// MARK: - JavaScriptKit runtime re-export

// Re-export JavaScriptKit's closure feature-detection function under its
// canonical wasm export name.
//
// JavaScriptKit's SwiftRuntime (Package/runtime.js `get closureDeallocator`,
// reached from `swjs_create_function`) calls
// `instance.exports.swjs_library_features()` the first time any `JSClosure`
// is created — which for this module happens when the editor wires its
// textarea event listeners. JavaScriptKit exposes that function with
// `@_expose(wasm, "swjs_library_features")`, but that attribute only
// reliably produces a wasm export from the *root executable target*; from a
// dependency library (JavaScriptKit) the export is dropped, so without this
// shim the editor mount throws "swjs_library_features is not a function".
// The engine's string-only @JS functions never create a closure, so this
// gap only surfaced once the editor was added.
//
// Defining our own `@_expose` here (same mechanism that makes the bjs_*
// exports work) emits the export. We can't forward to JavaScriptKit's
// `_swjs_library_features` — that dependency-module symbol is stripped and
// fails to link cross-module — so we mirror its trivial body instead:
// JavaScriptKit's Features.swift returns the `weakRefs` feature bit
// (1 << 0) unless built with JAVASCRIPTKIT_WITHOUT_WEAKREFS (which we don't).
// All target browsers support WeakRef/FinalizationRegistry.
@_expose(wasm, "swjs_library_features")
public func _vgraph_swjs_library_features() -> Int32 {
    1  // LibraryFeatures.weakRefs
}

// Re-export JavaScriptKit's BridgeJS closure-release function under its
// canonical wasm export name — same dependency-`@_expose`-gets-stripped
// problem as `swjs_library_features` above.
//
// The JS-side closure registry (bridge-js.js `swiftClosureRegistry`, from
// ElementaryUI's BrowserRuntime) calls
// `instance.exports.bjs_release_swift_closure(pointer)` to free a Swift
// closure once JS is done with it. That function is
// `@_expose(wasm, "bjs_release_swift_closure")` in the JavaScriptKit
// dependency (BridgeJSIntrinsics.swift), but the dependency-library export
// is dropped by the linker, so releasing ANY Swift event closure (every
// ElementaryUI `.onInput`/`.onClick`/`.onMouseMove`/… handler, most visibly
// the splitter's transient drag overlay) threw
// "bjs_release_swift_closure is not a function" and leaked the closure box.
//
// Its body is a trivial one-liner (release the boxed closure), so — as with
// the shim above, and to avoid a duplicate-export clash with the stripped
// dependency symbol — we mirror it from the root target rather than forward.
@_expose(wasm, "bjs_release_swift_closure")
public func _vgraph_bjs_release_swift_closure(_ pointer: UnsafeMutableRawPointer) {
    Unmanaged<AnyObject>.fromOpaque(pointer).release()
}

// MARK: - Editor entry points

/// Mount the ElementaryUI-based interactive editor into the DOM element with
/// the given id. Builds a textarea + Render button + status line (managed by
/// ElementaryUI) plus a live SVG preview, and renders the default VGL.
@JS public func mountEditor(elementId: String) {
    VGraphEditor.mountEditor(elementId: elementId)
}

@JS public func editorRenderNow() {
    VGraphEditor.editorRenderNow()
}

@JS public func editorLongPressFired() {
    VGraphEditor.editorLongPressFired()
}

@JS public func setEditorVGL(text: String) {
    VGraphEditor.setEditorVGL(text: text)
}

/// Load a document the host fetched for `?src=`. `name` is the last
/// path segment of the source, which is where the document's name comes
/// from — the same role a picked file's name plays.
@JS public func openEditorDocument(text: String, name: String) -> Bool {
    VGraphEditor.openEditorDocument(text: text, named: name)
}

@JS public func setEditorStatus(text: String) {
    VGraphEditor.setEditorStatus(text: text)
}

// MARK: - Public API

@JS public func convertToDot(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        return try app.vithancoGraphToDot(graph)
    } catch let error {
        return "Error: \(error)"
    }
}

/// Produce the DOT for the host to lay out with Graphviz (decoupled path).
/// The host computes layout JSON from this DOT at JS top level and passes
/// it back to `renderGraphWithLayout` — keeping Graphviz off the nested
/// SwiftWasm→JS call path that corrupts the Emscripten module.
@JS public func dotForLayout(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        return try app.dotForLayout(graph)
    } catch let error {
        return "Error: \(error)"
    }
}

/// Render a graph to SVG. Graphviz layout runs in-process inside this wasm
/// module (swiftGraphviz) — no host-computed layout JSON needed.
@JS public func renderGraph(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        return try app.renderGraph(graph).svg
    } catch let error {
        return "<svg><text x=\"10\" y=\"20\">Error: \(error)</text></svg>"
    }
}

/// Dark-mode variant of `renderGraph` (§11 of the Diagram Style Guide).
@JS public func renderGraphDark(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        return try app.renderGraph(graph, darkMode: true).svg
    } catch let error {
        return "<svg><text x=\"10\" y=\"20\">Error: \(error)</text></svg>"
    }
}

/// SVG *and* the quality report, as `{"svg": …, "quality": [{severity, message}]}`.
///
/// Restored: this export existed as `renderGraphWithQuality` until 99c8d5c,
/// where the Graphviz-decoupling refactor reused its body for a layout
/// variant and dropped the quality half — leaving `App.renderGraphJSON`
/// ("the shape JavaScript callers read") with no JavaScript caller.
/// `renderGraph` discards the report the editor already displays.
///
/// An empty `view` is the default view: the model, shown even in a document
/// that declares views. An unknown name returns the error listing them.
@JS public func renderGraphWithQuality(graph: String, view: String) -> String {
    let app = VGraphWasmApp()
    do {
        return try app.renderGraphJSON(graph, view: view.isEmpty ? nil : view)
    } catch let error {
        return "{\"error\":\"\(error)\"}"
    }
}

/// `[{"name": …, "label": …}]` in document order; `[]` for a document without views.
@JS public func listViews(graph: String) -> String {
    do {
        return try VGraphWasmApp().listViewsJSON(graph)
    } catch let error {
        return "{\"error\":\"\(error)\"}"
    }
}

/// A notation's self-describing Markdown, or `Error: …`.
///
/// The same document as the CLI's `describe` subcommand and the
/// `describe_notation` MCP tool. Without this export a wasm host can
/// render every notation but not explain one, which is the half a model
/// needs first.
@JS public func describeNotation(notation: String) -> String {
    VGraphWasmApp().describeNotation(notation)
        ?? "Error: notation '\(notation)' has no self-description content yet."
}

@JS public func debugGraph(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        let parsedGraph = try app.parseGraph(graph)
        let typedGraph = parsedGraph.typedGraph

        var output = parsedGraph.debugDescription
        output += "\n\nTypedGraph stats:"
        output += "\n  Nodes: \(typedGraph.nodes.count)"
        output += "\n  Edges: \(typedGraph.edges.count)"
        output += "\n  Node types: \(typedGraph.nodeTypes.count)"
        output += "\n  Edge types: \(typedGraph.edgeTypes.count)"

        return output
    } catch let error {
        return "Error parsing graph: \(error)"
    }
}

/// Lay out a graph (in-process Graphviz) and return position information as
/// text — node positions and edge paths.
@JS public func layoutGraph(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        let layoutedGraph = try app.layoutGraph(graph)

        var output = "=== LAYOUT RESULTS ===\n\n"

        output += "NODE POSITIONS:\n"
        for node in layoutedGraph.nodes {
            let label = try layoutedGraph.get(node: node, attribute: Attributes.Node.label)
            if let pos = try? layoutedGraph.get(node: node, attribute: Attributes.Node.layoutedPos) {
                output += "  \(label): (\(pos.x), \(pos.y))\n"
            } else {
                output += "  \(label): NO POSITION\n"
            }
        }

        output += "\nEDGE PATHS:\n"
        for edge in layoutedGraph.edges {
            let fromLabel = try layoutedGraph.get(node: edge.from, attribute: Attributes.Node.label)
            let toLabel = try layoutedGraph.get(node: edge.to, attribute: Attributes.Node.label)

            if let path = try? layoutedGraph.get(edge: edge.id, attribute: Attributes.Edge.layoutedPath) {
                output += "  \(fromLabel) -> \(toLabel): \(path)\n"
            } else {
                output += "  \(fromLabel) -> \(toLabel): NO PATH\n"
            }
        }

        return output
    } catch let error {
        return "Error in layoutGraph: \(error)"
    }
}

@JS public func exportToVGL(graph: String) -> String {
    let app = VGraphWasmApp()
    do {
        return try app.exportToVGL(graph)
    } catch let error {
        return "Error in exportToVGL: \(error)"
    }
}
