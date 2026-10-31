// The order in which a graph is prepared for rendering.
//
// This is domain knowledge, not platform knowledge, so it is defined **once,
// here** — not reassembled by each composition root. It previously lived in
// three hand-written copies (CLI, MCP, WASM) which had drifted: MCP applied
// group folding but not the notation phase, so the MCP server rendered
// notations and `vnotation` blocks differently from the CLI and the web
// editor. One definition makes that class of bug impossible.
//
// Composition roots inject only what is genuinely platform-specific: the
// logger, the renderer, and the layout engine.

import VGraph

public enum DisplayPipeline {
    /// In dependency order, so a mis-ordering fails loudly rather than producing
    /// silent zero-sized nodes.
    public static var sizingSteps: [TransformStep] {
        [
            assembleNodeStyles,
            applyTextWrapping,
            calculateNodeTextDimensions,
            extractNodeShape,
            calculateNodeDimensions,
        ]
    }

    public static var sizingStepIds: [TransformStep.Id] { sizingSteps.map { $0.id } }

    public static var preLayoutSteps: [TransformStep] {
        Notations.extensionSteps + sizingSteps
    }

    /// All five sizing ids, not just the last: `orderProblems` takes no transitive
    /// closure, and the sizing chain has two roots. App decides where layout sits in
    /// the order; the port still decides how it works.
    public static func layoutStep(_ layout: @escaping GraphTransform) -> TransformStep {
        TransformStep(.layoutGraph, requires: sizingStepIds) { (graph: VGraph) throws(VError) in
            try layout(graph)
        }
    }

    public static func fullSteps(layout: @escaping GraphTransform) -> [TransformStep] {
        preLayoutSteps + [layoutStep(layout)]
    }

    /// `layout` is typically an injected `ForLayoutAGraph` engine's `layout(graph:)`.
    public static func full(layout: @escaping GraphTransform) -> GraphTransform {
        TransformStep.pipeline(fullSteps(layout: layout))
    }
}
