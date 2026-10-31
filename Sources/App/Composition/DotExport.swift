// DOT conveniences. Outside Domain/ because DOT is the Graphviz adapter's
// format, not something the application layer knows about.

import VGraph
import VGraphvizLib

extension VGraphApplication {
    /// Export to DOT the same way every other target format is exported:
    /// parse, apply the extension transforms, serialise.
    public func vithancoGraphToDot(_ input: String) throws(VError) -> String {
        try exportGraph(input, using: DotExporter())
    }

    /// The DOT actually handed to Graphviz, after the *pre-layout* transforms —
    /// a different and longer pipeline than `vithancoGraphToDot`.
    ///
    /// Debugging/inspection only; no longer part of the render path. Shares
    /// `DisplayPipeline.preLayoutSteps` with that path so the two cannot drift.
    public func dotForLayout(_ input: String) throws(VError) -> String {
        let graph = try parseGraph(input)
        let prepared = try TransformStep.pipeline(DisplayPipeline.preLayoutSteps)(graph)
        return try DotExporter().export(graph: prepared)
    }
}
