// Writes a computed [[GraphLayoutData]] onto a VGraph as layout attributes.
//
// Engine-agnostic: it only maps the result model onto `layoutedPos` /
// `layoutData` / `layoutedBounds` attributes, so it can be tested against a
// hand-built GraphLayoutData without running any layout engine.

public func applyLayoutData<Logger: VForLogMessages>(
    _ layoutData: GraphLayoutData,
    to graph: VGraph,
    logger: Logger
) throws(VError) -> VGraph {
    let placed = try graph.nodes.folding(graph) { (result, node) throws(VError) in
        guard let position = layoutData.nodePositions[node.id] else {
            logger.log("[applyLayoutData] No position found for node \(node.id)")
            return result
        }
        return try result.setting(node: node, attribute: Attributes.Node.layoutedPos(position))
    }

    // The layout engine keys edgeLayouts by the edge's own id, so no positional sort is needed.
    let routed = try graph.edges.folding(placed) { (result, edge) throws(VError) in
        guard let edgeLayout = layoutData.edgeLayouts[edge.id.description] else {
            logger.log("[applyLayoutData] ✗ No layout found for \(edge.id.description)")
            return result
        }
        return try result.setting(edge: edge, attribute: Attributes.Edge.layoutData(edgeLayout))
    }

    // The engine's root box already encloses every drawn element (nodes, edge
    // splines, arrowheads, labels), so the SVG renderer sizes the viewBox from it.
    let rootLaidOut =
        try layoutData.rootLayout.map { (layout) throws(VError) in
            try applyGroupLayout(layout, to: Group.root, in: routed)
        } ?? routed

    return try layoutData.groupLayouts.folding(rootLaidOut) { (result, entry) throws(VError) in
        try applyGroupLayout(entry.value, to: Group(rawValue: entry.key), in: result)
    }
}

private func applyGroupLayout(
    _ layout: GroupLayoutData,
    to group: Group,
    in graph: VGraph
) throws(VError) -> VGraph {
    let bounded = try graph.setting(group: group, attribute: Attributes.Group.layoutedBounds(layout.boundingBox))
    let labelPlaced =
        try layout.labelPosition.map { (position) throws(VError) in
            try bounded.setting(group: group, attribute: Attributes.Group.labelLayoutedPos(position))
        } ?? bounded
    return try layout.labelSize.map { (size) throws(VError) in
        try labelPlaced.setting(group: group, attribute: Attributes.Group.labelLayoutedSize(size))
    } ?? labelPlaced
}
