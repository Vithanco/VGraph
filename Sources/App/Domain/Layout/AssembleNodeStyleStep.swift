import VGraph

extension TransformStep.Id {
    public static var assembleNodeStyles: Self { "assembleNodeStyles" }
}

extension DisplayPipeline {
    /// Stores each node type's resolved layout in `style`, so later steps and the
    /// renderer can read it without re-deriving. The derivation itself is
    /// `VGraph.effectiveNodeLayout(for:)` — shared with `hasUserText`, which needs
    /// the same answer before the pipeline has run.
    ///
    /// The second pass stores against the *node*, which the renderer already
    /// prefers over the type's. `presetLayout` is skipped in the first pass but not
    /// the second: its baked style needs no re-storing, but it does need recolouring.
    public static var assembleNodeStyles: TransformStep {
        TransformStep(.assembleNodeStyles) { (graph: VGraph) throws(VError) in
            var result = graph
            for nodeType in graph.nodeTypes {
                // `presetLayout` types already hold their layout in `style`;
                // re-storing it would be a no-op, so skip them.
                let ns: NodeStyle =
                    (try? graph.get(nodeType: nodeType, attribute: Attributes.Node.nodeStyle)) ?? .bareText
                guard ns != .presetLayout, let layout = graph.effectiveNodeLayout(for: nodeType) else { continue }
                result = try result.set(
                    nodeType: nodeType,
                    attribute: Attributes.Node.style.attribute(layout)
                )
            }
            for node in graph.nodes {
                let own = graph.getOwnAttributes(node: node)
                guard own[Attributes.Node.backgroundColor.id] != nil || own[Attributes.Node.fontColor.id] != nil,
                    let layout = graph.effectiveNodeLayout(for: node)
                else { continue }
                result = try result.set(node: node, attribute: Attributes.Node.style.attribute(layout))
            }
            return result
        }
    }
}
