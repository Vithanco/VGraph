////
////  RenderContext.swift
////  VGraphSVG
////
////  The per-render parameters the SVG renderer reads on top of the laid-out
////  graph.
////

import VGraph

/// Per-render parameters threaded through every pipeline pass.
///
/// Carries only what is *not* already on the graph. The graph holds layout-
/// computed state (positions, sizes, wrapped text, edge splines, group bounds,
/// notation name) as attributes — passes read those directly via `ctx.graph`.
// Note: not `Sendable` because `VGraph` is not currently Sendable. If VGraph
// gains Sendable, this struct can too — all its other fields are Sendable.
public struct RenderContext {
    public let graph: VGraph

    /// Per-render theme choice. Drives `SemanticColor.resolve(darkMode:)` lookups.
    public let darkMode: Bool

    /// The overlay entry matched to this graph's notation (or nil for
    /// notations without an overlay). Pipeline slot methods delegate to this
    /// to inject notation-specific layers. Value type — no `any` existential.
    public let overlay: NotationOverlayEntry?

    /// Whether to emit the chrome only a live editor can use — the [[Edge end]]
    /// handles of ADR-0021. Belongs here for the reason everything else does:
    /// it is a per-render parameter and not a property of the graph.
    public let interactive: Bool

    public init(
        graph: VGraph,
        darkMode: Bool,
        overlay: NotationOverlayEntry? = nil,
        interactive: Bool = false
    ) {
        self.graph = graph
        self.darkMode = darkMode
        self.overlay = overlay
        self.interactive = interactive
    }
}
