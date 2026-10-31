import VGraph

extension TransformStep.Id {
    public static var extractNodeShape: Self { "extractNodeShape" }
}

extension DisplayPipeline {
    /// Extracts each node's shape from its style background; produces `shape`.
    public static var extractNodeShape: TransformStep {
        TransformStep(.extractNodeShape, requires: [.assembleNodeStyles]) { (graph: VGraph) throws(VError) in
            var result = graph
            for node in graph.nodes {
                result = try extractShape(node: node, in: result)
            }
            return result
        }
    }
}

private func extractShape(node: Node, in graph: VGraph) throws(VError) -> VGraph {
    // Get node type and its style — try? form (catch { … } with untyped `error`
    // is restricted under Embedded Swift; the fallback is the same here).
    let style: NodeStyleLayout = {
        guard let nodeType = try? graph.nodeType(for: node),
            let s: NodeStyleLayout = try? graph.get(nodeType: nodeType, attribute: Attributes.Node.style)
        else { return NodeStyleLayout.bareText }
        return s
    }()

    if let shape = style.walk({ layout -> NodeShape? in
        if case .background(let bg, _) = layout {
            return bg.shape
        }
        return nil
    }) {
        return try graph.set(
            node: node,
            attribute: Attributes.Node.shape.attribute(shape)
        )
    }

    // No background shape in the style: leave the attribute unset so the default applies.
    return graph
}
