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
    var updatedGraph = graph

    for node in graph.nodes {
        if let position = layoutData.nodePositions[node.id] {
            updatedGraph = try updatedGraph.set(
                node: node,
                attribute: Attributes.Node.layoutedPos.attribute(position)
            )
        } else {
            logger.log("[applyLayoutData] No position found for node \(node.id)")
        }
    }

    // Look up each edge's layout by its own id. The layout engine keys
    // edgeLayouts by the DOT `id` attribute (which DotExporter emits from
    // edge.id), so no positional sort is needed.
    for edge in graph.edges {
        let key = edge.id.description
        if let edgeLayout = layoutData.edgeLayouts[key] {
            updatedGraph = try updatedGraph.set(
                edge: edge,
                attribute: Attributes.Edge.layoutData.attribute(edgeLayout)
            )
        } else {
            logger.log("[applyLayoutData] ✗ No layout found for \(key)")
        }
    }

    // Store the root graph layout (bounding box + optional label) on the root
    // group. The engine reports a box that already encloses every drawn element
    // (nodes, edge splines, arrowheads, labels), so the SVG renderer can use it
    // directly to size the viewBox.
    if let rootLayout = layoutData.rootLayout {
        updatedGraph = try applyGroupLayout(rootLayout, to: Group(rawValue: rootGroup), in: updatedGraph)
    }

    for (groupId, groupLayout) in layoutData.groupLayouts {
        updatedGraph = try applyGroupLayout(groupLayout, to: Group(rawValue: groupId), in: updatedGraph)
    }

    return updatedGraph
}

private func applyGroupLayout(
    _ layout: GroupLayoutData,
    to group: Group,
    in graph: VGraph
) throws(VError) -> VGraph {
    var updated = try graph.set(
        group: group,
        attribute: Attributes.Group.layoutedBounds.attribute(layout.boundingBox)
    )
    if let labelPos = layout.labelPosition {
        updated = try updated.set(
            group: group,
            attribute: Attributes.Group.labelLayoutedPos.attribute(labelPos)
        )
    }
    if let labelSize = layout.labelSize {
        updated = try updated.set(
            group: group,
            attribute: Attributes.Group.labelLayoutedSize.attribute(labelSize)
        )
    }
    return updated
}
