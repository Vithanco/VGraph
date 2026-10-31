// See ADR-0015.

import VGraph

/// `Sendable` is spelled out rather than inferred: a `public` struct does not get
/// the conformance across a module boundary, and every consumer is in another one.
public struct VSVGRenderer<Logger: ForLogMessages>: ForRenderAGraph, Sendable {
    private let logger: Logger
    private let overlayProviders: [String: NotationOverlayEntry]

    public init(
        logger: Logger,
        overlayProviders: [String: NotationOverlayEntry] = NotationOverlayRegistry.default
    ) {
        self.logger = logger
        self.overlayProviders = overlayProviders
    }

    /// The VGL envelope is spliced into the string rather than built into the
    /// tree: it is CDATA, which the IR does not model, and keeping it on this
    /// side is what lets the tree stay entirely mountable (ADR-0015 F1). Only
    /// Save SVG and document re-opening need it; the mounted preview does not.
    public func render(
        graph: VGraph, sourceVGL: String? = nil, darkMode: Bool = false, interactive: Bool = false
    ) throws(VError) -> String {
        let svg = try VSVGGraph.render(
            graph: graph, darkMode: darkMode, logger: logger,
            overlayProviders: overlayProviders, interactive: interactive
        ).render()
        guard let sourceVGL else { return svg }
        return SVGBuilder.embedVGL(sourceVGL, in: svg)
    }

    /// `render` embeds it as CDATA in `<metadata>`; `SVGBuilder` owns both ends
    /// so the mint and the parse cannot drift.
    public func sourceVGL(from rendered: String) -> String? {
        SVGBuilder.extractVGL(from: rendered)
    }
}
