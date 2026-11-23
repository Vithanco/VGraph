extension TransformStep.Id {
    public static var foldGroups: Self { "foldGroups" }
}

/// Each folded group becomes a stand-in node with the group's id — a detailed
/// node as its own node type, a plain group as the generic `FoldedGroup`. Edges
/// wholly inside it go, edges crossing it end at the stand-in, and everything it
/// held goes. A group nested in a folded one (`foldState == .hidden`) goes with
/// its folded ancestor rather than being folded itself.
public func applyFoldStep(to graph: VGraph) throws(VError) -> VGraph {
    let foldedGroups = graph.groups.filter { graph.foldState(of: $0) == .folded }
    guard !foldedGroups.isEmpty else { return graph }
    let foldedGroupOf = try graph.foldedGroupOfMember(foldedGroups)
    let withStandIns = try foldedGroups.folding(graph) { (result, folded) throws(VError) in
        try result.standingIn(for: folded, holding: foldedGroupOf.values.filter { $0 == folded }.count, from: graph)
    }
    let redirected = try graph.edges.folding(withStandIns) { (result, edge) throws(VError) in
        try result.folding(edge, from: foldedGroupOf[edge.from], to: foldedGroupOf[edge.to])
    }
    let withoutMembers = try foldedGroupOf.keys.folding(redirected) { (result, node) throws(VError) in
        try result.deleting(node: node)
    }
    // The folded groups themselves already went, to free their ids for the stand-ins.
    let subgroups = try foldedGroups.map { (folded) throws(VError) in try graph.allContent(of: folded).groups }.flatMap { $0 }
    return try subgroups.folding(withoutMembers) { (result, subgroup) throws(VError) in
        result.has(group: subgroup) ? try result.deleting(group: subgroup) : result
    }
}

extension VGraph {
    /// Each node inside a folded group, to the outermost folded group holding it.
    fileprivate func foldedGroupOfMember(_ foldedGroups: [Group]) throws(VError) -> [Node: Group] {
        let pairs = try foldedGroups.map { (folded) throws(VError) in try allContent(of: folded).nodes.map { ($0, folded) } }
            .flatMap { $0 }
        return Dictionary(pairs, uniquingKeysWith: { _, last in last })
    }

    /// The group must go before its stand-in comes: nodes and groups share one id
    /// space, so adding a node under a group's id throws `idCollision`. What still
    /// needs the group reads it from `original`.
    fileprivate func standingIn(for folded: Group, holding count: Int, from original: VGraph) throws(VError) -> VGraph {
        let replaced: VGraph
        if let type = original.nodeType(of: folded) {
            replaced = try folding(detailed: folded, as: type)
        } else {
            replaced = try folding(plain: folded, holding: count, from: original)
        }
        return try replaced.setting(node: Node(folded), attribute: Attributes.Node.foldedNodeCount.attribute(count))
            .setting(node: Node(folded), attribute: Attributes.Node.standsForGroup.attribute(true))
    }

    /// An edge with both ends in one folded group is gone with it; one with an end
    /// in a folded group ends at that group's stand-in instead.
    fileprivate func folding(_ edge: Edge, from fromGroup: Group?, to toGroup: Group?) throws(VError) -> VGraph {
        switch (fromGroup, toGroup) {
        case (nil, nil): return self
        case (let from?, let to?) where from == to: return try deleting(edge: edge.id)
        default: return try redirectingToStandIns(edge, fromGroup: fromGroup, toGroup: toGroup)
        }
    }
}

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
        let foldedGroupType = Notations.FoldGroups.NodeTypes.foldedGroup
        // A display type every notation has: the engine's, so a notation may restyle it.
        let typed = has(nodeType: foldedGroupType) ? self : try placing(Notations.FoldGroups.nodeContent, in: .engine)
        let groupLabel = graph.label(of: .group(group)) ?? ""
        let groupNode = Node(group)
        let added = try typed.deleting(group: group)
            .adding(node: groupNode, type: foldedGroupType, group: graph.parentGroup(of: group))
        // Keep the original-case label on the node for round-tripping; the layout
        // uppercases the rendered title via NodeStyleLayout.typeLabel.
        let labeled =
            groupLabel.isEmpty ? added : try added.setting(node: groupNode, attribute: Attributes.Node.label.attribute(groupLabel))
        // The box is the group on screen, so it carries the group's link and badge.
        let result =
            try graph.url(of: .group(group)).map { (url) throws(VError) in
                try labeled.setting(node: groupNode, attribute: Attributes.Node.url.attribute(url))
            } ?? labeled

        let nodeStyle =
            graph.resolvedGroupStyle(group)?.folded
            ?? NodeStyleLayout.foldedGroupNode(
                label: groupLabel,
                count: count,
                fill: .groupFill,
                border: .groupBorder,
                textColor: .groupText
            )
        return try result.setting(node: groupNode, attribute: Attributes.Node.style.attribute(nodeStyle))
    }
}

extension VGraph {
    /// A display type standing for `original` between other node types. Its
    /// styling reaches it through its chain (ADR-0030).
    fileprivate func redirectedEdgeType(standingFor original: EdgeType, between ends: NodeTypePair) throws(VError)
        -> (VGraph, EdgeType)
    {
        let id = "\(original.id.id)__\(ends.from.id)__\(ends.to.id)"
        if let existing = get(edgeType: id) { return (self, existing) }
        let redirected = EdgeType(id: id, from: ends.from, to: ends.to)
        return (try deriving(edgeType: redirected, from: original.id), redirected)
    }
}

extension VGraph {
    /// Points an edge at the stand-ins instead of the nodes they replace, under a
    /// display type when its own type does not hold the new ends.
    fileprivate func redirectingToStandIns(_ edge: Edge, fromGroup: Group?, toGroup: Group?) throws(VError) -> VGraph {
        let newFrom = fromGroup.map { Node($0) } ?? edge.from
        let newTo = toGroup.map { Node($0) } ?? edge.to
        let originalEdgeType = try edgeType(for: edge)
        // Read now, while the folded-away end still exists: a bundle lists its members
        // this way once they are drawn as one.
        let described = try setting(
            edge: edge.id,
            attribute: Attributes.Edge.foldedDescription.attribute("\(name(of: edge)) (\(originalEdgeType.id.id))"))
        let ends = NodeTypePair(from: try described.nodeType(for: newFrom), to: try described.nodeType(for: newTo))
        let retyped =
            described.holds(originalEdgeType, from: ends.from, to: ends.to)
            ? described : try described.retyping(edge.id, standingFor: originalEdgeType, between: ends)
        return try retyped.redirecting(edge: Edge(base: edge, from: newFrom, to: newTo))
    }

    fileprivate func retyping(_ edge: Edge.Id, standingFor original: EdgeType, between ends: NodeTypePair) throws(VError)
        -> VGraph
    {
        let (withType, type) = try redirectedEdgeType(standingFor: original, between: ends)
        return try withType.settingEdgeType(edge: edge, type: type.id)
    }
}
