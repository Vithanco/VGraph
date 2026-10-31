extension TransformStep.Id {
    public static var foldGroups: Self { "foldGroups" }
}

/// When groups are folded (`foldingState == .folded`), this layout step transforms the graph:
/// 1. Creates a stand-in node for each folded group: a detailed node as its own
///    node type, a plain group as the generic `FoldedGroup`
/// 2. Deletes internal edges (where both endpoints are within the folded group)
/// 3. Redirects crossing edges to point to/from the stand-in
/// 4. Deletes all subgroups of folded groups
/// 5. Deletes all nodes within folded groups
///
/// Groups with `foldingState == .hidden` (nested inside a folded group) are not processed
/// separately - they are deleted as part of their parent folded group's processing.
public func applyFoldingLayoutStep(to graph: VGraph) throws(VError) -> VGraph {
    let foldedGroups = graph.groups.filter { group in
        graph.foldingState(group: group) == .folded
    }

    if foldedGroups.isEmpty {
        return graph
    }

    var result = graph

    // Build a lookup: node -> folded group it belongs to (if any)
    // This maps each node to its "owning" folded group (the outermost folded ancestor)
    var nodeToFoldedGroup: [Node: Group] = [:]
    for foldedGroup in foldedGroups {
        let (_, allNodes) = try result.getAllContent(group: foldedGroup)
        for node in allNodes {
            nodeToFoldedGroup[node] = foldedGroup
        }
    }

    // Replace each folded group with a node of the same id. We must delete the
    // group from `result` FIRST: nodes and groups share one id space, and adding a
    // node under a group's id throws `idCollision`.
    // All lookups that still need the group reach for the ORIGINAL `graph` parameter.
    for foldedGroup in foldedGroups {
        let nodeCount = nodeToFoldedGroup.values.filter { $0 == foldedGroup }.count
        if let type = graph.nodeType(of: foldedGroup) {
            result = try result.folding(detailed: foldedGroup, as: type)
        } else {
            result = try result.folding(plain: foldedGroup, holding: nodeCount, from: graph)
        }
        result = try result.set(node: Node(foldedGroup), attribute: Attributes.Node.foldedNodeCount.attribute(nodeCount))
            .set(node: Node(foldedGroup), attribute: Attributes.Node.standsForGroup.attribute(true))
    }

    for edge in graph.edges {
        let fromFoldedGroup = nodeToFoldedGroup[edge.from]
        let toFoldedGroup = nodeToFoldedGroup[edge.to]

        if let fromGroup = fromFoldedGroup, let toGroup = toFoldedGroup {
            if fromGroup == toGroup {
                result = try result.delete(edge: edge.id)
            } else {
                result = try redirectEdge(
                    edge,
                    fromGroup: fromGroup,
                    toGroup: toGroup,
                    in: result
                )
            }
        } else if let fromGroup = fromFoldedGroup {
            result = try redirectEdge(
                edge,
                fromGroup: fromGroup,
                toGroup: nil,
                in: result
            )
        } else if let toGroup = toFoldedGroup {
            result = try redirectEdge(
                edge,
                fromGroup: nil,
                toGroup: toGroup,
                in: result
            )
        }
    }

    for node in nodeToFoldedGroup.keys {
        result = try result.delete(node: node)
    }

    // Delete subgroups of (now-removed) folded groups. The folded groups themselves were
    // already removed above to free their ADS keys for the replacement nodes.
    for foldedGroup in foldedGroups {
        let (subgroups, _) = try graph.getAllContent(group: foldedGroup)
        for subgroup in subgroups where result.has(group: subgroup) {
            result = try result.delete(group: subgroup)
        }
    }

    return result
}

// MARK: - Private Helpers

extension VGraph {
    public func isFoldedStandIn(_ node: Node) -> Bool {
        (try? get(node: node, attribute: Attributes.Node.standsForGroup)) ?? false
    }

    /// Folded, a detailed node is the node it was (ADR-0032), so its type's
    /// current look and every view still reach it.
    fileprivate func folding(detailed group: Group, as type: NodeType) throws(VError) -> VGraph {
        try replacing(detailed: group, withNodeOfType: type, in: parentGroup(of: group))
    }

    /// A plain group has no look of its own as a node, so it gets the generic
    /// folded-group display type and a copy of what the box needs.
    fileprivate func folding(plain group: Group, holding count: Int, from graph: VGraph) throws(VError) -> VGraph {
        var result = self
        if !result.has(nodeType: Notations.FoldGroups.NodeTypes.foldedGroup) {
            // A display type every notation has: the engine's, so a notation may restyle it.
            result = try result.placing(Notations.FoldGroups.nodeContent, in: .engine)
        }
        let groupLabel = graph.label(of: .group(group)) ?? ""
        let groupNode = Node(group)
        result = try result.delete(group: group)
            .add(node: groupNode, type: Notations.FoldGroups.NodeTypes.foldedGroup, group: graph.parentGroup(of: group))

        // Keep the original-case label on the node for round-tripping; the layout
        // uppercases the rendered title via NodeStyleLayout.typeLabel.
        if !groupLabel.isEmpty {
            result = try result.set(node: groupNode, attribute: Attributes.Node.label.attribute(groupLabel))
        }

        // The box is the group on screen, so it carries the group's link and badge.
        if let url = graph.url(of: .group(group)) {
            result = try result.set(node: groupNode, attribute: Attributes.Node.url.attribute(url))
        }

        let nodeStyle =
            graph.resolvedGroupStyle(group)?.folded
            ?? NodeStyleLayout.foldedGroupNode(
                label: groupLabel,
                count: count,
                fill: Notations.FoldGroups.foldedGroupFill,
                border: Notations.FoldGroups.foldedGroupBorder,
                textColor: Notations.FoldGroups.foldedGroupText
            )
        return try result.set(node: groupNode, attribute: Attributes.Node.style.attribute(nodeStyle))
    }
}

/// The original's styling reaches the new type through its chain (ADR-0030).
private func createRedirectedEdgeType(
    originalEdgeType: EdgeType,
    newFromType: NodeType,
    newToType: NodeType,
    in graph: VGraph
) throws(VError) -> (VGraph, EdgeType) {
    // Format: originalId__fromType__toType
    let newEdgeTypeId = "\(originalEdgeType.id.id)__\(newFromType.id)__\(newToType.id)"

    if let existing = graph.get(edgeType: newEdgeTypeId) {
        return (graph, existing)
    }

    let newEdgeType = EdgeType(id: newEdgeTypeId, from: newFromType, to: newToType)
    return (try graph.deriving(edgeType: newEdgeType, from: originalEdgeType.id), newEdgeType)
}

/// Redirects an edge to point to/from GroupNodes instead of the original nodes.
/// Creates a new edge type if necessary to accommodate the FoldedGroup node type.
private func redirectEdge(
    _ edge: Edge,
    fromGroup: Group?,
    toGroup: Group?,
    in graph: VGraph
) throws(VError) -> VGraph {
    var result = graph

    let newFrom = fromGroup.map { Node($0) } ?? edge.from
    let newTo = toGroup.map { Node($0) } ?? edge.to

    let originalEdgeType = try result.edgeType(for: edge)

    // Read now, while the folded-away end still exists: a bundle lists its members
    // this way once they are drawn as one.
    func name(_ node: Node) -> String {
        let label = (try? result.get(node: node, attribute: Attributes.Node.label)) ?? ""
        return label.isEmpty ? node.id : label
    }
    result = try result.set(
        edge: edge.id,
        attribute: Attributes.Edge.foldedDescription.attribute(
            "\(name(edge.from)) → \(name(edge.to)) (\(originalEdgeType.id.id))"))

    let newFromType = try result.nodeType(for: newFrom)
    let newToType = try result.nodeType(for: newTo)

    let needsNewEdgeType = !result.holds(originalEdgeType, from: newFromType, to: newToType)

    if needsNewEdgeType {
        let (updatedGraph, newEdgeType) = try createRedirectedEdgeType(
            originalEdgeType: originalEdgeType,
            newFromType: newFromType,
            newToType: newToType,
            in: result
        )
        result = updatedGraph
        result = try result.setEdgeType(edge: edge.id, type: newEdgeType.id)
    }

    let redirectedEdge = Edge(base: edge, from: newFrom, to: newTo)
    result = try result.redirect(edge: redirectedEdge)

    return result
}
