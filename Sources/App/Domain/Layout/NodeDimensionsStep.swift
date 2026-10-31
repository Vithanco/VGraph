import MathUtils
import VGraph

extension TransformStep.Id {
    public static var calculateNodeDimensions: Self { "calculateNodeDimensions" }
}

extension DisplayPipeline {
    /// Computes each node's final size; produces `width`, `height`, `layoutedSize`.
    public static var calculateNodeDimensions: TransformStep {
        TransformStep(
            .calculateNodeDimensions,
            requires: [.assembleNodeStyles, .calculateNodeTextDimensions, .extractNodeShape]
        ) { (graph: VGraph) throws(VError) in
            var result = graph
            for node in graph.nodes {
                result = try calculateNodeSize(node: node, in: result)
            }
            return result
        }
    }
}

private func calculateNodeSize(node: Node, in graph: VGraph) throws(VError) -> VGraph {
    let nodeTextSize = (try? graph.get(node: node, attribute: Attributes.Node.nodeTextSize)) ?? VSize.zero

    // Read the style via the full inheritance chain (node → group → nodeType → default).
    // The node-level override matters for per-instance layouts whose dimensions depend on
    // instance data — e.g. FoldingLayoutStep stamps a per-node `foldedGroupNode` layout
    // whose size includes the count badge, subtitle, and stack-shadow padding.
    // try? form — untyped catch `error: any Error` is restricted under Embedded Swift.
    let style: NodeStyleLayout =
        (try? graph.get(node: node, attribute: Attributes.Node.style)) ?? NodeStyleLayout.bareText

    var nodeSize = style.calculateSizeWithText(nodeTextSize)

    if let nodeType = try? graph.nodeType(for: node),
        let minWidth = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.minWidth),
        minWidth > 0
    {
        nodeSize = nodeSize.widthAtLeast(minWidth)
    }

    // For circle-shaped nodes, force square dimensions using the diagonal.
    // A circle's inscribed rectangle has its diagonal equal to the diameter,
    // so diameter = √(width² + height²) ensures the text fits inside.
    let shape = (try? graph.get(node: node, attribute: Attributes.Node.shape)) ?? NodeShape.box
    if shape == .circle {
        let diameter = Math.sqrt(nodeSize.width * nodeSize.width + nodeSize.height * nodeSize.height)
        nodeSize = VSize(width: diameter, height: diameter)
    }

    var result = try graph.set(
        node: node,
        attribute: Attributes.Node.width.attribute(nodeSize.width)
    )
    result = try result.set(
        node: node,
        attribute: Attributes.Node.height.attribute(nodeSize.height)
    )
    result = try result.set(
        node: node,
        attribute: Attributes.Node.layoutedSize.attribute(nodeSize)
    )
    result = try result.set(node: node, attribute: Attributes.Node.fixedsize.attribute(true))

    return result
}
