import VGraph

extension TransformStep.Id {
    public static var calculateNodeTextDimensions: Self { "calculateNodeTextDimensions" }
}

extension DisplayPipeline {
    /// Measures each node's wrapped text; produces `nodeTextSize`.
    public static var calculateNodeTextDimensions: TransformStep {
        TransformStep(.calculateNodeTextDimensions, requires: [.applyTextWrapping]) { (graph: VGraph) throws(VError) in
            var result = graph
            for node in graph.nodes {
                result = try calculateTextSize(node: node, in: result)
            }
            return result
        }
    }
}

private func calculateTextSize(node: Node, in graph: VGraph) throws(VError) -> VGraph {
    let wrappedLines = (try? graph.get(node: node, attribute: Attributes.Node.wrappedText)) ?? []
    let font = graph.getFont(forNode: node)

    let textSize = TextSizeEstimator.estimateSize(lines: wrappedLines, font: font)

    return try graph.set(
        node: node,
        attribute: Attributes.Node.nodeTextSize.attribute(textSize)
    )
}
