import VGraph

extension TransformStep.Id {
    public static var applyTextWrapping: Self { "applyTextWrapping" }
}

extension DisplayPipeline {
    /// Wraps each node's label to the max node width; produces `wrappedText`.
    public static var applyTextWrapping: TransformStep {
        TransformStep(.applyTextWrapping) { (graph: VGraph) throws(VError) in
            var result = graph
            for node in graph.nodes {
                result = try wrapNodeText(node: node, in: result)
            }
            return result
        }
    }
}

private func wrapNodeText(node: Node, in graph: VGraph) throws(VError) -> VGraph {
    let label = (try? graph.get(node: node, attribute: Attributes.Node.label)) ?? ""

    guard !label.isEmpty else {
        return try graph.set(
            node: node,
            attribute: Attributes.Node.wrappedText.attribute([])
        )
    }

    let font: VFont = graph.getFont(forNode: node)
    let maxNodeWidth: Double = (try? graph.get(attribute: Attributes.Group.maxNodeWidth)) ?? 300.0

    let lineHeightMultiplier = 1.2
    let lineHeight = font.size * lineHeightMultiplier
    let charWidth = font.size * font.charWidthRatio

    let wrappingResult = TextWrapping.findOptimalLineBreaks(
        label,
        characterWidthToHeightRatio: charWidth,
        lineHeightMultiplier: lineHeight,
        maxWidth: maxNodeWidth
    )

    return try graph.set(
        node: node,
        attribute: Attributes.Node.wrappedText.attribute(wrappingResult.lines)
    )
}
