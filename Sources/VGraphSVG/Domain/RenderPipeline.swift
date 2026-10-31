////
////  RenderPipeline.swift
////  VGraphSVG
////
////  Function-composition utilities for the SVG render pipeline.
////  Analogous to `TransformPipeline.compose` for the layout pipeline.
////
////  The render pipeline runs after the layout pipeline has stamped positions,
////  sizes, wrapped text, and edge layout data onto the graph. Pipeline passes
////  read those attributes via `ctx.graph` and emit SVG fragments.
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

/// Composition utilities for the SVG render pipeline.
///
/// Mirrors `TransformPipeline.compose` from the layout pipeline. A render pass
/// is `(RenderContext) throws(VError) -> String`; `compose` runs an ordered
/// array of passes and concatenates their outputs.
public enum RenderPipeline {

    /// A render pass: receives per-render context, returns an SVG fragment.
    /// Throws `VError` because some underlying helpers (defs/node/group rendering)
    /// throw when required graph attributes are unreadable.
    public typealias Pass = (RenderContext) throws(VError) -> String

    /// Compose passes left-to-right; concatenate their string outputs.
    public static func compose(_ passes: [Pass]) -> Pass {
        return { ctx throws(VError) in
            var result = ""
            for pass in passes {
                result += try pass(ctx)
            }
            return result
        }
    }

    /// A no-op pass that emits the empty string. Useful as a placeholder.
    public static var empty: Pass {
        return { _ in "" }
    }
}
