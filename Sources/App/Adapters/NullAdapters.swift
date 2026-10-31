// Stand-ins for capabilities a given configuration does not have.

import VGraph

public struct NullRenderer: ForRenderAGraph {
    /// Nothing was ever carried, so there is nothing to recover — `nil` rather
    /// than `.notImplemented`, because being handed an artefact with no source
    /// is a normal answer and not a missing capability.
    public func sourceVGL(from rendered: String) -> String? { nil }

    public init() {}

    public func render(
        graph: VGraph, sourceVGL: String? = nil, darkMode: Bool = false, interactive: Bool = false
    ) throws(VError) -> String {
        throw VError.notImplemented("No renderer available")
    }
}

public struct NullLayoutEngine: ForLayoutAGraph {
    public init() {}

    public func layout(graph: VGraph) throws(VError) -> VGraph {
        throw VError.notImplemented("No layout engine available")
    }
}

/// Nobody is watching the document. The configuration of every driver that
/// moves both its views from one place — which is all of them today — and of a
/// session with no views at all (CLI, MCP, tests).
public struct NullDocumentObserver: ForObserveDocumentChanges {
    public init() {}

    public func documentChanged() {}
}

/// Unlike the others, returns rather than throws: highlighting is presentation,
/// so its absence is not an error.
public struct NullHighlighter: ForHighlightVGL {
    public init() {}

    public func lexicalHighlightHTML(source: String) -> String { source }

    public func semanticHighlightHTML(source: String, report: QualityReport?) -> String { source }
}
